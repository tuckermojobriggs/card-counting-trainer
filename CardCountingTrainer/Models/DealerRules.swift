import Foundation

enum SurrenderRule: String, Codable, CaseIterable, Identifiable {
    case none, late, early
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none:  return "Not allowed"
        case .late:  return "Late surrender"
        case .early: return "Early surrender"
        }
    }
}

enum BlackjackPayout: String, Codable, CaseIterable, Identifiable {
    case threeToTwo = "3:2"
    case sixToFive  = "6:5"
    case oneToOne   = "1:1"
    var id: String { rawValue }
    var ratio: Double {
        switch self {
        case .threeToTwo: return 1.5
        case .sixToFive:  return 1.2
        case .oneToOne:   return 1.0
        }
    }
}

/// A "dealer profile" — the table rules for a hypothetical casino/game.
/// Defaults reflect a typical Vegas Strip 6-deck S17 DAS LS game — the same baseline the Strategy
/// section's chart targets, so chart actions and EV-best stay aligned at neutral counts.
struct DealerRules: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Default"

    var deckCount: Int = 6                      // 1, 2, 4, 6, 8
    var penetration: Double = 0.75              // fraction of shoe dealt before reshuffle
    var dealerHitsSoft17: Bool = false          // S17 default
    var doubleAfterSplit: Bool = true           // DAS allowed
    var doubleOnAnyTwo: Bool = true             // some games restrict to 9-11
    var resplitAllowed: Bool = true
    var maxSplitHands: Int = 4
    var resplitAces: Bool = false
    var hitSplitAces: Bool = false              // most games give one card only
    var surrender: SurrenderRule = .late
    var blackjackPayout: BlackjackPayout = .threeToTwo
    var dealerPeeksOnTenAce: Bool = true        // US-style hole-card peek

    static let `default` = DealerRules()
}

extension DealerRules {
    /// Approximate house edge at zero true count for these rules, assuming perfect basic-strategy play.
    /// Captures the dominant rule effects (deck count, soft-17, double-after-split, surrender, BJ
    /// payout) to within roughly ±0.1% for typical combinations. Used as the per-hand baseline for the
    /// session expected-value tracker — not as a substitute for the composition-dependent EV calculator.
    var approximateHouseEdgeAtZeroCount: Double {
        var edge = 0.005
        if deckCount == 1 { edge -= 0.004 }
        if deckCount == 2 { edge -= 0.002 }
        if deckCount >= 6 { edge += 0.001 }
        if dealerHitsSoft17 { edge += 0.002 }
        if !doubleAfterSplit { edge += 0.0014 }
        if surrender == .none { edge += 0.0008 }
        if blackjackPayout == .sixToFive { edge += 0.0139 }
        if blackjackPayout == .oneToOne  { edge += 0.0232 }
        return edge
    }

    /// Player's expected edge per hand at the given true count, using the standard ~0.5%-per-TC-unit
    /// rule of thumb for Hi-Lo-class systems.
    func playerEdge(atTrueCount trueCount: Double) -> Double {
        -approximateHouseEdgeAtZeroCount + trueCount * 0.005
    }
}
