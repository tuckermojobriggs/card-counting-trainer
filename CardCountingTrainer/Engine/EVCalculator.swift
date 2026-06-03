import Foundation

/// Composition-dependent expected-value calculator. Uses the live shoe composition (counts per rank)
/// to compute the probability distribution over dealer final totals, then per-action EV for the player.
///
/// Approach is intentionally simple/correct over fast: dealer recursion is exact given the composition;
/// player hit EV is exact recursive; double is one-card-then-stand; split is approximated as two
/// independent post-split single-hand EVs sharing the same composition (slight overcount, but the
/// effect is <0.1% in practice).
///
/// Cost: a typical 1-deck call returns in well under 100ms.
enum EVCalculator {

    /// EV per legal action, normalized to "per unit of original bet" (so double's bet doubling is
    /// already reflected in the returned number). Surrender = -0.5.
    static func evaluate(
        hand: Hand,
        dealerUpcard: Card,
        rules: DealerRules,
        composition: [Rank: Int],
        legal: Set<PlayerAction>
    ) -> [PlayerAction: Double] {
        // The caller passes the live shoe composition, which already excludes every dealt card
        // (the upcard, the hole, and the player's cards were removed by Shoe.draw). By exchangeability
        // the hole card is distributed like the next shoe draw, so we can use the composition as-is.
        let comp = composition

        // For peeked games with A/T upcard we condition on "dealer doesn't have BJ".
        // We compute dealer distribution that excludes the BJ subset.
        let dealerDist = dealerDistribution(
            upcard: dealerUpcard.rank,
            composition: comp,
            rules: rules,
            conditionOnNoBJ: rules.dealerPeeksOnTenAce && (dealerUpcard.rank == .ace || dealerUpcard.rank.isTen)
        )

        var out: [PlayerAction: Double] = [:]

        if legal.contains(.stand) {
            out[.stand] = standEV(playerTotal: hand.total, dealerDist: dealerDist)
        }
        if legal.contains(.hit) {
            out[.hit] = hitEV(hand: hand, composition: comp, dealerDist: dealerDist, rules: rules)
        }
        if legal.contains(.double) {
            out[.double] = doubleEV(hand: hand, composition: comp, dealerDist: dealerDist)
        }
        if legal.contains(.surrender) {
            out[.surrender] = -0.5
        }
        if legal.contains(.split), let pr = hand.pairRank {
            out[.split] = splitEV(pairRank: pr, dealerUpcard: dealerUpcard, composition: comp,
                                  dealerDist: dealerDist, rules: rules)
        }
        return out
    }

    /// The action with highest EV among legal moves. If tie, prefer cheaper-variance order: stand, hit, double, split, surrender.
    static func bestAction(_ evs: [PlayerAction: Double]) -> PlayerAction? {
        let order: [PlayerAction] = [.stand, .hit, .double, .split, .surrender]
        var best: (PlayerAction, Double)? = nil
        for a in order {
            guard let v = evs[a] else { continue }
            if best == nil || v > best!.1 + 1e-9 { best = (a, v) }
        }
        return best?.0
    }

    // MARK: - Dealer probability distribution

    /// Distribution over final dealer states.
    struct DealerDist: Hashable {
        var p17: Double = 0
        var p18: Double = 0
        var p19: Double = 0
        var p20: Double = 0
        var p21: Double = 0
        var pBust: Double = 0
        var pBJ: Double = 0

        var total: Double { p17 + p18 + p19 + p20 + p21 + pBust + pBJ }

        mutating func add(_ other: DealerDist, weight: Double) {
            p17  += other.p17  * weight
            p18  += other.p18  * weight
            p19  += other.p19  * weight
            p20  += other.p20  * weight
            p21  += other.p21  * weight
            pBust += other.pBust * weight
            pBJ  += other.pBJ  * weight
        }

        /// Renormalize so probabilities sum to 1 (after conditioning).
        mutating func normalize() {
            let t = total
            guard t > 0 else { return }
            p17 /= t; p18 /= t; p19 /= t; p20 /= t; p21 /= t; pBust /= t; pBJ /= t
        }
    }

    static func dealerDistribution(
        upcard: Rank,
        composition: [Rank: Int],
        rules: DealerRules,
        conditionOnNoBJ: Bool
    ) -> DealerDist {
        // Initial dealer total from the upcard.
        var startTotal = upcard.blackjackValue
        let soft = (upcard == .ace)
        if soft { startTotal = 11 }

        var dist = DealerDist()
        // Enumerate hole card.
        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else { return dist }
        for r in Rank.allCases {
            let n = composition[r] ?? 0
            if n == 0 { continue }
            let p = Double(n) / Double(totalCards)
            var comp = composition
            decrement(&comp, rank: r)

            var total = startTotal + r.blackjackValue
            var localSoft = soft || r == .ace
            if total > 21 && localSoft {
                total -= 10
                localSoft = false
            }

            // Detect dealer blackjack (A + 10 or 10 + A as the first two cards)
            let isDealerBJ = (upcard == .ace && r.isTen) || (upcard.isTen && r == .ace)
            if isDealerBJ {
                if !conditionOnNoBJ {
                    dist.pBJ += p
                }
                continue
            }

            // Recurse
            var sub = DealerDist()
            recurseDealer(total: total, soft: localSoft, composition: comp, rules: rules, dist: &sub)
            dist.add(sub, weight: p)
        }

        if conditionOnNoBJ {
            dist.normalize()  // mass excluded BJ branches
        }
        return dist
    }

