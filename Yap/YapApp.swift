import SwiftUI

@main
struct YapApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(store.appearanceOverride)
                .environmentObject(store)
        }
    }
}
