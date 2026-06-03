import SwiftUI

/// Onboarding / glossary explaining what each piece of the Play screen means. Surfaced from the question
/// mark in the toolbar. Also has a button into the running-count quiz for self-testing.
struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            List {
                Section {
                    difficultyChoice(.easy,
                        body: "Hand totals, running count, and true count are all visible. Best for learning basic strategy without juggling the count.")
                    difficultyChoice(.casual,
                        body: "Hand totals are hidden — you add up your own cards. Running count and true count are still visible so you can focus on totals first.")
                    difficultyChoice(.medium,
                        body: "Hand totals and the actual count are both hidden. You track the count yourself with the minus and plus buttons. The trainer blocks every action — deal, hit, stand, insurance — until your tracked count matches the actual count. The true count and edge shown are derived from the count you typed.")
                    difficultyChoice(.hard,
                        body: "All count helpers are gone — no running count, no true count, no edge, no minus and plus buttons. You count in your head. Every action carries a 10% chance the trainer pops a count quiz; wrong answers shake the prompt and tell you Higher or Lower until you land on the right number.")
                } header: {
                    Text("Difficulty")
                } footer: {
                    Text("Tap a level to switch — your choice syncs with Settings.")
                }
                Section("Top counters") {
                    helpRow(
                        title: "Bankroll",
                        body: "Your chips right now. Wins add, losses subtract. Reset Session puts it back to $1,000."
                    )
                    helpRow(
                        title: "Expected",
                        body: "What your decisions are worth on average across this session. Each round adds the rules-and-count baseline (≈ −0.10% × bet at neutral count, climbing about 0.5% per unit of true count). Each suboptimal decision subtracts its dollar cost. Wipes with Reset Session; the Stats tab keeps a lifetime version."
                    )
                    helpRow(
                        title: "Perfect",
                        body: "What perfect play would have averaged at the counts you saw — Expected plus your cumulative skill cost. Perfect minus Expected is exactly the money you've left on the table this session by mis-playing."
                    )
                }
                Section("Counting") {
                    helpRow(
                        title: "Running count",
                        body: "High-Low running tally. Cards 2–6 add +1, 7–9 are 0, tens and aces subtract 1. Updates every time a card is revealed. Shown directly on Easy and Casual; hidden on Medium and Hard."
                    )
                    helpRow(
                        title: "True count",
                        body: "Running count divided by decks remaining. This is the count that drives strategy deviations and bet sizing — raw running count alone doesn't tell you how concentrated the imbalance is."
                    )
                    helpRow(
                        title: "Edge",
                        body: "Your expected edge per hand at the current true count. Roughly 0.5% per +1 of true count above the rules baseline. Green means you have the advantage; red means the house does."
                    )
                    helpRow(
                        title: "Cards left",
                        body: "Cards remaining in the shoe before the dealer reshuffles. Reshuffle happens at the penetration mark (default 75% of the shoe dealt)."
                    )
                    helpRow(
                        title: "Count bar (Medium)",
                        body: "On Medium difficulty a strip with a minus button, your tracked count, and a plus button appears just above the action buttons. Tap minus or plus as each card comes out. The trainer refuses to deal or hit until your tracked count matches the actual count."
                    )
                }
                Section("Action buttons") {
                    helpRow(
                        title: "Hit",
                        body: "Take another card. You can keep hitting until you stand or bust (over 21)."
                    )
                    helpRow(
                        title: "Stand",
                        body: "No more cards. Lock in your current total and pass play to the dealer (or the next split hand)."
                    )
                    helpRow(
                        title: "Double",
                        body: "Double your bet, take exactly one more card, then stand. Only legal as your first action on a hand."
                    )
                    helpRow(
                        title: "Split",
                        body: "Only with a pair: split into two hands, each with the same bet as the original. Each new hand plays independently."
                    )
                    helpRow(
                        title: "Surrender",
                        body: "Forfeit half your bet and end the hand. Only legal as your first action. Right call on hard 16 vs dealer 9, 10, or Ace, and hard 15 vs 10."
                    )
                    helpRow(
                        title: "Insurance",
                        body: "Side bet appearing only when the dealer's upcard is an Ace. Pays 2:1 if the dealer has a ten in the hole. Take it only when the probability of a ten exceeds one-third — usually means the count has run high."
                    )
                }
                Section("Feedback") {
                    helpRow(
                        title: "Green check",
                        body: "Your decision matched the highest-expected-value choice given the actual remaining shoe."
                    )
                    helpRow(
                        title: "Red X",
                        body: "There was a better play. The trainer shows what it was and how much expected value you gave up in dollars per bet."
                    )
                    helpRow(
                        title: "Action blocked (Medium)",
                        body: "If your tracked count doesn't match the actual count, every action button is refused and a yellow banner tells you the target value to adjust to. Tap the minus or plus button until the banner disappears, then act."
                    )
                    helpRow(
                        title: "Count quiz (Hard)",
                        body: "Roughly one in ten actions on Hard pops a count check before the action runs. Type in your tracked count and tap Submit. A right answer flashes green and the action proceeds. A wrong answer shakes the prompt and tells you Higher or Lower until you land on it."
                    )
                }
                Section("Toolbar") {
                    helpRow(
                        title: "Reset (top left)",
                        body: "Reset Session — returns bankroll to $1,000, wipes session stats, reshuffles the shoe, and resets the count. Lifetime stats on the Stats tab are untouched. Asks to confirm first."
                    )
                    helpRow(
                        title: "Help (top right)",
                        body: "This screen — quick glossary plus a difficulty switcher at the top."
                    )
                }
                Section("Other tabs") {
                    helpRow(
                        title: "Strategy",
                        body: "Basic-strategy charts, count deviations, and a full High-Low tutorial under \"Learn to count\"."
                    )
                    helpRow(
                        title: "Stats",
                        body: "Summary cards, bankroll chart, and hand outcome / performance details for whichever scope is selected. A Session / Lifetime picker at the top toggles between your current sitting and the all-time totals; defaults to Session. A Reset button at the bottom acts on the currently-selected scope."
                    )
                    helpRow(
                        title: "Settings",
                        body: "Difficulty picker, dealer rules and saved profiles, counting system, default bet, and a Fast dealing toggle that skips the card-deal animation."
                    )
                }
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func difficultyChoice(_ d: Difficulty, body: String) -> some View {
        let isSelected = session.difficulty == d
        return Button {
            if !isSelected { session.difficulty = d }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(d.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.green.opacity(0.18) : nil)
    }
}
