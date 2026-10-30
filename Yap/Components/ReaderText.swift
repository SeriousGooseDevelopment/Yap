import SwiftUI
import UIKit

/// An entry laid out for reading, split into sentences so playback can highlight along and
/// a tapped sentence can seek the recording there.
struct ReaderDocument {
    static let fontSize: CGFloat = 18.5
    static let lineHeight: CGFloat = 1.6
    static let paragraphSpacing: CGFloat = 14

    let paragraphs: [String]
    let text: NSAttributedString
    let sentences: [NSRange]
    /// Each sentence's start as a fraction of the whole text, by character count — the
    /// prototype's estimate of where it falls in the recording.
    let starts: [Double]

    init(paragraphs: [String]) {
        self.paragraphs = paragraphs
        text = JournalText.attributed(paragraphs, size: Self.fontSize, lineHeight: Self.lineHeight, paragraphSpacing: Self.paragraphSpacing)
        var ranges: [NSRange] = []
        var offset = 0
        for paragraph in paragraphs {
            let plain = InlineMarkdown.plain(paragraph) as NSString
            for r in Self.sentenceRanges(plain) { ranges.append(NSRange(location: offset + r.location, length: r.length)) }
            offset += plain.length + 1
        }
        sentences = ranges
        let total = Double(max(1, ranges.reduce(0) { $0 + $1.length }))
        var acc = 0
        starts = ranges.map { r in
            defer { acc += r.length }
            return Double(acc) / total
        }
    }

    /// Sentence ranges in one paragraph: text up to `.`, `!` or `?` plus any closing quotes.
    private static func sentenceRanges(_ text: NSString) -> [NSRange] {
        var result: [NSRange] = []
        var start = 0
        var i = 0
        let terminal = CharacterSet(charactersIn: ".!?")
        let closing = CharacterSet(charactersIn: "\"”’)")
        while i < text.length {
            let ch = text.character(at: i)
            if let scalar = Unicode.Scalar(ch), terminal.contains(scalar) {
                var end = i + 1
                while end < text.length, let s = Unicode.Scalar(text.character(at: end)),
                      terminal.contains(s) || closing.contains(s) { end += 1 }
                result.append(trimmed(NSRange(location: start, length: end - start), in: text))
                start = end
                i = end
                continue
            }
            i += 1
        }
        if start < text.length {
            let rest = trimmed(NSRange(location: start, length: text.length - start), in: text)
            if rest.length > 0 { result.append(rest) }
        }
        return result.filter { $0.length > 0 }
    }

    private static func trimmed(_ range: NSRange, in text: NSString) -> NSRange {
        var r = range
        while r.length > 0, text.character(at: r.location) == 32 { r.location += 1; r.length -= 1 }
        while r.length > 0, text.character(at: NSMaxRange(r) - 1) == 32 { r.length -= 1 }
        return r
    }

    func sentence(at time: Double, duration: Double) -> Int? {
        guard duration > 0, !starts.isEmpty else { return nil }
        let fraction = time / duration
        return starts.lastIndex { $0 <= fraction }
    }
}

/// Lets the reading screen ask where a sentence sits, to keep it in view while following along.
@MainActor
final class ReaderController {
    fileprivate weak var textView: UITextView?

    /// The sentence's bounding box in the text view's coordinates.
    func rect(of range: NSRange) -> CGRect? {
        guard let textView else { return nil }
        let layout = textView.layoutManager
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layout.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
    }
}

/// Read-only entry text with the active sentence highlighted in a soft rounded box.
struct ReaderText: UIViewRepresentable {
    var document: ReaderDocument
    var active: Int?
    var controller: ReaderController
    var onTapSentence: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let storage = NSTextStorage()
        let layout = HighlightLayoutManager()
        layout.textLineHeight = Newsreader.uiFont(ReaderDocument.fontSize).lineHeight
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let textView = UITextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        controller.textView = textView
        context.coordinator.apply(to: textView, reload: true)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let reload = context.coordinator.parent.document.paragraphs != document.paragraphs
        context.coordinator.parent = self
        context.coordinator.apply(to: textView, reload: reload)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return CGSize(width: width, height: uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }

    final class Coordinator: NSObject {
        var parent: ReaderText
        private var shownActive: Int?

        init(parent: ReaderText) { self.parent = parent }

        func apply(to textView: UITextView, reload: Bool) {
            let storage = textView.textStorage
            if reload {
                storage.setAttributedString(parent.document.text)
                shownActive = nil
            }
            guard shownActive != parent.active || reload else { return }
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
            if let i = parent.active, i < parent.document.sentences.count {
                let range = parent.document.sentences[i]
                if NSMaxRange(range) <= storage.length {
                    storage.addAttribute(.backgroundColor, value: Palette.UI.yap100, range: range)
                }
            }
            storage.endEditing()
            shownActive = parent.active
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let point = gesture.location(in: textView)
            let index = textView.layoutManager.characterIndex(for: point, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if let sentence = parent.document.sentences.firstIndex(where: { NSLocationInRange(index, NSRange(location: $0.location, length: $0.length + 1)) }) {
                parent.onTapSentence(sentence)
            }
        }
    }
}

/// Draws background highlights as rounded boxes hugging the glyphs (2pt padding, 4pt
/// corners) instead of TextKit's full-line rectangles.
final class HighlightLayoutManager: NSLayoutManager {
    var textLineHeight: CGFloat = 18.5

    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<CGRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: UIColor) {
        color.setFill()
        for i in 0..<rectCount {
            let r = rectArray[i]
            let box = CGRect(x: r.minX - 2, y: r.minY - 1, width: r.width + 4, height: min(r.height, textLineHeight) + 2)
            UIBezierPath(roundedRect: box, cornerRadius: 4).fill()
        }
    }
}
