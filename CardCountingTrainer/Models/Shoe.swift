import Foundation

/// A multi-deck blackjack shoe with reshuffle controlled by penetration.
/// Tracks composition (counts per rank remaining) for fast EV / strategy lookups.
struct Shoe {
    private(set) var cards: [Card] = []
    private(set) var totalCards: Int = 0
    private(set) var rankCounts: [Rank: Int] = [:]
    private(set) var dealtCount: Int = 0

    let deckCount: Int
    let penetration: Double

    private var rng: SystemRandomNumberGenerator

    init(deckCount: Int, penetration: Double) {
        self.deckCount = max(1, deckCount)
        self.penetration = min(max(penetration, 0.1), 0.95)
        self.rng = SystemRandomNumberGenerator()
        rebuildAndShuffle()
    }

    /// Cards remaining in the shoe.
    var remaining: Int { cards.count }

    /// Decimal "decks remaining" — used for true count.
    var decksRemaining: Double {
        Double(remaining) / 52.0
    }

    /// True when penetration has been hit and a reshuffle is due.
    var needsShuffle: Bool {
        let dealtFraction = Double(dealtCount) / Double(totalCards)
        return dealtFraction >= penetration
    }

    /// Reset the shoe and shuffle.
    mutating func rebuildAndShuffle() {
        var fresh: [Card] = []
        var counts: [Rank: Int] = [:]
        fresh.reserveCapacity(deckCount * 52)
        for _ in 0..<deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    fresh.append(Card(rank: rank, suit: suit))
                    counts[rank, default: 0] += 1
                }
            }
        }
        fresh.shuffle(using: &rng)
        self.cards = fresh
        self.totalCards = fresh.count
        self.rankCounts = counts
        self.dealtCount = 0
    }

    /// Draw one card from the top of the shoe.
    mutating func draw() -> Card {
        precondition(!cards.isEmpty, "Shoe empty — should have reshuffled")
        let c = cards.removeLast()
        rankCounts[c.rank, default: 0] -= 1
        dealtCount += 1
        return c
    }

    /// Number of cards of a given rank still in the shoe.
    func count(of rank: Rank) -> Int {
        rankCounts[rank, default: 0]
    }

    /// Number of 10-valued cards (10, J, Q, K) still in the shoe.
    var tenCount: Int {
        count(of: .ten) + count(of: .jack) + count(of: .queen) + count(of: .king)
    }
}

