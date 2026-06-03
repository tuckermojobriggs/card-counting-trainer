import Foundation

/// Multi-deck S17 LS DAS basic strategy. Single-deck and H17 differ in a handful of cells,
/// which we patch via `ruleAdjustment(...)` rather than maintaining six separate charts.
enum BasicStrategy {

    /// The recommended action for a hand vs. a dealer upcard, ignoring count deviations.
    /// Pass the set of currently-legal actions so we never recommend an illegal move
    /// (e.g. recommending "double" after a hit, which the engine would reject).
    static func recommend(
        hand: Hand,
        dealerUpcard: Card,
        rules: DealerRules,
        legal: Set<PlayerAction>
    ) -> PlayerAction {
        let raw = rawRecommendation(hand: hand, dealerUpcard: dealerUpcard, rules: rules)
        return resolve(raw, with: hand, legal: legal)
    }

    /// "Pure" basic strategy result, before legality filtering. Useful if you want to display
    /// "the optimal action would have been X (illegal here, fallback Y)".
    static func rawRecommendation(
        hand: Hand,
        dealerUpcard: Card,
        rules: DealerRules
    ) -> PlayerAction {
        if let pair = hand.pairRank, hand.cards.count == 2, !hand.fromSplit || rules.resplitAces || pair != .ace {
            // Pairs (or check pair-resplit eligibility)
            let action = pairAction(pair: pair, upcard: dealerUpcard.rank, rules: rules)
            if action != nil { return action! }
        }

        if hand.isSoft && hand.cards.count >= 2 {
            // Soft totals A,X
            return softAction(total: hand.total, upcard: dealerUpcard.rank, rules: rules)
        }

        // Hard totals (also catches non-soft post-hit states)
        return hardAction(total: hand.total, upcard: dealerUpcard.rank, rules: rules)
    }

    /// Apply legality filter: if the chart says "double" but doubles aren't allowed here, hit instead;
    /// if it says "split" but we can't, fall back to the underlying hard/soft recommendation; etc.
    private static func resolve(_ action: PlayerAction, with hand: Hand, legal: Set<PlayerAction>) -> PlayerAction {
        if legal.contains(action) { return action }
        switch action {
        case .double:
            // Double-falls-back-to: hit if legal (we want to draw); otherwise stand for soft 18+.
            if legal.contains(.hit) {
                // For some soft hands (A,7 vs 3-6) where double is the chart but not allowed (post-hit),
                // basic strategy says stand instead. Approximate: if total >= 18 stand, else hit.
                if hand.isSoft && hand.total >= 18 && legal.contains(.stand) { return .stand }
                return .hit
            }
            return legal.contains(.stand) ? .stand : (legal.first ?? .stand)
        case .split:
            // If we can't split, treat as the hard/soft equivalent.
            if hand.cards.first?.rank == .ace {
                // A,A treated as soft 12 (basically, hit)
                return legal.contains(.hit) ? .hit : .stand
            }
            // Pairs of 5: treat as 10. Pairs of 10: stand. Others fall back to hard total.
            return legal.contains(.hit) ? .hit : .stand
        case .surrender:
            return legal.contains(.stand) ? .stand : .hit
        default:
            return legal.first ?? .stand
        }
    }

    // MARK: - Charts

    private static func hardAction(total: Int, upcard: Rank, rules: DealerRules) -> PlayerAction {
        let up = upcard.blackjackValue
        switch total {
        case ...8:  return .hit
        case 9:     return (3...6).contains(up) ? .double : .hit
        case 10:    return up <= 9 ? .double : .hit
        case 11:    return rules.dealerHitsSoft17 ? .double : (up <= 10 ? .double : .hit)
        case 12:    return (4...6).contains(up) ? .stand : .hit
        case 13, 14:return (2...6).contains(up) ? .stand : .hit
        case 15:
            if (2...6).contains(up) { return .stand }
            if up == 10 && rules.surrender != .none { return .surrender }
            return .hit
        case 16:
            if (2...6).contains(up) { return .stand }
            if (9...11).contains(up) && rules.surrender != .none { return .surrender }
            return .hit
        case 17:
            // H17: surrender 17 vs A (per Wong). For S17 always stand.
            if rules.dealerHitsSoft17 && up == 11 && rules.surrender != .none { return .surrender }
            return .stand
        case 18...:
            return .stand
        default:
            return .stand
        }
    }

    private static func softAction(total: Int, upcard: Rank, rules: DealerRules) -> PlayerAction {
        let up = upcard.blackjackValue
        switch total {
        case 13, 14: // A,2  A,3
            return (5...6).contains(up) ? .double : .hit
        case 15, 16: // A,4  A,5
            return (4...6).contains(up) ? .double : .hit
        case 17:    // A,6
            return (3...6).contains(up) ? .double : .hit
        case 18:    // A,7
            // S17: D vs 3-6, S vs 2/7/8, H vs 9-A
            // H17: D vs 2-6, S vs 7-8, H vs 9-A
            if rules.dealerHitsSoft17 {
                if (2...6).contains(up) { return .double }
                if up == 7 || up == 8 { return .stand }
                return .hit
            } else {
                if (3...6).contains(up) { return .double }
                if up == 2 || up == 7 || up == 8 { return .stand }
                return .hit
            }
        case 19:    // A,8
            if rules.dealerHitsSoft17 && up == 6 { return .double }
            return .stand
        case 20, 21:
            return .stand
        default:
            return .hit
        }
    }

