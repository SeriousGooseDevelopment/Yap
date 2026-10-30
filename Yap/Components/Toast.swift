import SwiftUI

/// The prototype's confirmation toast: a black pill that grows out of the Dynamic Island,
/// shows a check and a short message, then shrinks back into it. On phones without an
/// island it fades in under the status bar instead.
struct ToastOverlay: View {
    var toast: Toast?
    var safeTop: CGFloat

    @State private var text = ""
    @State private var visible = false
    @State private var expanded = false
    @State private var contentShown = false

    private var hasIsland: Bool { safeTop >= 51 }

    var body: some View {
        let width = expanded ? min(340, max(190, 70 + CGFloat(text.count) * 7.8)) : 126
        let height: CGFloat = expanded ? 46 : 37
        HStack(spacing: 8) {
            GlyphView(glyph: .check, size: 12, lineWidth: 3)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Palette.yap))
            Text(text)
                .font(.sf(14, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .opacity(contentShown ? 1 : 0)
        .scaleEffect(contentShown ? 1 : 0.9)
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(.black))
        .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
        .opacity(visible ? 1 : 0)
        .padding(.top, hasIsland ? 11 : safeTop + 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: toast?.id) { await run() }
    }

    private func pause(_ seconds: Double) async -> Bool {
        (try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))) != nil
    }

    private func run() async {
        guard let toast else { return }
        AccessibilityNotification.Announcement(toast.text).post()
        contentShown = false
        text = toast.text
        if hasIsland {
            // Starts exactly over the island, so appearing is invisible until it grows.
            visible = true
        } else {
            withAnimation(.easeOut(duration: 0.2)) { visible = true }
        }
        withAnimation(Motion.ios(0.36)) { expanded = true }
        guard await pause(0.24) else { return }
        withAnimation(.easeOut(duration: 0.26)) { contentShown = true }
        guard await pause(1.8) else { return }
        withAnimation(.easeIn(duration: 0.2)) { contentShown = false }
        guard hasIsland else {
            withAnimation(.easeOut(duration: 0.25)) { visible = false }
            guard await pause(0.25) else { return }
            expanded = false
            return
        }
        guard await pause(0.16) else { return }
        withAnimation(Motion.ios(0.34)) { expanded = false }
        guard await pause(0.34) else { return }
        withAnimation(.easeOut(duration: 0.12)) { visible = false }
    }
}
