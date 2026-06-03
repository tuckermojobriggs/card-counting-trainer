import Foundation

enum GamePhase: String, Hashable, Codable {
    case idle               // no round active, waiting for bet
    case insuranceOffered   // dealer shows Ace, player can take insurance
    case playerTurn         // player making decisions on current hand
    case dealerTurn         // animated/instant dealer play
    case complete           // round finished, results ready
}

enum HandOutcome: String, Hashable, Codable {
    case blackjack          // 3:2 (or whatever payout) on a natural
    case win                // beats dealer
    case push               // ties dealer
    case loss               // dealer beats hand
    case bust               // player bust
    case surrender          // -0.5 of bet
}

/// Per-hand result after settlement.
struct HandResult: Hashable, Identifiable {
    let id: UUID = UUID()
    let outcome: HandOutcome
    let bet: Double         // the bet on this specific hand (after doubles)
    let payout: Double      // net P/L on this hand (e.g. +1x bet for win, -1x for loss, +1.5x for BJ at 3:2)
}

/// The complete state of a single round of blackjack.
struct Round {
    var hands: [Hand] = []
    var dealerHand: Hand = Hand()
    var currentHandIndex: Int = 0
    var initialBet: Double = 0
    var insuranceBet: Double = 0
    var insuranceTaken: Bool = false
    var phase: GamePhase = .idle
    var results: [HandResult] = []
    var insuranceResult: HandResult? = nil
    /// True if the dealer revealed BJ at peek and ended the round.
    var endedOnDealerBlackjack: Bool = false

    var currentHand: Hand? {
        guard hands.indices.contains(currentHandIndex) else { return nil }
        return hands[currentHandIndex]
    }

    /// Total wagered across all player hands plus insurance, for stats.
    var totalAmountWagered: Double {
        hands.reduce(0) { $0 + $1.bet } + insuranceBet
    }

    /// Net dollar P/L across all results in this round.
    var totalPayout: Double {
        let main = results.reduce(0) { $0 + $1.payout }
        return main + (insuranceResult?.payout ?? 0)
    }
}

/// Drives the game state machine. Mutating struct so SwiftUI can observe via @Observable wrapper.
struct BlackjackEngine {
    var rules: DealerRules
    var shoe: Shoe
    var round: Round = Round()

    init(rules: DealerRules) {
        self.rules = rules
        self.shoe = Shoe(deckCount: rules.deckCount, penetration: rules.penetration)
    }

    // MARK: - Round lifecycle

    /// Start a new round with the given bet. Reshuffles if penetration was hit.
    mutating func startRound(bet: Double) {
        if shoe.needsShuffle || shoe.remaining < 15 {
            shoe.rebuildAndShuffle()
        }
        round = Round()
        round.initialBet = bet

        var player = Hand()
        player.bet = bet
        var dealer = Hand()
        // Standard order: player, dealer, player, dealer (dealer's 2nd is the hole card)
        player.cards.append(shoe.draw())
        dealer.cards.append(shoe.draw())
        player.cards.append(shoe.draw())
        dealer.cards.append(shoe.draw())
        round.hands = [player]
        round.dealerHand = dealer

        // Decide next phase: insurance, immediate BJ resolution, or player turn.
        let upcard = dealer.cards[0]
        if rules.dealerPeeksOnTenAce && upcard.rank == .ace {
            round.phase = .insuranceOffered
            return
        }
        if rules.dealerPeeksOnTenAce && upcard.rank.isTen && dealer.isBlackjack {
            // Dealer has BJ — round ends immediately
            settleOnDealerBlackjack()
            return
        }
        // Player BJ with non-Ace, non-Ten dealer upcard: settle immediately
        if player.isBlackjack {
            round.phase = .dealerTurn
            playDealerAndSettle()
            return
        }
        round.phase = .playerTurn
    }

