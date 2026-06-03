import Foundation

struct Hand: Hashable, Codable {
    var cards: [Card] = []
    var bet: Double = 0
    var isDoubled: Bool = false
    var isSurrendered: Bool = false
    var isStood: Bool = false
    var fromSplit: Bool = false
    var splitFromAces: Bool = false

    /// Total counting aces as 11 where possible without busting; otherwise as 1.
    var total: Int {
        var sum = 0
        var aces = 0
        for c in cards {
            sum += c.rank.blackjackValue
            if c.rank == .ace { aces += 1 }
        }
        while sum > 21 && aces > 0 {
            sum -= 10
            aces -= 1
        }
        return sum
    }

    /// True if the hand contains an ace currently being counted as 11.
    var isSoft: Bool {
        var sum = 0
        var aces = 0
        for c in cards {
            sum += c.rank.blackjackValue
            if c.rank == .ace { aces += 1 }
        }
        while sum > 21 && aces > 0 {
            sum -= 10
            aces -= 1
        }
        return aces > 0
    }

    var isBust: Bool { total > 21 }

    /// Natural blackjack: exactly two cards totaling 21, not from a split.
    var isBlackjack: Bool {
        cards.count == 2 && total == 21 && !fromSplit
    }

    /// True if the hand is a pair (two cards of the same rank, including any 10-valued cards as a 10-pair).
    var isPair: Bool {
        guard cards.count == 2 else { return false }
        return cards[0].rank.blackjackValue == cards[1].rank.blackjackValue
    }

    /// The pair rank if `isPair`. Tens (T/J/Q/K) collapse to .ten for strategy lookup.
    var pairRank: Rank? {
        guard isPair else { return nil }
        let r = cards[0].rank
        return r.isTen ? .ten : r
    }

    /// True if the hand has been settled — stand, bust, surrender, double-resolved, blackjack,
    /// split-aces with one card each, or any total of 21 or more (no further action can help).
    var isResolved: Bool {
        if isStood || isBust || isSurrendered { return true }
        if isDoubled { return true }
        if splitFromAces && cards.count == 2 { return true }
        if total >= 21 { return true }
        return isBlackjack && !fromSplit
    }
}
