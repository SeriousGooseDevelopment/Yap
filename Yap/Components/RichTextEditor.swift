import SwiftUI
import UIKit

extension NSAttributedString.Key {
    static let yapBold = NSAttributedString.Key("yap.bold")
    static let yapItalic = NSAttributedString.Key("yap.italic")
}

/// Body text styling shared by the writing editor and the reader.
enum JournalText {
    static func font(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        Newsreader.uiFont(size, weight: bold ? 700 : 400, italic: italic)
    }

    static func paragraphStyle(size: CGFloat, lineHeight: CGFloat, paragraphSpacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = max(0, (lineHeight - 1) * size)
        style.paragraphSpacing = paragraphSpacing
        return style
    }

    /// Paragraph strings with `InlineMarkdown` spans → one attributed string, one line per
    /// paragraph.
    static func attributed(_ paragraphs: [String], size: CGFloat, lineHeight: CGFloat, paragraphSpacing: CGFloat) -> NSMutableAttributedString {
        let style = paragraphStyle(size: size, lineHeight: lineHeight, paragraphSpacing: paragraphSpacing)
        let result = NSMutableAttributedString()
        for (i, paragraph) in paragraphs.enumerated() {
            if i > 0 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes(size: size, style: style)))
            }
            for run in InlineMarkdown.runs(paragraph) {
                var attrs = baseAttributes(size: size, style: style)
                attrs[.font] = font(size: size, bold: run.bold, italic: run.italic)
                attrs[.yapBold] = run.bold
                attrs[.yapItalic] = run.italic
                result.append(NSAttributedString(string: run.text, attributes: attrs))
            }
        }
        return result
    }

    static func baseAttributes(size: CGFloat, style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        [.font: font(size: size, bold: false, italic: false), .foregroundColor: Palette.UI.ink, .paragraphStyle: style,
         .yapBold: false, .yapItalic: false]
    }

    /// Attributed text → paragraphs joined by blank lines, styled runs wrapped in markers.
    static func markdown(from text: NSAttributedString) -> String {
        var paragraphs: [String] = [""]
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attrs, range, _ in
            let bold = attrs[.yapBold] as? Bool ?? false
            let italic = attrs[.yapItalic] as? Bool ?? false
            let pieces = (text.string as NSString).substring(with: range).components(separatedBy: "\n")
            for (i, piece) in pieces.enumerated() {
                if i > 0 { paragraphs.append("") }
                paragraphs[paragraphs.count - 1] += InlineMarkdown.wrap(piece, bold: bold, italic: italic)
            }
        }
        return paragraphs
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

/// Handle the writing screen's Format menu uses to style the editor's selection.
@MainActor
final class RichTextController {
    fileprivate weak var textView: UITextView?
    fileprivate var lastSelection = NSRange(location: 0, length: 0)
    fileprivate var onEdit: (() -> Void)?

    var hasSelection: Bool { lastSelection.length > 0 && textView != nil }

    func focus() { textView?.becomeFirstResponder() }

    /// Toggles bold or italic over the current selection. Returns false when nothing is selected.
    @discardableResult
    func toggle(_ key: NSAttributedString.Key) -> Bool {
        guard let textView, lastSelection.length > 0,
              NSMaxRange(lastSelection) <= textView.textStorage.length else { return false }
        let storage = textView.textStorage
        let range = lastSelection
        var allSet = true
        storage.enumerateAttribute(key, in: range) { value, _, _ in
            if (value as? Bool) != true { allSet = false }
        }
        storage.beginEditing()
        storage.enumerateAttributes(in: range) { attrs, sub, _ in
            var bold = attrs[.yapBold] as? Bool ?? false
            var italic = attrs[.yapItalic] as? Bool ?? false
            if key == .yapBold { bold = !allSet } else { italic = !allSet }
            storage.addAttributes([
                .yapBold: bold, .yapItalic: italic,
                .font: JournalText.font(size: RichTextEditor.fontSize, bold: bold, italic: italic),
            ], range: sub)
        }
        storage.endEditing()
        textView.selectedRange = range
        onEdit?()
        return true
    }
}