    /// Returns nil if the pair shouldn't be split (caller falls through to hard/soft).
    private static func pairAction(pair: Rank, upcard: Rank, rules: DealerRules) -> PlayerAction? {
        let up = upcard.blackjackValue
        let das = rules.doubleAfterSplit
        switch pair {
        case .ace: return .split
        case .ten: return .stand
        case .nine:
            if up == 7 || up == 10 || up == 11 { return .stand }
            return .split
        case .eight:
            // Pair of 8s: split always, except some H17 8+deck books say surrender vs A.
            if rules.dealerHitsSoft17 && up == 11 && rules.surrender != .none && rules.deckCount >= 4 {
                return .surrender
            }
            return .split
        case .seven:
            return up <= 7 ? .split : nil
        case .six:
            if up == 2 { return das ? .split : nil }
            return (3...6).contains(up) ? .split : nil
        case .five:
            return nil       // never split 5s; treat as hard 10
        case .four:
            return das && (5...6).contains(up) ? .split : nil
        case .three, .two:
            if (2...3).contains(up) { return das ? .split : nil }
            return (4...7).contains(up) ? .split : nil
        default:
            return nil
        }
    }
}

/// Hi-Lo Illustrious 18 + Fab 4 deviations on top of basic strategy.
/// True-count thresholds; positive deviations override "the chart" at high counts.
enum CountDeviations {

    /// Returns a deviation action, or nil to use plain basic strategy.
    static func override(
        hand: Hand,
        dealerUpcard: Card,
        trueCount: Double,
        rules: DealerRules,
        legal: Set<PlayerAction>
    ) -> PlayerAction? {
        let up = dealerUpcard.rank.blackjackValue
        let total = hand.total

        // Insurance is handled separately by the engine; not returned as a player action here.

        if hand.cards.count == 2 && !hand.fromSplit {
            // Doubles
            if total == 11 && up == 11 && trueCount >= 1, legal.contains(.double) { return .double }
            if total == 10 && up == 10 && trueCount >= 4, legal.contains(.double) { return .double }
            if total == 10 && up == 11 && trueCount >= 4, legal.contains(.double) { return .double }
            if total == 9  && up == 2  && trueCount >= 1, legal.contains(.double) { return .double }
            if total == 9  && up == 7  && trueCount >= 3, legal.contains(.double) { return .double }
            if total == 8  && up == 6  && trueCount >= 2, legal.contains(.double) { return .double }
        }

        // Stands (override hits)
        if !hand.isSoft {
            if total == 16 && up == 10 && trueCount >= 0, legal.contains(.stand) { return .stand }
            if total == 16 && up == 9  && trueCount >= 5, legal.contains(.stand) { return .stand }
            if total == 15 && up == 10 && trueCount >= 4, legal.contains(.stand) { return .stand }
            if total == 13 && up == 2  && trueCount >= -1, legal.contains(.stand) { return .stand }
            if total == 13 && up == 3  && trueCount >= -2, legal.contains(.stand) { return .stand }
            if total == 12 && up == 2  && trueCount >= 3, legal.contains(.stand) { return .stand }
            if total == 12 && up == 3  && trueCount >= 2, legal.contains(.stand) { return .stand }
            if total == 12 && up == 4  && trueCount >= 0, legal.contains(.stand) { return .stand }
            if total == 12 && up == 5  && trueCount >= -2, legal.contains(.stand) { return .stand }
            if total == 12 && up == 6  && trueCount >= -1, legal.contains(.stand) { return .stand }
        }

        // Splits — 10,10 vs 5/6 at high count is famous but rarely worth the EV; included for completeness.
        if let pair = hand.pairRank, pair == .ten {
            if up == 5 && trueCount >= 5, legal.contains(.split) { return .split }
            if up == 6 && trueCount >= 4, legal.contains(.split) { return .split }
        }

        // Fab 4 surrender deviations
        if rules.surrender != .none, hand.cards.count == 2, !hand.fromSplit, legal.contains(.surrender) {
            if total == 14 && up == 10 && trueCount >= 3 { return .surrender }
            if total == 15 && up == 9  && trueCount >= 2 { return .surrender }
            if total == 15 && up == 10 && trueCount >= 0 { return .surrender }
            if total == 15 && up == 11 && trueCount >= (rules.dealerHitsSoft17 ? 0 : 1) { return .surrender }
        }

        return nil
    }

    /// Whether to take insurance given true count. Hi-Lo says +3; other systems vary.
    static func shouldTakeInsurance(trueCount: Double, threshold: Double) -> Bool {
        trueCount >= threshold
    }
}

/// Combined basic + count strategy.
enum Strategy {
    static func recommend(
        hand: Hand,
        dealerUpcard: Card,
        trueCount: Double,
        rules: DealerRules,
        legal: Set<PlayerAction>
    ) -> PlayerAction {
        if let dev = CountDeviations.override(
            hand: hand,
            dealerUpcard: dealerUpcard,
            trueCount: trueCount,
            rules: rules,
            legal: legal
        ) {
            return dev
        }
        return BasicStrategy.recommend(hand: hand, dealerUpcard: dealerUpcard, rules: rules, legal: legal)
    }
}
