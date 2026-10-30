import SwiftUI

/// The prototype's icon set, drawn from its own SVG paths (24pt viewBox unless noted).
extension Glyph {
    static let lock = Glyph([rect(5, 10.25, 14, 10.5, r: 2.75), path("M8.25 10.25V7.75a3.75 3.75 0 0 1 7.5 0v2.5")])
    static let lockLarge = Glyph([rect(5, 10.25, 14, 10.5, r: 3), path("M8.75 10.25V7.5a3.25 3.25 0 0 1 6.5 0v2.75")])
    static let arrowRight = Glyph([path("M4.75 12h14.5M13.5 6.25L19.25 12l-5.75 5.75")])
    static let arrowRightLong = Glyph([path("M5 12h14M13.5 6.5L19 12l-5.5 5.5")])
    static let chevronLeft = Glyph([path("M14.5 5.5L8 12l6.5 6.5")])
    static let chevronRight = Glyph([path("M9.5 5.5L16 12l-6.5 6.5")])
    static let chevronDown = Glyph([path("M6.5 9.5L12 15l5.5-5.5")])
    static let mic = Glyph([rect(8.75, 2.75, 6.5, 11.5, r: 3.25), path("M5.5 11.25a6.5 6.5 0 0 0 13 0M12 17.75v3.5")])
    static let speech = Glyph([path("M4 10.5v3M8 8v8M12 4.5v15M16 8v8M20 10.5v3")])
    static let check = Glyph([path("M5.5 12.5l4 4 9-9")])
    static let search = Glyph([circle(10.75, 10.75, 6.25), path("M15.5 15.5l4.75 4.75")])
    static let waveSmall = Glyph([path("M3 10v4M6.5 8v8M10 5.5v13M13.5 8.5v7M17 6.5v11M20.5 10v4")])
    static let close = Glyph([path("M7 7l10 10M17 7L7 17")])
    static let closeLarge = Glyph([path("M6.5 6.5l11 11M17.5 6.5l-11 11")])
    static let pause = Glyph([rect(6.5, 4.5, 4, 15, r: 1.4, fill: true), rect(13.5, 4.5, 4, 15, r: 1.4, fill: true)])
    static let pauseWide = Glyph([rect(6.5, 5, 3.75, 14, r: 1.25, fill: true), rect(13.75, 5, 3.75, 14, r: 1.25, fill: true)])
    static let play = Glyph([filled("M8 5.6v12.8a1.1 1.1 0 0 0 1.68.94l10.1-6.4a1.1 1.1 0 0 0 0-1.88L9.68 4.66A1.1 1.1 0 0 0 8 5.6z")])
    static let ellipsis = Glyph([circle(5.5, 12, 1.75, fill: true), circle(12, 12, 1.75, fill: true), circle(18.5, 12, 1.75, fill: true)])
    static let format = Glyph([path("M3.5 18.5L8 6l4.5 12.5M5.1 14.25h5.8M20 13v5.5"), circle(17.25, 15.75, 2.75)])
    static let photo = Glyph([rect(3.25, 4.75, 17.5, 14.5, r: 3.25), circle(9, 10, 1.75), path("M20.5 15.5l-4.25-4.25L7 19")])
    static let share = Glyph([path("M12 14.5V3.75M8 7.5l4-3.75 4 3.75M7.5 10.5h-.75A1.75 1.75 0 0 0 5 12.25v6.5a1.75 1.75 0 0 0 1.75 1.75h10.5A1.75 1.75 0 0 0 19 18.75v-6.5a1.75 1.75 0 0 0-1.75-1.75h-.75")])
    static let back15 = Glyph([path("M4.75 12a7.25 7.25 0 1 0 2.2-5.2M4.5 3.75v3.5H8")])
    static let forward15 = Glyph([path("M19.25 12a7.25 7.25 0 1 1-2.2-5.2M19.5 3.75v3.5H16")])
    static let follow = Glyph([path("M4 6.5h16M4 11.5h10M4 16.5h13")])
    static let tabJournal = Glyph([path("M5 19.5V5a2.25 2.25 0 0 1 2.25-2.25H19v14.5H7.25A2.25 2.25 0 0 0 5 19.5a2.25 2.25 0 0 0 2.25 2.25H19M9 7h6")])
    static let tabInsights = Glyph([path("M5 20v-6M10 20V9M15 20v-4M20 20V5")])
    static let tabSettings = Glyph([path("M4 7.5h9M18 7.5h2M4 16.5h3M11 16.5h9"), circle(15.5, 7.5, 2.25), circle(9, 16.5, 2.25)])
    static let bell = Glyph([path("M6.25 16.75V11a5.75 5.75 0 0 1 11.5 0v5.75l1.5 2H4.75zM10 21a2.1 2.1 0 0 0 4 0")])
    static let voice = Glyph([path("M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3")])
    static let appearance = Glyph([circle(12, 12, 8.75), filled("M12 3.25a8.75 8.75 0 0 1 0 17.5z")])
    static let shield = Glyph([path("M12 3.25l7 2.75v5.6c0 4.3-2.9 7.6-7 9.15-4.1-1.55-7-4.85-7-9.15V6z")])
    static let export = Glyph([path("M4.75 13.75v4.5a2 2 0 0 0 2 2h10.5a2 2 0 0 0 2-2v-4.5M12 3.75v11M7.75 10.5L12 14.75l4.25-4.25")])
    static let help = Glyph([circle(12, 12, 8.75), path("M9.6 9.5a2.5 2.5 0 0 1 4.85.85c0 1.65-2.45 2.15-2.45 3.9"), circle(12, 17, 0.9, fill: true)])
    static let info = Glyph([circle(12, 12, 8.75), path("M12 11v5.5"), circle(12, 7.75, 0.9, fill: true)])
    static let trash = Glyph([path("M4.75 6.75h14.5M9.75 6.5V4.75h4.5V6.5M6.75 6.75l.8 12.6a1.5 1.5 0 0 0 1.5 1.4h5.9a1.5 1.5 0 0 0 1.5-1.4l.8-12.6M10 10.75v6M14 10.75v6")])