/// The writing screen's body editor: Newsreader 19.5/1.58, 16pt between paragraphs, with
/// bold and italic spans. A `UITextView` so selection-based formatting and native editing
/// behave exactly like the system.
struct RichTextEditor: UIViewRepresentable {
    static let fontSize: CGFloat = 19.5
    static let lineHeight: CGFloat = 1.58
    static let paragraphSpacing: CGFloat = 16

    @Binding var markdown: String
    /// Reloads the text when it changes from outside (a recording appended, Clean Up).
    var revision: Int
    /// Paragraphs from this index fade in after a reload.
    var appendedFrom: Int?
    var controller: RichTextController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.tintColor = Palette.UI.yap
        textView.delegate = context.coordinator
        textView.accessibilityLabel = "Entry text"
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        controller.textView = textView
        controller.onEdit = { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else { return }
            coordinator?.textChanged(textView)
        }
        load(textView, coordinator: context.coordinator)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.revision != revision {
            load(textView, coordinator: context.coordinator)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, Self.fontSize * Self.lineHeight))
    }

    private func load(_ textView: UITextView, coordinator: Coordinator) {
        coordinator.revision = revision
        let paragraphs = JournalEntry.paragraphs(in: markdown)
        let text = JournalText.attributed(paragraphs, size: Self.fontSize, lineHeight: Self.lineHeight, paragraphSpacing: Self.paragraphSpacing)
        textView.attributedText = text
        textView.typingAttributes = JournalText.baseAttributes(
            size: Self.fontSize,
            style: JournalText.paragraphStyle(size: Self.fontSize, lineHeight: Self.lineHeight, paragraphSpacing: Self.paragraphSpacing)
        )
        if let from = appendedFrom, from < paragraphs.count, !reduceMotion {
            coordinator.fadeIn(textView, paragraphs: paragraphs, from: from)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var revision = -1
        private var fadeTimer: Timer?

        init(parent: RichTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) { textChanged(textView) }

        func textChanged(_ textView: UITextView) {
            let markdown = JournalText.markdown(from: textView.attributedText)
            if markdown != parent.markdown { parent.markdown = markdown }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller.lastSelection = textView.selectedRange
            keepCaretVisible(textView)
        }

        /// New paragraphs from a recording fade in one after another (`yapWord`).
        func fadeIn(_ textView: UITextView, paragraphs: [String], from: Int) {
            fadeTimer?.invalidate()
            let ns = textView.textStorage.string as NSString
            var ranges: [NSRange] = []
            var location = 0
            for (i, paragraph) in paragraphs.enumerated() {
                let length = (InlineMarkdown.plain(paragraph) as NSString).length
                if i >= from, location + length <= ns.length { ranges.append(NSRange(location: location, length: length)) }
                location += length + 1
            }
            let start = Date()
            let apply = { [weak textView] in
                guard let textView else { return true }
                let t = Date().timeIntervalSince(start)
                var done = true
                textView.textStorage.beginEditing()
                for (j, range) in ranges.enumerated() where NSMaxRange(range) <= textView.textStorage.length {
                    let p = min(1, max(0, (t - 0.22 - Double(j) * 0.14) / 0.7))
                    if p < 1 { done = false }
                    textView.textStorage.addAttribute(.foregroundColor, value: Palette.UI.ink.withAlphaComponent(p), range: range)
                }
                textView.textStorage.endEditing()
                return done
            }
            _ = apply()
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { timer in
                Task { @MainActor in
                    if apply() { timer.invalidate() }
                }
            }
        }

        /// With scrolling disabled the text view can't keep its own caret above the
        /// keyboard, so ask the enclosing scroll view SwiftUI renders.
        private func keepCaretVisible(_ textView: UITextView) {
            guard textView.isFirstResponder, let selected = textView.selectedTextRange else { return }
            let caret = textView.caretRect(for: selected.end)
            guard caret.width.isFinite, caret.height.isFinite else { return }
            var view: UIView? = textView.superview
            while let v = view, !(v is UIScrollView) { view = v.superview }
            guard let scrollView = view as? UIScrollView else { return }
            scrollView.scrollRectToVisible(textView.convert(caret, to: scrollView).insetBy(dx: 0, dy: -60), animated: true)
        }

        deinit { fadeTimer?.invalidate() }
    }
}
