import SwiftUI
import UIKit

/// A `UITextView`-backed transcript editor with plain, fully native text editing — tap to
/// place the cursor exactly where you tapped, drag to select or reposition, all standard
/// UIKit behavior. (This used to draw a custom Apple-Watch-style box around whichever word
/// the cursor was on, with matching custom tap/drag handling to drive it — removed by
/// request as an unnecessary layer on top of editing that already works fine natively.)
struct EditableTranscriptView: UIViewRepresentable {
    @Binding var text: String
    var textColor: UIColor
    var accentColor: UIColor
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var lineSpacing: CGFloat = 6
    /// Called when editing ends (keyboard dismissed / tapped away) and the text is empty —
    /// a journal entry with no text is meaningless, so this deletes it rather than leaving
    /// a blank row sitting in the entry list, matching `Store.commitEntry`'s own "an empty
    /// transcript isn't saved" rule for newly-recorded entries.
    var onEmptyCommit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: { text = $0 }, onEmptyCommit: onEmptyCommit)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.tintColor = accentColor
        textView.accessibilityLabel = "Journal entry"
        textView.accessibilityHint = "Edit the transcript"
        applyAttributedText(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let textChanged = textView.text != text
        let fontChanged = textView.font?.pointSize != fontSize
        let colorChanged = textView.textColor.isEqual(textColor) == false
        if textChanged || fontChanged || colorChanged {
            applyAttributedText(to: textView, preserveSelection: !textChanged)
        }
        textView.tintColor = accentColor
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    private func applyAttributedText(to textView: UITextView, preserveSelection: Bool = false) {
        let selection = textView.selectedRange
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        textView.attributedText = NSAttributedString(string: text, attributes: attrs)
        textView.typingAttributes = attrs
        if preserveSelection {
            let location = min(selection.location, textView.attributedText.length)
            let length = min(selection.length, textView.attributedText.length - location)
            textView.selectedRange = NSRange(location: location, length: length)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let onTextChange: (String) -> Void
        private let onEmptyCommit: (() -> Void)?

        init(onTextChange: @escaping (String) -> Void, onEmptyCommit: (() -> Void)?) {
            self.onTextChange = onTextChange
            self.onEmptyCommit = onEmptyCommit
        }

        func textViewDidChange(_ textView: UITextView) {
            onTextChange(textView.text)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onEmptyCommit?()
            }
        }

        /// `isScrollEnabled = false` (see makeUIView) means the text view can't keep its
        /// own caret visible above the keyboard — walk up to the real UIScrollView
        /// SwiftUI's ScrollView renders as (it's still a genuine UIScrollView in the
        /// rendered hierarchy) and ask it directly. Without this, editing near the bottom
        /// of a long note could leave the cursor hidden under the keyboard with no way to
        /// see what you're typing. Fires on every cursor move — tap, drag, selection
        /// handles, arrow keys — whatever caused it.
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.isFirstResponder, let selectedRange = textView.selectedTextRange else { return }
            let caretRect = textView.caretRect(for: selectedRange.end)
            guard caretRect.width.isFinite, caretRect.height.isFinite else { return }
            var responder: UIView? = textView.superview
            while let r = responder, !(r is UIScrollView) { responder = r.superview }
            guard let scrollView = responder as? UIScrollView else { return }
            let rectInScrollView = textView.convert(caretRect, to: scrollView)
            scrollView.scrollRectToVisible(rectInScrollView.insetBy(dx: 0, dy: -60), animated: true)
        }
    }
}
