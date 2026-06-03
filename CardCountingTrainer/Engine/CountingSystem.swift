import Foundation

enum CountingSystemKind: String, CaseIterable, Codable, Identifiable {
    case hiLo
    case ko
    case hiOptI
    case hiOptII
    case omegaII
    case wongHalves
    case zen

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .hiLo:       return "High-Low"
        case .ko:         return "Knock-Out"
        case .hiOptI:     return "Hi-Opt I"
        case .hiOptII:    return "Hi-Opt II"
        case .omegaII:    return "Omega II"
        case .wongHalves: return "Wong Halves"
        case .zen:        return "Zen Count"
        }
    }

    /// Whether this system is "balanced" (i.e. running count of complete shoe sums to 0).
    /// Unbalanced systems (e.g. KO) don't divide by decks remaining for true count.
    var isBalanced: Bool { self != .ko }

    /// Short, user-facing description of the system — surfaced under the picker in Settings.
    var summary: String {
        switch self {
        case .hiLo:
            return "The standard system. Cards 2 through 6 add 1, cards 7 through 9 are neutral, ten-valued cards and aces subtract 1. Balanced — divides cleanly into a true count."
        case .ko:
            return "Unbalanced single-level system. Same tags as High-Low plus 7s also add 1. The running count is used directly, no true count conversion needed."
        case .hiOptI:
            return "Balanced single-level system. 3 through 6 add 1, ten-valued cards subtract 1. Aces are tracked separately for insurance and bet sizing. Slightly more accurate than High-Low at the cost of more bookkeeping."
        case .hiOptII:
            return "Balanced two-level system. 2/3/6/7 add 1, 4/5 add 2, 8/9 are neutral, ten-valued cards subtract 2. Aces tracked separately. Higher accuracy, considerably harder to track at table speed."
        case .omegaII:
            return "Balanced two-level system. 2/3/7 add 1, 4/5/6 add 2, 8 is neutral, 9 subtracts 1, ten-valued cards subtract 2. Aces tracked separately. Strong accuracy for serious counters."
        case .wongHalves:
            return "Balanced three-level fractional system. Uses half-unit tags. Among the most accurate published counts, but tracking fractions at speed is demanding — most players double all tags to track in whole units."
        case .zen:
            return "Balanced two-level system. 2/3/7 add 1, 4/5/6 add 2, 8/9 are neutral, ten-valued cards subtract 2, aces subtract 1. Aces are baked into the count, which simplifies tracking versus Hi-Opt II or Omega II."
        }
    }
}

protocol CountingSystem {
    var kind: CountingSystemKind { get }
    /// Tag value contributed by a single card.
    func tag(for rank: Rank) -> Double
    /// Initial running count given total decks (for unbalanced systems like KO).
    func initialRunningCount(decks: Int) -> Double
    /// Insurance threshold (true count for balanced, running count for unbalanced).
    var insuranceThreshold: Double { get }
}

/// Hi-Lo: 2-6 = +1, 7-9 = 0, T-A = -1.
struct HiLo: CountingSystem {
    let kind: CountingSystemKind = .hiLo
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .three, .four, .five, .six: return 1
        case .seven, .eight, .nine:            return 0
        case .ten, .jack, .queen, .king, .ace: return -1
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

/// KO (Knock-Out) — unbalanced; like Hi-Lo but 7s also count as +1.
/// Initial running count = 4 - 4*decks (so it crosses 0 at the "key count").
struct KO: CountingSystem {
    let kind: CountingSystemKind = .ko
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .three, .four, .five, .six, .seven: return 1
        case .eight, .nine:                            return 0
        case .ten, .jack, .queen, .king, .ace:         return -1
        }
    }
    func initialRunningCount(decks: Int) -> Double { Double(4 - 4 * decks) }
    var insuranceThreshold: Double { 3 }
}

struct HiOptI: CountingSystem {
    let kind: CountingSystemKind = .hiOptI
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .three, .four, .five, .six:        return 1
        case .ten, .jack, .queen, .king:        return -1
        default:                                return 0
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

struct HiOptII: CountingSystem {
    let kind: CountingSystemKind = .hiOptII
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .three, .six, .seven:        return 1
        case .four, .five:                      return 2
        case .ten, .jack, .queen, .king:        return -2
        default:                                return 0
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

struct OmegaII: CountingSystem {
    let kind: CountingSystemKind = .omegaII
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .three, .seven:              return 1
        case .four, .five, .six:                return 2
        case .nine:                             return -1
        case .ten, .jack, .queen, .king:        return -2
        default:                                return 0
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

struct WongHalves: CountingSystem {
    let kind: CountingSystemKind = .wongHalves
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .seven:                      return 0.5
        case .three, .four, .six:               return 1
        case .five:                             return 1.5
        case .nine:                             return -0.5
        case .ten, .jack, .queen, .king, .ace:  return -1
        default:                                return 0
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

struct ZenCount: CountingSystem {
    let kind: CountingSystemKind = .zen
    func tag(for rank: Rank) -> Double {
        switch rank {
        case .two, .three, .seven:              return 1
        case .four, .five, .six:                return 2
        case .ten, .jack, .queen, .king:        return -2
        case .ace:                              return -1
        default:                                return 0
        }
    }
    func initialRunningCount(decks: Int) -> Double { 0 }
    var insuranceThreshold: Double { 3 }
}

/// Factory.
enum CountingSystems {
    static func make(_ kind: CountingSystemKind) -> CountingSystem {
        switch kind {
        case .hiLo:       return HiLo()
        case .ko:         return KO()
        case .hiOptI:     return HiOptI()
        case .hiOptII:    return HiOptII()
        case .omegaII:    return OmegaII()
        case .wongHalves: return WongHalves()
        case .zen:        return ZenCount()
        }
    }
}

/// A live counter that observes cards as they're dealt.
struct CountTracker {
    var system: CountingSystem
    var decks: Int
    var runningCount: Double
    /// What the user *thinks* the running count is (for accuracy training).
    var userRunningCount: Double = 0

    init(system: CountingSystem, decks: Int) {
        self.system = system
        self.decks = decks
        self.runningCount = system.initialRunningCount(decks: decks)
        self.userRunningCount = system.initialRunningCount(decks: decks)
    }

    mutating func observe(_ card: Card) {
        runningCount += system.tag(for: card.rank)
    }

    mutating func reset() {
        runningCount = system.initialRunningCount(decks: decks)
        userRunningCount = system.initialRunningCount(decks: decks)
    }

    /// True count given decks remaining in shoe. Falls back to running count for unbalanced systems.
    func trueCount(decksRemaining: Double) -> Double {
        guard system.kind.isBalanced else { return runningCount }
        let denom = max(decksRemaining, 0.5)   // avoid div by zero / wild swings
        return runningCount / denom
    }
}
