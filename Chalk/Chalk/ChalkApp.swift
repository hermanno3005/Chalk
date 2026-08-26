import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    private let store = ChalkStore.open()

    var body: some Scene {
        WindowGroup {
            switch store {
            case .opened(let container):
                ContentView()
                    .modelContainer(container)
            case .failed(let storePath, _):
                StoreUnavailableView(storePath: storePath)
            }
        }
    }
}