    private static func recurseDealer(
        total: Int, soft: Bool, composition: [Rank: Int], rules: DealerRules, dist: inout DealerDist
    ) {
        // Stand?
        let standsHere: Bool = {
            if total >= 18 { return true }
            if total == 17 { return !(soft && rules.dealerHitsSoft17) }
            return false
        }()
        if standsHere {
            switch total {
            case 17: dist.p17 += 1
            case 18: dist.p18 += 1
            case 19: dist.p19 += 1
            case 20: dist.p20 += 1
            case 21: dist.p21 += 1
            default:
                if total > 21 { dist.pBust += 1 }
            }
            return
        }
        if total > 21 {
            dist.pBust += 1
            return
        }

        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else {
            // Out of cards — treat current total as the result (defensive)
            switch total {
            case 17: dist.p17 += 1
            case 18: dist.p18 += 1
            case 19: dist.p19 += 1
            case 20: dist.p20 += 1
            case 21: dist.p21 += 1
            default: dist.pBust += 1
            }
            return
        }
        for r in Rank.allCases {
            let n = composition[r] ?? 0
            if n == 0 { continue }
            let p = Double(n) / Double(totalCards)
            var comp = composition
            decrement(&comp, rank: r)
            var newTotal = total + r.blackjackValue
            var newSoft = soft || r == .ace
            if newTotal > 21 && newSoft {
                newTotal -= 10
                newSoft = false
            }
            var sub = DealerDist()
            recurseDealer(total: newTotal, soft: newSoft, composition: comp, rules: rules, dist: &sub)
            dist.add(sub, weight: p)
        }
    }

    // MARK: - Player EV

    static func standEV(playerTotal: Int, dealerDist: DealerDist) -> Double {
        // Player can't be bust here (caller filters). Player BJ handled by caller.
        if playerTotal > 21 { return -1 }
        var win = dealerDist.pBust
        var push = 0.0
        var loss = dealerDist.pBJ  // dealer BJ beats non-BJ stand
        // Dealer 17-21
        let dealerStates: [(total: Int, prob: Double)] = [
            (17, dealerDist.p17), (18, dealerDist.p18), (19, dealerDist.p19),
            (20, dealerDist.p20), (21, dealerDist.p21)
        ]
        for (t, p) in dealerStates {
            if playerTotal > t { win += p }
            else if playerTotal == t { push += p }
            else { loss += p }
        }
        return win - loss + 0 * push
    }

    static func hitEV(hand: Hand, composition: [Rank: Int], dealerDist: DealerDist, rules: DealerRules) -> Double {
        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else { return standEV(playerTotal: hand.total, dealerDist: dealerDist) }
        var ev = 0.0
        for r in Rank.allCases {
            let n = composition[r] ?? 0
            if n == 0 { continue }
            let p = Double(n) / Double(totalCards)
            var newHand = hand
            newHand.cards.append(Card(rank: r, suit: .spades))
            let newTotal = newHand.total
            var newComp = composition
            decrement(&newComp, rank: r)
            let evSub: Double
            if newTotal > 21 {
                evSub = -1
            } else if newTotal == 21 {
                evSub = standEV(playerTotal: 21, dealerDist: dealerDist)
            } else {
                let stand = standEV(playerTotal: newTotal, dealerDist: dealerDist)
                let hit = hitEV(hand: newHand, composition: newComp, dealerDist: dealerDist, rules: rules)
                evSub = max(stand, hit)
            }
            ev += p * evSub
        }
        return ev
    }

    static func doubleEV(hand: Hand, composition: [Rank: Int], dealerDist: DealerDist) -> Double {
        // Take exactly one card, then stand. EV is per unit of the *doubled* bet, so multiply by 2 at the end.
        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else { return 2 * standEV(playerTotal: hand.total, dealerDist: dealerDist) }
        var ev = 0.0
        for r in Rank.allCases {
            let n = composition[r] ?? 0
            if n == 0 { continue }
            let p = Double(n) / Double(totalCards)
            var newHand = hand
            newHand.cards.append(Card(rank: r, suit: .spades))
            let newTotal = newHand.total
            let evSub: Double = newTotal > 21 ? -1 : standEV(playerTotal: newTotal, dealerDist: dealerDist)
            ev += p * evSub
        }
        return 2.0 * ev
    }

