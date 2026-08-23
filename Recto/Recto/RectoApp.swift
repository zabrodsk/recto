import SwiftUI

@main
struct RectoApp: App {
    @State private var store = AppStore.load()
    @Environment(\.(scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        store.flushPersist()
                    }
                }
        }
    }
}