    /// After insurance choice, peek the hole card if upcard is A. (For 10-up peek we already handled above.)
    mutating func resolveInsuranceAndContinue() {
        guard round.phase == .insuranceOffered else { return }
        let dealerHasBJ = round.dealerHand.isBlackjack

        if round.insuranceTaken {
            let ins = round.insuranceBet
            round.insuranceResult = HandResult(
                outcome: dealerHasBJ ? .win : .loss,
                bet: ins,
                payout: dealerHasBJ ? 2 * ins : -ins
            )
        }

        if dealerHasBJ {
            settleOnDealerBlackjack()
            return
        }
        // Player BJ without dealer BJ: pays immediately
        if round.hands[0].isBlackjack {
            round.phase = .dealerTurn
            playDealerAndSettle()
            return
        }
        round.phase = .playerTurn
    }

    /// Player declines insurance — proceed.
    mutating func declineInsurance() {
        round.insuranceTaken = false
        round.insuranceBet = 0
        resolveInsuranceAndContinue()
    }

    /// Player takes insurance for half the original bet.
    mutating func takeInsurance() {
        round.insuranceTaken = true
        round.insuranceBet = round.initialBet / 2.0
        resolveInsuranceAndContinue()
    }

    // MARK: - Player actions

    /// What actions are legal on the current hand right now.
    func availableActions() -> Set<PlayerAction> {
        guard round.phase == .playerTurn,
              let hand = round.currentHand,
              !hand.isResolved
        else { return [] }

        var actions: Set<PlayerAction> = [.hit, .stand]

        let canDouble = hand.cards.count == 2
            && (rules.doubleOnAnyTwo || (9...11).contains(hand.total))
            && !(hand.fromSplit && hand.splitFromAces)
            && (!hand.fromSplit || rules.doubleAfterSplit)
        if canDouble { actions.insert(.double) }

        if let _ = hand.pairRank, hand.cards.count == 2, round.hands.count < rules.maxSplitHands {
            // Cannot resplit aces unless rules allow it
            if hand.cards[0].rank == .ace && hand.fromSplit && !rules.resplitAces {
                // can't split again
            } else {
                actions.insert(.split)
            }
        }

        // Surrender only on first decision of first hand
        if hand.cards.count == 2 && !hand.fromSplit && round.hands.count == 1 && rules.surrender != .none {
            actions.insert(.surrender)
        }

        // Split aces: usually only one card and no further actions
        if hand.fromSplit && hand.splitFromAces && !rules.hitSplitAces {
            return []
        }

        return actions
    }

    mutating func hit() {
        guard availableActions().contains(.hit) else { return }
        round.hands[round.currentHandIndex].cards.append(shoe.draw())
        if round.hands[round.currentHandIndex].isResolved {
            advanceToNextHandOrDealer()
        }
    }

    mutating func stand() {
        guard availableActions().contains(.stand) else { return }
        round.hands[round.currentHandIndex].isStood = true
        advanceToNextHandOrDealer()
    }

    mutating func double() {
        guard availableActions().contains(.double) else { return }
        round.hands[round.currentHandIndex].bet *= 2
        round.hands[round.currentHandIndex].isDoubled = true
        round.hands[round.currentHandIndex].cards.append(shoe.draw())
        advanceToNextHandOrDealer()
    }

    mutating func surrender() {
        guard availableActions().contains(.surrender) else { return }
        round.hands[round.currentHandIndex].isSurrendered = true
        advanceToNextHandOrDealer()
    }