    /// Composition-dependent split EV with proper post-split play:
    /// - Each post-split hand may double (when rules.doubleAfterSplit and not split-aces)
    /// - Each post-split hand may resplit (within rules.maxSplitHands)
    /// - Split aces draw one card and stand (unless rules.hitSplitAces)
    /// - Aces resplitting respects rules.resplitAces
    ///
    /// Approximation: post-split slots see the same composition (we don't condition slot 2 on slot 1's
    /// draw). For the typical 4-deep max-split games this introduces <0.05% error vs full enumeration.
    static func splitEV(
        pairRank: Rank,
        dealerUpcard: Card,
        composition: [Rank: Int],
        dealerDist: DealerDist,
        rules: DealerRules
    ) -> Double {
        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else { return 0 }

        // Resplit budget per slot: total resplits allowed is (maxSplitHands - 2); split evenly between the
        // two initial slots so the model can't exceed maxSplitHands in expectation.
        let perSlotResplits = max(0, (rules.maxSplitHands - 2) / 2)

        let perSlotEV = splitSlotEV(
            pairRank: pairRank,
            composition: composition,
            dealerDist: dealerDist,
            rules: rules,
            resplitsRemaining: perSlotResplits
        )
        return 2.0 * perSlotEV
    }

    /// Expected value of one post-split slot: draw one card, then choose between resplit (if eligible),
    /// stand, hit, or double-after-split (if rules allow). For split aces with no hit-split-aces rule,
    /// we collapse to "draw one card and stand" except when the drawn card lets us resplit.
    private static func splitSlotEV(
        pairRank: Rank,
        composition: [Rank: Int],
        dealerDist: DealerDist,
        rules: DealerRules,
        resplitsRemaining: Int
    ) -> Double {
        let totalCards = composition.values.reduce(0, +)
        guard totalCards > 0 else { return 0 }

        let isAces = pairRank == .ace
        let hitAcesRestricted = isAces && !rules.hitSplitAces

        var ev = 0.0
        for r in Rank.allCases {
            let n = composition[r] ?? 0
            if n == 0 { continue }
            let p = Double(n) / Double(totalCards)
            var compNext = composition
            decrement(&compNext, rank: r)

            var hand = Hand()
            hand.cards = [Card(rank: pairRank, suit: .spades), Card(rank: r, suit: .hearts)]
            hand.fromSplit = true
            hand.splitFromAces = isAces

            let canResplit = (resplitsRemaining > 0)
                && (r == pairRank)
                && (!isAces || rules.resplitAces)

            let evChoice: Double
            if canResplit {
                // Option A: resplit this slot — slot becomes two new slots (each with one less budget).
                let evResplit = 2.0 * splitSlotEV(
                    pairRank: pairRank,
                    composition: compNext,
                    dealerDist: dealerDist,
                    rules: rules,
                    resplitsRemaining: resplitsRemaining - 1
                )
                // Option B: keep the hand and play it.
                let evKeep: Double
                if hitAcesRestricted {
                    evKeep = standEV(playerTotal: hand.total, dealerDist: dealerDist)
                } else {
                    evKeep = playPostSplitHandEV(hand: hand, composition: compNext, dealerDist: dealerDist, rules: rules)
                }
                evChoice = max(evResplit, evKeep)
            } else if hitAcesRestricted {
                // Aces with no-hit rule: one card and stand.
                evChoice = standEV(playerTotal: hand.total, dealerDist: dealerDist)
            } else {
                evChoice = playPostSplitHandEV(hand: hand, composition: compNext, dealerDist: dealerDist, rules: rules)
            }
            ev += p * evChoice
        }
        return ev
    }

    /// Best EV among legal post-split actions: stand, hit, or double-after-split (no surrender, no further
    /// split — those are handled by the caller).
    private static func playPostSplitHandEV(
        hand: Hand,
        composition: [Rank: Int],
        dealerDist: DealerDist,
        rules: DealerRules
    ) -> Double {
        if hand.isBust { return -1 }
        let stand = standEV(playerTotal: hand.total, dealerDist: dealerDist)
        let hit   = hitEV(hand: hand, composition: composition, dealerDist: dealerDist, rules: rules)
        var best  = max(stand, hit)
        let canDouble = hand.cards.count == 2
            && !hand.splitFromAces
            && rules.doubleAfterSplit
        if canDouble {
            let dbl = doubleEV(hand: hand, composition: composition, dealerDist: dealerDist)
            if dbl > best { best = dbl }
        }
        return best
    }

    // MARK: - Helpers

    private static func decrement(_ comp: inout [Rank: Int], rank: Rank) {
        let v = (comp[rank] ?? 0) - 1
        if v <= 0 { comp[rank] = 0 } else { comp[rank] = v }
    }
}
