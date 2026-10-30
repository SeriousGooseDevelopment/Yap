import SwiftUI

/// Parses SVG path data (`d` attributes) into a SwiftUI `Path`, so the prototype's own
/// stroked icons and the Yap mark can be drawn exactly instead of approximated with SF
/// Symbols. Supports every path command (M L H V C S Q T A Z, absolute and relative).
/// Shared by the app and the Live Activity widget.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var scanner = Scanner(Array(data.utf8))
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: UInt8 = 0
        var command: UInt8 = 0

        while true {
            scanner.skipSeparators()
            guard let byte = scanner.peek() else { break }
            if Scanner.isCommand(byte) {
                command = byte
                scanner.advance()
            } else if command == 0 {
                break
            }
            let relative = command >= UInt8(ascii: "a")
            let base = relative ? current : .zero
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: base.x + x, y: base.y + y)
            }

            switch command | 0x20 {
            case UInt8(ascii: "m"):
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = point(x, y)
                start = current
                path.move(to: current)
                lastControl = nil
                // Coordinate pairs after a moveto are implicit linetos.
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
                lastCommand = UInt8(ascii: "m")
                continue
            case UInt8(ascii: "l"):
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = point(x, y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "h"):
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "v"):
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "c"):
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: point(x1, y1), control2: c2)
                lastControl = c2
            case UInt8(ascii: "s"):
                guard let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c1 = reflected(lastControl, about: current, if: [UInt8(ascii: "c"), UInt8(ascii: "s")].contains(lastCommand | 0x20))
                let c2 = point(x2, y2)
                current = point(x, y)
                path.addCurve(to: current, control1: c1, control2: c2)
                lastControl = c2
            case UInt8(ascii: "q"):
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c = point(x1, y1)
                current = point(x, y)
                path.addQuadCurve(to: current, control: c)
                lastControl = c
            case UInt8(ascii: "t"):
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                let c = reflected(lastControl, about: current, if: [UInt8(ascii: "q"), UInt8(ascii: "t")].contains(lastCommand | 0x20))
                current = point(x, y)
                path.addQuadCurve(to: current, control: c)
                lastControl = c
            case UInt8(ascii: "a"):
                guard let rx = scanner.number(), let ry = scanner.number(), let rotation = scanner.number(),
                      let largeArc = scanner.flag(), let sweep = scanner.flag(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let end = point(x, y)
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, rotation: rotation, largeArc: largeArc, sweep: sweep)
                current = end
                lastControl = nil
            case UInt8(ascii: "z"):
                path.closeSubpath()
                current = start
                lastControl = nil
                // Closepath takes no arguments, so it never repeats implicitly.
                lastCommand = command
                command = 0
                continue
            default:
                return path
            }
            lastCommand = command
        }
        return path
    }

    private static func reflected(_ control: CGPoint?, about point: CGPoint, if condition: Bool) -> CGPoint {
        guard condition, let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// Endpoint-parameterised elliptical arc (SVG 1.1 appendix F.6.5), approximated with
    /// one cubic Bézier per quarter turn.
    private static func addArc(to path: inout Path, from p1: CGPoint, to p2: CGPoint, rx: CGFloat, ry: CGFloat,
                               rotation: CGFloat, largeArc: Bool, sweep: Bool) {
        if p1 == p2 { return }
        var rx = abs(rx), ry = abs(ry)
        if rx == 0 || ry == 0 { path.addLine(to: p2); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx2 = (p1.x - p2.x) / 2, dy2 = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coefficient = (largeArc != sweep ? 1 : -1) * sqrt(max(0, numerator / denominator))
        let cxp = coefficient * rx * y1p / ry
        let cyp = coefficient * -ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let theta1 = angle(1, 0, ux, uy)
        var delta = angle(ux, uy, vx, vy)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2) - 0.001)))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)
        func map(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cosPhi * u - ry * sinPhi * v, y: cy + rx * sinPhi * u + ry * cosPhi * v)
        }
        var a = theta1
        for _ in 0..<segments {
            let b = a + step
            let c1 = map(cos(a) - t * sin(a), sin(a) + t * cos(a))
            let c2 = map(cos(b) + t * sin(b), sin(b) - t * cos(b))
            path.addCurve(to: map(cos(b), sin(b)), control1: c1, control2: c2)
            a = b
        }
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        static func isCommand(_ byte: UInt8) -> Bool {
            switch byte | 0x20 {
            case UInt8(ascii: "m"), UInt8(ascii: "l"), UInt8(ascii: "h"), UInt8(ascii: "v"),
                 UInt8(ascii: "c"), UInt8(ascii: "s"), UInt8(ascii: "q"), UInt8(ascii: "t"),
                 UInt8(ascii: "a"), UInt8(ascii: "z"):
                return true
            default:
                return false
            }
        }

        func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }
        mutating func advance() { index += 1 }

        mutating func skipSeparators() {
            while let b = peek(), b == UInt8(ascii: " ") || b == UInt8(ascii: ",") || b == UInt8(ascii: "\n")
                || b == UInt8(ascii: "\t") || b == UInt8(ascii: "\r") {
                index += 1
            }
        }

        /// Arc flags may be written without separators ("a1 1 0 011 1").
        mutating func flag() -> Bool? {
            skipSeparators()
            guard let b = peek(), b == UInt8(ascii: "0") || b == UInt8(ascii: "1") else { return nil }
            index += 1
            return b == UInt8(ascii: "1")
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = index
            if let b = peek(), b == UInt8(ascii: "-") || b == UInt8(ascii: "+") { index += 1 }
            var sawDot = false
            var sawDigit = false
            while let b = peek() {
                if b >= UInt8(ascii: "0") && b <= UInt8(ascii: "9") {
                    sawDigit = true
                    index += 1
                } else if b == UInt8(ascii: "."), !sawDot {
                    sawDot = true
                    index += 1
                } else {
                    break
                }
            }
            if sawDigit, let b = peek(), b == UInt8(ascii: "e") || b == UInt8(ascii: "E") {
                index += 1
                if let s = peek(), s == UInt8(ascii: "-") || s == UInt8(ascii: "+") { index += 1 }
                while let d = peek(), d >= UInt8(ascii: "0") && d <= UInt8(ascii: "9") { index += 1 }
            }
            guard sawDigit, let text = String(bytes: bytes[begin..<index], encoding: .ascii),
                  let value = Double(text) else {
                index = begin
                return nil
            }
            return CGFloat(value)
        }
    }
}

