import SwiftUI

@main
struct YapApp: App {
    @StateObject private var prefs: Preferences
    @StateObject private var store: Store

    init() {
        Newsreader.register()
        let prefs = Preferences()
        _prefs = StateObject(wrappedValue: prefs)
        _store = StateObject(wrappedValue: Store(prefs: prefs))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(prefs)
                .environmentObject(store.lock)
                .preferredColorScheme(prefs.colorScheme)
                .tint(Palette.yap)
        }
    }
}
