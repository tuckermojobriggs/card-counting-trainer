import SwiftUI

/// Full tutorial on the High-Low system: why counting works, the tags, how to convert running count to
/// true count, and how to act on it. Reached from a "Learn to count" link at the top of the Strategy
/// tab. Designed to be read top to bottom by someone who has never counted before.
struct HowToCountView: View {
    var body: some View {
        List {
            whyCount
            theHiLoSystem
            practiceDrills
            trueCount
            usingTheCount
            tips
        }
        .navigationTitle("How to count")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 1. Why count?

    private var whyCount: some View {
        Section {
            paragraph("Casino blackjack is dealt from a finite shoe. Cards don't come back until the dealer reshuffles, so the composition of what's left changes as the round goes on.")
            paragraph("High cards (ten, Jack, Queen, King, Ace) favor the player. Player blackjacks pay 3-to-2, dealer blackjacks only break even on the original wager, and the dealer is forced to hit stiff totals 12 through 16 — every ten left in the deck is another chance for the dealer to bust.")
            paragraph("Low cards (2 through 6) favor the dealer for the mirror reason. They turn dealer busts into safe seventeens and eighteens.")
            paragraph("Counting tracks this imbalance. When the deck runs heavy in high cards, you bet bigger and play slightly more aggressively. When it runs heavy in low cards, you bet the minimum and play textbook basic strategy.")
        } header: {
            Text("Why count?")
        } footer: {
            Text("The whole edge from counting is the bet ramp. Playing every hand at one unit, perfect basic strategy still loses to a small house edge — counting moves money to the hands you're favored to win.")
        }
    }

    // MARK: - 2. The High-Low tags

    private var theHiLoSystem: some View {
        Section {
            paragraph("High-Low assigns a tag to every card. You add the tag to a running total — the running count — each time a card is revealed.")
            tagTable
            paragraph("A 2 through 6 adds one. A 7, 8, or 9 changes nothing. A ten-valued card or an Ace subtracts one.")
            paragraph("Across a full deck the tags sum to zero — five low ranks balance five high ranks. That's why High-Low is called a balanced system, and it's why the running count starts at zero after every shuffle.")
            Divider().padding(.vertical, 4)
            Text("Worked example")
                .font(.callout.weight(.semibold))
            paragraph("Cards revealed, in order: 8, King, 4, Ace, 5, Jack, 2, 7, 6, Queen.")
            workedSequence
            paragraph("Running count after the ten cards: 0. Five high cards (King, Ace, Jack, Queen, plus the ten implicit in Jack) cancel five low cards (4, 5, 2, 6, and the 8/7 which are neutral). The shoe is exactly as balanced as it started.")
        } header: {
            Text("The High-Low tags")
        }
    }

    private var tagTable: some View {
        VStack(spacing: 6) {
            tagRow(cards: "2  3  4  5  6", tag: "+1", color: .green)
            tagRow(cards: "7  8  9",         tag: " 0", color: .secondary)
            tagRow(cards: "10  J  Q  K  A", tag: "−1", color: .red)
        }
        .padding(.vertical, 6)
    }

    private func tagRow(cards: String, tag: String, color: Color) -> some View {
        HStack {
            Text(cards)
                .font(.callout.weight(.semibold).monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tag)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var workedSequence: some View {
        VStack(alignment: .leading, spacing: 4) {
            sequenceLine(card: "8",    tag:  "0", running:  0)
            sequenceLine(card: "King", tag: "−1", running: -1)
            sequenceLine(card: "4",    tag: "+1", running:  0)
            sequenceLine(card: "Ace",  tag: "−1", running: -1)
            sequenceLine(card: "5",    tag: "+1", running:  0)
            sequenceLine(card: "Jack", tag: "−1", running: -1)
            sequenceLine(card: "2",    tag: "+1", running:  0)
            sequenceLine(card: "7",    tag:  "0", running:  0)
            sequenceLine(card: "6",    tag: "+1", running:  1)
            sequenceLine(card: "Queen",tag: "−1", running:  0)
        }
        .padding(.top, 4)
    }

    private func sequenceLine(card: String, tag: String, running: Int) -> some View {
        HStack {
            Text(card)
                .font(.callout.monospaced())
                .frame(width: 70, alignment: .leading)
            Text(tag)
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(width: 40, alignment: .center)
                .foregroundStyle(.secondary)
            Text("running: \(formatRunning(running))")
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatRunning(_ n: Int) -> String {
        n >= 0 ? "+\(n)" : "\(n)"
    }

    // MARK: - 3. Practice drills

    private var practiceDrills: some View {
        Section {
            paragraph("The goal is to track the count at the casino's dealing speed without your face giving anything away. Three habits get you there:")
            bulletRow("Watch every card the dealer turns face up — both player hands and the dealer's own draws. The dealer's hole card stays hidden until the end of the round, then add its tag when it's revealed.")
            bulletRow("Count in pairs. A 5 and a King sum to zero — skip the math entirely. A 6 and a 2 sum to +2. Pairing up neutral combinations is how counters keep pace.")
            bulletRow("Use the in-app drill. The Help screen on the Play tab has a 'Test my running count' button that hands you a card-by-card check against the real shoe.")
            paragraph("When you can call the running count correctly through an entire shoe at the speed the trainer deals, you're ready for the next piece.")
        } header: {
            Text("Practice drills")
        }
    }

    // MARK: - 4. True count

    private var trueCount: some View {
        Section {
            paragraph("Running count alone doesn't tell you how concentrated the imbalance is. A running count of +6 with six decks still to deal is barely meaningful — that's only one extra high card per deck. The same +6 with one deck left is a flood of high cards.")
            paragraph("The fix is dividing by decks remaining.")
            formulaCard("True count  =  Running count  ÷  Decks remaining")
            paragraph("At a real table you eyeball the discard tray and round to the nearest half deck. The trainer shows you 'cards left' exactly, so you can divide by that number over 52.")
            Divider().padding(.vertical, 4)
            Text("Two worked examples")
                .font(.callout.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                exampleRow(rc: "+6", left: "156 cards (3 decks)", tc: "+2")
                exampleRow(rc: "+6", left: "52 cards (1 deck)",   tc: "+6")
                exampleRow(rc: "−4", left: "104 cards (2 decks)", tc: "−2")
            }
            paragraph("Same running count, very different true count, very different decision. The true count is what drives bet sizing and the strategy deviations.")
        } header: {
            Text("Running count to true count")
        }
    }

    private func formulaCard(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold).monospaced())
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func exampleRow(rc: String, left: String, tc: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Running \(rc), \(left)")
                    .font(.callout)
            }
            Spacer()
            Text("True \(tc)")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 5. Using the count

    private var usingTheCount: some View {
        Section {
            Text("Bet sizing")
                .font(.callout.weight(.semibold))
            paragraph("A simple ramp: bet one unit when the true count is +1 or below, then add a unit for each +1 above that.")
            VStack(alignment: .leading, spacing: 4) {
                betRow("True count ≤ +1", "1 unit (base bet)")
                betRow("True count +2",   "2 units")
                betRow("True count +3",   "3 units")
                betRow("True count +4",   "4 units")
                betRow("True count +5 or higher", "5+ units")
            }
            Divider().padding(.vertical, 4)
            Text("Strategy deviations")
                .font(.callout.weight(.semibold))
            paragraph("At specific true counts the optimal play changes from the chart. The big ones:")
            VStack(alignment: .leading, spacing: 4) {
                deviationLine("Insurance",  "Take when true count is +3 or higher.")
                deviationLine("16 versus dealer 10", "Stand when true count is 0 or higher; otherwise hit.")
                deviationLine("15 versus dealer 10", "Stand when true count is +4 or higher.")
                deviationLine("12 versus dealer 3",  "Stand when true count is +2 or higher.")
                deviationLine("11 versus dealer Ace", "Double when true count is +1 or higher.")
            }
            paragraph("The full list is in the Strategy tab under Advanced → Count deviations. Don't worry about these until basic strategy is automatic — the trainer will tell you when a deviation costs you.")
        } header: {
            Text("Using the count")
        } footer: {
            Text("Bigger bets in good situations are where the actual money lives. Deviations matter, but they're small adjustments next to bet sizing.")
        }
    }

    private func betRow(_ trueCount: String, _ bet: String) -> some View {
        HStack {
            Text(trueCount)
                .font(.callout)
            Spacer()
            Text(bet)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func deviationLine(_ situation: String, _ rule: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(situation)
                .font(.callout.weight(.semibold))
            Text(rule)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - 6. Tips

    private var tips: some View {
        Section {
            bulletRow("Keep your lips still. New counters whisper the count under their breath — that's the easiest tell at a casino.")
            bulletRow("Don't change your face when the count climbs. Pit bosses watch for the moment a player suddenly perks up.")
            bulletRow("Count every card that turns face up. Player draws, dealer draws, hole cards revealed at the end of the round — every one of them carries a tag.")
            bulletRow("Cards that go to the discard tray without being shown are unknown. There aren't many of those in practice, but if a player surrenders without revealing both cards, you only get to count what you saw.")
            bulletRow("After a shuffle, the running count resets to zero. The trainer handles this automatically when the shoe reshuffles.")
            bulletRow("Don't try multiple counting systems at once. Master High-Low, then look at the others if you want a small edge. Mixing tags will make you worse than picking one.")
            bulletRow("Practice with the Medium and Hard difficulty modes in this app. Medium blocks every action until your tracked count matches the actual count. Hard hides every helper and pops a count quiz 10% of the time — wrong answers tell you Higher or Lower until you land on the right number.")
        } header: {
            Text("Tips")
        }
    }

    // MARK: - Building blocks

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .padding(.vertical, 2)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}
