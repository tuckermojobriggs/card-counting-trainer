import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) private var session
    @State private var showingWelcome = false

    var body: some View {
        TabView {
            GameView()
                .tabItem { Label("Play", systemImage: "suit.spade.fill") }

            StrategyView()
                .tabItem { Label("Strategy", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            // First launch only — the sheet flips the flag on dismiss and never reopens.
            if !session.hasSeenOnboarding { showingWelcome = true }
        }
        .sheet(isPresented: $showingWelcome) {
            WelcomeSheet()
        }
    }
}