    mutating func split() {
        guard availableActions().contains(.split) else { return }
        let current = round.hands[round.currentHandIndex]
        let firstCard = current.cards[0]
        let secondCard = current.cards[1]
        let isAces = firstCard.rank == .ace

        // Build first split hand (replace existing)
        var first = Hand()
        first.cards = [firstCard, shoe.draw()]
        first.bet = round.initialBet
        first.fromSplit = true
        first.splitFromAces = isAces

        // Second split hand
        var second = Hand()
        second.cards = [secondCard, shoe.draw()]
        second.bet = round.initialBet
        second.fromSplit = true
        second.splitFromAces = isAces

        round.hands[round.currentHandIndex] = first
        round.hands.insert(second, at: round.currentHandIndex + 1)

        // Auto-advance past hands that get only one card (split aces)
        if isAces && !rules.hitSplitAces {
            // Both new hands are immediately resolved (can't hit)
            round.hands[round.currentHandIndex].isStood = true
            round.hands[round.currentHandIndex + 1].isStood = true
            advanceToNextHandOrDealer()
        } else if round.hands[round.currentHandIndex].isResolved {
            // Post-split hand at the current index is already resolved (e.g. splitting tens and the
            // first draw is an ace, giving soft 21). Auto-advance so we don't ask for an action on a
            // hand that has none.
            advanceToNextHandOrDealer()
        }
    }

    private mutating func advanceToNextHandOrDealer() {
        var idx = round.currentHandIndex + 1
        while idx < round.hands.count && round.hands[idx].isResolved {
            idx += 1
        }
        if idx >= round.hands.count {
            // All hands done → dealer turn (unless all hands surrendered/busted: still play dealer for splits with surviving hands)
            round.currentHandIndex = round.hands.count
            round.phase = .dealerTurn
            playDealerAndSettle()
        } else {
            round.currentHandIndex = idx
            round.phase = .playerTurn
        }
    }

    // MARK: - Dealer turn + settlement

    /// Play out the dealer's hand and compute results for each player hand.
    mutating func playDealerAndSettle() {
        // If every player hand busted/surrendered, dealer doesn't need to draw.
        let allDeadHands = round.hands.allSatisfy { $0.isBust || $0.isSurrendered }
        if !allDeadHands {
            while shouldDealerHit(round.dealerHand) {
                round.dealerHand.cards.append(shoe.draw())
            }
        }

        var results: [HandResult] = []
        let dealerTotal = round.dealerHand.total
        let dealerBJ = round.dealerHand.isBlackjack
        let dealerBust = round.dealerHand.isBust

        for hand in round.hands {
            results.append(settle(playerHand: hand, dealerTotal: dealerTotal, dealerBust: dealerBust, dealerBJ: dealerBJ))
        }
        round.results = results
        round.phase = .complete
    }

    private mutating func settleOnDealerBlackjack() {
        round.endedOnDealerBlackjack = true
        var results: [HandResult] = []
        for hand in round.hands {
            if hand.isBlackjack {
                results.append(HandResult(outcome: .push, bet: hand.bet, payout: 0))
            } else {
                results.append(HandResult(outcome: .loss, bet: hand.bet, payout: -hand.bet))
            }
        }
        round.results = results
        round.phase = .complete
    }

    private func settle(playerHand: Hand, dealerTotal: Int, dealerBust: Bool, dealerBJ: Bool) -> HandResult {
        let bet = playerHand.bet
        if playerHand.isSurrendered {
            return HandResult(outcome: .surrender, bet: bet, payout: -bet / 2.0)
        }
        if playerHand.isBust {
            return HandResult(outcome: .bust, bet: bet, payout: -bet)
        }
        if playerHand.isBlackjack {
            // dealer BJ already handled in settleOnDealerBlackjack
            return HandResult(outcome: .blackjack, bet: bet, payout: bet * rules.blackjackPayout.ratio)
        }
        if dealerBJ {
            return HandResult(outcome: .loss, bet: bet, payout: -bet)
        }
        if dealerBust { return HandResult(outcome: .win, bet: bet, payout: bet) }
        let total = playerHand.total
        if total > dealerTotal { return HandResult(outcome: .win, bet: bet, payout: bet) }
        if total < dealerTotal { return HandResult(outcome: .loss, bet: bet, payout: -bet) }
        return HandResult(outcome: .push, bet: bet, payout: 0)
    }

    private func shouldDealerHit(_ dealer: Hand) -> Bool {
        let t = dealer.total
        if t < 17 { return true }
        if t == 17 && dealer.isSoft && rules.dealerHitsSoft17 { return true }
        return false
    }
}