/// An SVG drawing in its own viewBox, made of stroked and filled parts. Scales to any frame.
struct Glyph {
    enum Part {
        case stroke(Path)
        case fill(Path)
    }

    var viewBox: CGRect
    var parts: [Part]

    init(viewBox: CGRect, _ parts: [Part]) {
        self.viewBox = viewBox
        self.parts = parts
    }

    /// A glyph in the prototype's standard 24×24 viewBox.
    init(_ parts: [Part]) {
        self.init(viewBox: CGRect(x: 0, y: 0, width: 24, height: 24), parts)
    }

    static func path(_ d: String) -> Part { .stroke(SVGPath.parse(d)) }
    static func filled(_ d: String) -> Part { .fill(SVGPath.parse(d)) }
    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat, fill: Bool = false) -> Part {
        let p = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        return fill ? .fill(p) : .stroke(p)
    }
    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, fill: Bool = false) -> Part {
        let p = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        return fill ? .fill(p) : .stroke(p)
    }
}

/// Draws a `Glyph` at `size` with the prototype's stroke width (in viewBox units).
struct GlyphView: View {
    let glyph: Glyph
    var size: CGFloat
    var lineWidth: CGFloat = 1.8

    var body: some View {
        let scale = size / glyph.viewBox.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: -glyph.viewBox.minX, y: -glyph.viewBox.minY)
        ZStack {
            ForEach(glyph.parts.indices, id: \.self) { i in
                switch glyph.parts[i] {
                case .stroke(let path):
                    path.applying(transform)
                        .stroke(style: StrokeStyle(lineWidth: lineWidth * scale, lineCap: .round, lineJoin: .round))
                case .fill(let path):
                    path.applying(transform).fill()
                }
            }
        }
        .frame(width: size, height: glyph.viewBox.height * scale)
        .accessibilityHidden(true)
    }
}

extension Glyph {
    /// The Yap mark: a voice waveform flowing into two written lines (32pt viewBox).
    static let yapMark = Glyph(viewBox: CGRect(x: 0, y: 0, width: 32, height: 32), [
        path("M5.3 16H6.9C7.3 18 7.6 19.6 8.1 19.6C8.9 19.6 9.4 12.4 10.4 12.4C11.4 12.4 11.8 20.2 12.7 20.2C13.7 20.2 14.1 11.8 15.1 11.8C16.1 11.8 16.4 18.6 17.3 18.6C18.3 18.6 18.7 12.8 19.8 12.8C20.8 12.8 21 17.2 22 17.2C22.6 17.2 23 16.6 23.4 16H26.7"),
        path("M18.6 21.2H26M18.6 24H23.6"),
    ])
}
