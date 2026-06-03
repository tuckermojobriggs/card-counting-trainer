import Foundation

enum Suit: String, CaseIterable, Codable, Hashable {
    case spades = "♠"
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"

    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum Rank: Int, CaseIterable, Codable, Hashable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    var label: String {
        switch self {
        case .ace:   return "A"
        case .king:  return "K"
        case .queen: return "Q"
        case .jack:  return "J"
        case .ten:   return "10"
        default:     return String(rawValue)
        }
    }

    /// Blackjack value. Aces returned as 11 here; soft/hard handling lives in `Hand`.
    var blackjackValue: Int {
        switch self {
        case .ace: return 11
        case .king, .queen, .jack, .ten: return 10
        default: return rawValue
        }
    }

    /// True for 10/J/Q/K — used by dealer peek logic and counting systems.
    var isTen: Bool { blackjackValue == 10 }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Card: Hashable, Codable, Identifiable {
    let rank: Rank
    let suit: Suit
    let id: UUID

    init(rank: Rank, suit: Suit, id: UUID = UUID()) {
        self.rank = rank
        self.suit = suit
        self.id = id
    }

    var label: String { "\(rank.label)\(suit.rawValue)" }
}
