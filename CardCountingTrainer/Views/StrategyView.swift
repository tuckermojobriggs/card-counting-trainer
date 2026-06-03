import SwiftUI

/// Strategy reference. Quick must-knows on top, then collapsed sections for the full rules — tap a
/// section header to expand it. Targets the multi-deck stands-soft-17 double-after-split late-surrender
/// baseline (the same chart the trainer grades against) with notes for the hits-soft-17 variants where
/// they matter.
struct StrategyView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HowToCountView()
                    } label: {
                        sectionLabel(title: "Learn to count",
                                     subtitle: "Full walkthrough of the High-Low system with worked examples.")
                    }
                }

                Section {
                    quickRule("Always split aces and eights.")
                    quickRule("Never split fives or tens.")
                    quickRule("Surrender hard 16 versus dealer 9, 10, or Ace; hard 15 versus 10.")
                    quickRule("Stand on any hard total of 17 or higher.")
                    quickRule("Take insurance only when the true count is at least +3.")
                } header: {
                    Text("Quick rules")
                } footer: {
                    Text("These are the must-knows. Tap any section below for the full rules on that situation.")
                }

                Section("Decisions by topic") {
                    DisclosureGroup {
                        doublingContent
                    } label: {
                        sectionLabel(title: "When to double",
                                     subtitle: "Press your bet on hands the math favors.")
                    }
                    DisclosureGroup {
                        splittingContent
                    } label: {
                        sectionLabel(title: "When to split",
                                     subtitle: "Turn one hand into two — only when it improves expected outcome.")
                    }
                    DisclosureGroup {
                        surrenderContent
                    } label: {
                        sectionLabel(title: "When to surrender",
                                     subtitle: "Forfeit half your bet on the worst-case hands.")
                    }
                    DisclosureGroup {
                        insuranceContent
                    } label: {
                        sectionLabel(title: "Insurance",
                                     subtitle: "Almost always a bad bet — only take it when the count is high.")
                    }
                }

                Section("Full charts") {
                    DisclosureGroup {
                        hardTotalsContent
                    } label: {
                        sectionLabel(title: "Hard totals",
                                     subtitle: "Hands without a usable Ace.")
                    }
                    DisclosureGroup {
                        softTotalsContent
                    } label: {
                        sectionLabel(title: "Soft totals",
                                     subtitle: "Hands containing an Ace counted as 11.")
                    }
                    DisclosureGroup {
                        pairsContent
                    } label: {
                        sectionLabel(title: "Pair splitting",
                                     subtitle: "Decisions when both your cards are the same rank.")
                    }
                }

                Section("Advanced") {
                    DisclosureGroup {
                        deviationsContent
                    } label: {
                        sectionLabel(title: "Count deviations",
                                     subtitle: "Adjustments that kick in at specific true counts. Skip until basic strategy is automatic.")
                    }
                }
            }
            .navigationTitle("Strategy")
        }
    }

    // MARK: - Section content

    private var doublingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("Hard 9", "Double versus dealer 3 through 6.")
            strategyRow("Hard 10", "Double versus dealer 2 through 9.")
            strategyRow("Hard 11", "Double versus dealer 2 through 10. Hit versus Ace (stands-soft-17 rules); double versus Ace if dealer hits soft 17.")
            strategyRow("Soft 13 (Ace, 2)", "Double versus 5 or 6.")
            strategyRow("Soft 14 (Ace, 3)", "Double versus 5 or 6.")
            strategyRow("Soft 15 (Ace, 4)", "Double versus 4, 5, or 6.")
            strategyRow("Soft 16 (Ace, 5)", "Double versus 4, 5, or 6.")
            strategyRow("Soft 17 (Ace, 6)", "Double versus 3 through 6.")
            strategyRow("Soft 18 (Ace, 7)", "Double versus 3 through 6 (stands soft 17). If the dealer hits soft 17, double versus 2 as well.")
            strategyRow("Soft 19 (Ace, 8)", "Double versus 6 only when the dealer hits soft 17. Otherwise stand.")
            explainer("Doubling commits you to exactly one more card with twice the bet. The break-even is high — only worth it when the math gives you a real edge on the average outcome.")
        }
    }

    private var splittingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("Aces", "Always split. Two strong starting hands beat one soft 12.")
            strategyRow("Eights", "Always split. Hard 16 is the worst hand in blackjack — splitting turns one bad hand into two okay ones.")
            strategyRow("Twos and threes", "Split versus 2 through 7 when double-after-split is allowed; otherwise split only versus 4 through 7.")
            strategyRow("Fours", "Split only versus 5 or 6 when double-after-split is allowed. Otherwise hit.")
            strategyRow("Fives", "Never split — treat as hard 10 and double versus 2 through 9.")
            strategyRow("Sixes", "Split versus 2 through 6 (and versus 2 only when double-after-split is allowed).")
            strategyRow("Sevens", "Split versus 2 through 7.")
            strategyRow("Nines", "Split versus 2 through 6, 8, or 9. Stand versus 7, 10, or Ace.")
            strategyRow("Tens", "Never split — twenty is too strong to break up. Exception: at very high counts, see below.")
            explainer("Splitting either rescues a bad hand (eights) or presses an advantage by adding a second bet to a strong starting position.")

            Divider().padding(.vertical, 4)

            Text("How the count changes things")
                .font(.callout.weight(.semibold))
                .padding(.top, 2)

            strategyRow("Tens versus 5", "Split at true count ≥ +5. The shoe is so rich in ten-valued cards that two starting twenties win even more than one — and the dealer's bust 5 makes them a lock.")
            strategyRow("Tens versus 6", "Split at true count ≥ +4. Same logic, slightly looser threshold because the dealer's 6 is the worst-bust upcard.")
            strategyRow("Pair of eights versus Ace", "On hits-soft-17 multi-deck shoes, surrender (instead of split) at any count. The trainer's default rules keep this as a normal split.")

            explainer("When the deck runs hot for the player (positive true count = high cards remaining), splitting becomes more attractive in general — every new hand is more likely to start with a ten or ace. The two ten-pair plays above are the only ones in the Illustrious 18 list, but the principle generalizes: at high counts, lean toward the more aggressive of two close decisions.")

            Text("For surrender deviations and the rest of the count-based plays, see Advanced → Count deviations.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var surrenderContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("Hard 16 vs 9", "Surrender. Both hit and stand average worse than −0.5.")
            strategyRow("Hard 16 vs 10", "Surrender.")
            strategyRow("Hard 16 vs Ace", "Surrender.")
            strategyRow("Hard 15 vs 10", "Surrender.")
            strategyRow("Hard 17 vs Ace", "Surrender — but only when the dealer hits soft 17. Otherwise stand.")
            strategyRow("Pair of eights vs Ace", "In some hits-soft-17 multi-deck games, surrender beats splitting. Trainer's default rules don't trigger this.")
            explainer("Surrender forfeits half your bet. You only choose it when both hit and stand have expected value worse than −0.5 — surrendering is the lesser of three evils.")
        }
    }

    private var insuranceContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A side bet — half your original wager — that pays 2 to 1 if the dealer has a ten in the hole. Only offered when the dealer shows an Ace.")
                .font(.callout)
            Text("Insurance is positive expected value only when the probability of a ten exceeds one-third. At a fresh shoe that probability is roughly 30%, so it's a losing bet by default.")
                .font(.callout)
            Text("For counters using High-Low, the rule of thumb is to take insurance when the true count is at least +3. The trainer grades each insurance decision against the actual visible-card probability — see the feedback bar after a Take or Decline.")
                .font(.callout)
        }
    }

    private var hardTotalsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("8 or less", "Always hit.")
            strategyRow("9", "Double versus 3 through 6, otherwise hit.")
            strategyRow("10", "Double versus 2 through 9, otherwise hit.")
            strategyRow("11", "Double versus 2 through 10. Hit versus Ace (stands soft 17).")
            strategyRow("12", "Stand versus 4, 5, or 6, otherwise hit.")
            strategyRow("13 or 14", "Stand versus 2 through 6, otherwise hit.")
            strategyRow("15", "Stand versus 2 through 6. Surrender versus 10. Otherwise hit.")
            strategyRow("16", "Stand versus 2 through 6. Surrender versus 9, 10, or Ace. Otherwise hit.")
            strategyRow("17 or higher", "Always stand.")
        }
    }

    private var softTotalsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("Soft 13 / 14 (Ace, 2 or Ace, 3)", "Double versus 5 or 6. Otherwise hit.")
            strategyRow("Soft 15 / 16 (Ace, 4 or Ace, 5)", "Double versus 4, 5, or 6. Otherwise hit.")
            strategyRow("Soft 17 (Ace, 6)", "Double versus 3 through 6. Otherwise hit. Never stand on soft 17.")
            strategyRow("Soft 18 (Ace, 7)", "Stand versus 2, 7, or 8. Double versus 3 through 6. Hit versus 9, 10, or Ace.")
            strategyRow("Soft 19 (Ace, 8)", "Stand. If the dealer hits soft 17, double versus 6.")
            strategyRow("Soft 20 (Ace, 9)", "Always stand.")
            explainer("Soft hands can't bust on a single hit — the Ace flips from 11 to 1 if the total goes over 21. That's why hitting a soft 17 is safe and standing is wrong.")
        }
    }

    private var pairsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            strategyRow("Aces", "Always split.")
            strategyRow("Twos / Threes", "Split versus 2 through 7 (with double-after-split). Otherwise hit.")
            strategyRow("Fours", "Split only versus 5 or 6 (with double-after-split). Otherwise hit.")
            strategyRow("Fives", "Never split — treat as hard 10. Double versus 2 through 9.")
            strategyRow("Sixes", "Split versus 2 through 6 (versus 2 only with double-after-split). Otherwise hit.")
            strategyRow("Sevens", "Split versus 2 through 7. Otherwise hit.")
            strategyRow("Eights", "Always split.")
            strategyRow("Nines", "Split versus 2 through 6, 8, or 9. Stand versus 7, 10, or Ace.")
            strategyRow("Tens", "Never split — stand.")
        }
    }

    private var deviationsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strategy adjustments that kick in at specific High-Low true counts. Listed roughly in order of expected-value impact.")
                .font(.callout)

            Text("Illustrious 18")
                .font(.callout.weight(.semibold))
            Group {
                deviationRow("Insurance", "Take at true count ≥ +3.")
                deviationRow("16 vs 10", "Stand at true count ≥ 0.")
                deviationRow("15 vs 10", "Stand at true count ≥ +4.")
                deviationRow("12 vs 3", "Stand at true count ≥ +2.")
                deviationRow("12 vs 2", "Stand at true count ≥ +3.")
                deviationRow("11 vs Ace", "Double at true count ≥ +1.")
                deviationRow("9 vs 2", "Double at true count ≥ +1.")
            }
            Group {
                deviationRow("10 vs 10", "Double at true count ≥ +4.")
                deviationRow("9 vs 7", "Double at true count ≥ +3.")
                deviationRow("16 vs 9", "Stand at true count ≥ +5.")
                deviationRow("13 vs 2", "Stand at true count ≥ −1.")
                deviationRow("12 vs 4", "Stand at true count ≥ 0.")
                deviationRow("12 vs 5", "Stand at true count ≥ −2.")
                deviationRow("12 vs 6", "Stand at true count ≥ −1.")
                deviationRow("13 vs 3", "Stand at true count ≥ −2.")
                deviationRow("10 vs Ace", "Double at true count ≥ +4.")
                deviationRow("Tens vs 5", "Split at true count ≥ +5.")
                deviationRow("Tens vs 6", "Split at true count ≥ +4.")
            }

            Divider()

            Text("Fab 4 surrender deviations")
                .font(.callout.weight(.semibold))
            deviationRow("14 vs 10", "Surrender at true count ≥ +3.")
            deviationRow("15 vs 9", "Surrender at true count ≥ +2.")
            deviationRow("15 vs Ace", "Surrender at true count ≥ +1 (stands soft 17) or ≥ 0 (hits soft 17).")

            explainer("These are advanced. Get basic strategy automatic first, then layer these on. The trainer already grades against the count-aware optimal, so playing perfect basic strategy will register some 'best play was X' feedback at high counts — that's where the deviations live.")
        }
    }

    // MARK: - Building blocks

    private func sectionLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private func quickRule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
    }

    private func strategyRow(_ situation: String, _ action: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(situation)
                .font(.callout.weight(.semibold))
            Text(action)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func deviationRow(_ situation: String, _ action: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(situation)
                .font(.callout.weight(.semibold))
            Spacer()
            Text(action)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func explainer(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}
