import SwiftUI

@main
struct CardCountingTrainerApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
