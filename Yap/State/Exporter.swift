import Foundation
import UIKit

/// Settings › Export and the reading screen's share menu.
enum Exporter {
    static func plainText(_ entry: JournalEntry) -> String {
        ([entry.displayTitle] + entry.paragraphs.map(InlineMarkdown.plain)).joined(separator: "\n\n")
    }

    static func markdown(_ entry: JournalEntry) -> String {
        "# \(entry.displayTitle)\n\n*\(meta(entry))*\n\n" + entry.paragraphs.joined(separator: "\n\n") + "\n"
    }

    private static func meta(_ entry: JournalEntry) -> String {
        "\(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) · \(Fmt.time(entry.date)) · \(Fmt.minutes(entry))"
    }

    static func journalMarkdown(_ entries: [JournalEntry]) -> String {
        "# Yap journal\n\n" + entries.map { entry in
            "## \(entry.displayTitle)\n\n*\(meta(entry))*\n\n" + entry.paragraphs.joined(separator: "\n\n")
        }.joined(separator: "\n\n---\n\n") + "\n"
    }

    static func journalPlainText(_ entries: [JournalEntry]) -> String {
        entries.map { entry in
            ([entry.displayTitle, meta(entry)] + entry.paragraphs.map(InlineMarkdown.plain)).joined(separator: "\n\n")
        }.joined(separator: "\n\n\n")
    }

    /// Paginated US Letter PDF, laid out by UIKit's HTML print formatter.
    static func journalPDF(_ entries: [JournalEntry]) -> Data {
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        func html(_ paragraph: String) -> String {
            InlineMarkdown.runs(paragraph).map { run in
                var t = escape(run.text)
                if run.italic { t = "<i>\(t)</i>" }
                if run.bold { t = "<b>\(t)</b>" }
                return t
            }.joined()
        }
        let body = entries.map { entry in
            "<h2>\(escape(entry.displayTitle))</h2><p class=meta>\(escape(meta(entry)))</p>"
                + entry.paragraphs.map { "<p>\(html($0))</p>" }.joined()
        }.joined(separator: "<hr>")
        let page = """
        <html><head><style>
        body { font-family: Georgia, serif; font-size: 12pt; line-height: 1.5; color: #0D1B2E; }
        h1 { font-style: italic; color: #2F6BF2; font-weight: 500; }
        h2 { font-weight: 500; margin-bottom: 2pt; }
        .meta { font-family: -apple-system, sans-serif; font-size: 9pt; color: #4F5D73; margin-top: 0; }
        hr { border: 0; border-top: 0.5pt solid #ccd; margin: 18pt 0; }
        </style></head><body><h1>yap</h1>\(body)</body></html>
        """
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: page), startingAtPageAt: 0)
        let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
        renderer.setValue(paper, forKey: "paperRect")
        renderer.setValue(paper.insetBy(dx: 54, dy: 54), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    /// Writes the whole journal in `format` to a temporary file for the share sheet.
    static func exportJournal(_ entries: [JournalEntry], format: Preferences.ExportFormat) -> URL? {
        let sorted = entries.sorted { $0.date > $1.date }
        switch format {
        case .markdown: return write(Data(journalMarkdown(sorted).utf8), name: "Yap Journal.md")
        case .plainText: return write(Data(journalPlainText(sorted).utf8), name: "Yap Journal.txt")
        case .pdf: return write(journalPDF(sorted), name: "Yap Journal.pdf")
        }
    }

    static func markdownFile(_ entry: JournalEntry) -> URL? {
        let safe = entry.displayTitle.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        return write(Data(markdown(entry).utf8), name: (safe.isEmpty ? "Yap entry" : safe) + ".md")
    }

    private static func write(_ data: Data, name: String) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Presents the system share sheet from the top-most view controller.
@MainActor
enum SharePresenter {
    static func present(_ items: [Any], completion: ((Bool) -> Void)? = nil) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in completion?(completed) }
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}
