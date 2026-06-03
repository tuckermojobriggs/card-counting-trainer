import SwiftUI

/// One-time welcome flow shown on first launch. Three pages: intro, tab tour, difficulty pick.
/// Once dismissed (Skip or Done), `session.hasSeenOnboarding` flips true and the sheet never
/// shows again — there's no way to re-trigger it from the UI.
struct WelcomeSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                introPage.tag(0)
                tabTourPage.tag(1)
                difficultyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            footer
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header (Skip)

    private var header: some View {
        HStack {
            Spacer()
            Button("Skip") { complete() }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Footer (Back / Next / Done)

    private var footer: some View {
        HStack {
            if page > 0 {
                Button {
                    withAnimation { page -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            } else {
                // Reserve space so the Next/Done button stays right-aligned without jumping.
                Color.clear.frame(width: 80, height: 1)
            }
            Spacer()
            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    complete()
                }
            } label: {
                Text(page < 2 ? "Next" : "Done")
                    .frame(minWidth: 60)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }

    // MARK: - Page 1: Intro

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "suit.spade.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
            Text("Card Counting Trainer")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A blackjack trainer that grades every decision, tracks the count for you, and quizzes you as you learn.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 2: Tab tour

    private var tabTourPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Around the app")
                    .font(.title.weight(.bold))
                Text("Four tabs along the bottom. Here's what each one does.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 18) {
                tabRow(
                    icon: "suit.spade.fill",
                    name: "Play",
                    body: "Bet, hit, stand. Top of the screen tracks your bankroll, expected value, and perfect-play target. Tap the ? for a glossary."
                )
                tabRow(
                    icon: "list.bullet.rectangle",
                    name: "Strategy",
                    body: "Basic-strategy charts for every situation, count deviations, and a full High-Low walkthrough under Learn to count."
                )
                tabRow(
                    icon: "chart.bar.fill",
                    name: "Stats",
                    body: "Realized vs. Expected so you can tell skill from luck. Toggle between current session and lifetime numbers."
                )
                tabRow(
                    icon: "gearshape",
                    name: "Settings",
                    body: "Dealer rules, saved profiles, counting system, fast-dealing toggle, and the difficulty picker."
                )
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
    }

    private func tabRow(icon: String, name: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Page 3: Difficulty pick

    private var difficultyPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pick a starting difficulty")
                    .font(.title.weight(.bold))
                Text("You can switch any time from the ? on the Play screen or from Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Difficulty.allCases) { d in
                        difficultyButton(d)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func difficultyButton(_ d: Difficulty) -> some View {
        let isSelected = session.difficulty == d
        return Button {
            session.difficulty = d
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(d.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(d.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.18) : Color.gray.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Done

    private func complete() {
        session.hasSeenOnboarding = true
        dismiss()
    }
}
