import SwiftUI
import UIKit
import CoreText

/// Newsreader (SIL OFL, bundled in `Yap/Fonts`) is the prototype's journal voice: the
/// italic "yap" wordmark, screen titles, entry titles and entry text. Everything else is
/// the system font, as in the prototype's `-apple-system` stack.
///
/// The bundled files are variable fonts with weight (200–800) and optical-size (6–72)
/// axes. Browsers set the optical size to the CSS pixel size automatically
/// (`font-optical-sizing: auto`), which is what gives the 100px wordmark its tighter
/// display cut and the 18px body its sturdier text cut — so each size here is built with
/// both axes set explicitly rather than relying on named instances.
enum Newsreader {
    private static let romanName = "Newsreader16pt-Regular"
    private static let italicName = "Newsreader16pt-Italic"
    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let opticalAxis = 0x6F70_737A // 'opsz'
    private static let lock = NSLock()
    private static var cache: [String: UIFont] = [:]

    /// Registers the bundled font files for this process. Called once from `YapApp.init`.
    static func register() {
        for file in ["Newsreader-Variable", "Newsreader-Italic-Variable"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func uiFont(_ size: CGFloat, weight: CGFloat = 400, italic: Bool = false) -> UIFont {
        let key = "\(size)-\(weight)-\(italic)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: italic ? italicName : romanName,
            kCTFontVariationAttribute: [
                weightAxis: weight,
                opticalAxis: min(72, max(6, size)),
            ],
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil) as UIFont
        cache[key] = font
        return font
    }
}

extension Font {
    /// Newsreader at a CSS pixel size and weight, e.g. `.news(34, 500)`.
    static func news(_ size: CGFloat, _ weight: CGFloat = 400, italic: Bool = false) -> Font {
        Font(Newsreader.uiFont(size, weight: weight, italic: italic) as CTFont)
    }

    /// The system font at a CSS pixel size (the prototype's `-apple-system` text).
    static func sf(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Newsreader's ascent + descent is exactly 1em with no line gap, so CSS line heights
    /// translate to SwiftUI line spacing as `(lineHeight - 1) * size`.
    func newsLines(_ size: CGFloat, lineHeight: CGFloat) -> some View {
        lineSpacing(max(0, (lineHeight - 1) * size))
    }

    /// SF Pro's natural line height is about 1.19em.
    func sfLines(_ size: CGFloat, lineHeight: CGFloat) -> some View {
        lineSpacing(max(0, (lineHeight - 1.19) * size))
    }
}

/// The italic lowercase "yap" wordmark.
struct Wordmark: View {
    var size: CGFloat
    var color: Color = Palette.yap

    var body: some View {
        Text("yap")
            .font(.news(size, 500, italic: true))
            .tracking(-0.035 * size)
            .foregroundStyle(color)
            .accessibilityLabel("Yap")
    }
}