    /// Face ID frame (viewBox 2.5 2.5 19 19) with and without the face.
    private static let faceCorners = "M4 8V6.5A2.5 2.5 0 0 1 6.5 4H8M16 4h1.5A2.5 2.5 0 0 1 20 6.5V8M20 16v1.5a2.5 2.5 0 0 1-2.5 2.5H16M8 20H6.5A2.5 2.5 0 0 1 4 17.5V16"
    static let faceID = Glyph(viewBox: CGRect(x: 2.5, y: 2.5, width: 19, height: 19), [
        path(faceCorners + "M9 9.25v1.25M15 9.25v1.25M12 9.25v3.75h-1M9.5 15.75c1.4 1.1 3.6 1.1 5 0"),
    ])
    static let faceFrame = Glyph(viewBox: CGRect(x: 2.5, y: 2.5, width: 19, height: 19), [path(faceCorners)])
    static let faceTick = SVGPath.parse("M8.25 12.25l2.6 2.6 4.9-5.35")

    // Privacy pills (screen 03).
    static let pillMic = Glyph([rect(9, 3, 6, 11, r: 3), path("M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21")])
    static let pillWave = Glyph([path("M3.5 10.5v3M7 8v8M10.5 4.5v15M14 7.5v9M17.5 9.5v5M21 11v2")])
    static let pillShield = Glyph([path("M12 3l7 3v5.5c0 4.5-3 7.7-7 9.5-4-1.8-7-5-7-9.5V6l7-3z")])
    static let pillPhone = Glyph([rect(7, 2.5, 10, 19, r: 2.5), path("M11 18.5h2")])
    static let pillSpark = Glyph([
        path("M11 4l1.8 4.7 4.7 1.8-4.7 1.8L11 17l-1.8-4.7-4.7-1.8 4.7-1.8z"),
        path("M18.5 15l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"),
    ])
}

/// The skip-back / skip-forward icons carry a "15" set in the SVG's own text box.
struct SkipGlyph: View {
    var forward: Bool
    var size: CGFloat = 30

    var body: some View {
        let scale = size / 24
        GlyphView(glyph: forward ? .forward15 : .back15, size: size, lineWidth: 1.6)
            .overlay(alignment: .topLeading) {
                Text("15")
                    .font(.system(size: 6.4 * scale, weight: .bold))
                    .fixedSize()
                    .frame(width: 12 * scale, height: 8 * scale)
                    .position(x: (forward ? 11.6 : 12.4) * scale, y: 12.75 * scale)
            }
    }
}
