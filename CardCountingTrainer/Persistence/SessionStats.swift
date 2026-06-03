import Foundation

/// Aggregated stats across rounds. Persisted via JSON in UserDefaults by SessionStore.
struct SessionStats: Codable, Hashable {
    var roundsPlayed: Int = 0
    var handsPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var pushes: Int = 0
    var blackjacks: Int = 0
    var busts: Int = 0
    var surrenders: Int = 0

    var totalWagered: Double = 0
    var totalNet: Double = 0

    /// What you would expect to win on average given the decisions you actually made (assuming the EV
    /// calculator is correct). Realized minus expected is variance; expected minus optimal-play is skill.
    var expectedNet: Double = 0

    /// Cumulative dollars given up to suboptimal decisions. Always ≥ 0. Lower is better.
    var skillCostDollars: Double = 0

    var decisionsMade: Int = 0
    var correctDecisions: Int = 0

    var insuranceDecisions: Int = 0
    var correctInsuranceDecisions: Int = 0

    /// Bankroll snapshots, capped at most-recent N for charts.
    var bankrollHistory: [BankrollPoint] = []
    /// Expected-bankroll snapshots in lockstep with bankrollHistory.
    var expectedHistory: [BankrollPoint] = []

    /// % of decisions that matched the optimal play (basic strategy + count deviations).
    var decisionAccuracy: Double {
        decisionsMade == 0 ? 0 : Double(correctDecisions) / Double(decisionsMade)
    }

    /// Net P/L per dollar wagered — your realized "house edge" against the casino (negative is bad for you).
    var realizedEV: Double {
        totalWagered == 0 ? 0 : totalNet / totalWagered
    }

    var winRate: Double {
        let resolved = wins + losses
        return resolved == 0 ? 0 : Double(wins) / Double(resolved)
    }

    /// Insurance accuracy across rounds where dealer showed an Ace.
    var insuranceAccuracy: Double {
        insuranceDecisions == 0 ? 0 : Double(correctInsuranceDecisions) / Double(insuranceDecisions)
    }

    mutating func recordDecision(isCorrect: Bool) {
        decisionsMade += 1
        if isCorrect { correctDecisions += 1 }
    }

    mutating func recordInsuranceDecision(took: Bool, wasCorrect: Bool) {
        insuranceDecisions += 1
        if wasCorrect { correctInsuranceDecisions += 1 }
    }

    mutating func recordRound(net: Double, wagered: Double, handResults: [HandResult], insuranceTaken: Bool) {
        roundsPlayed += 1
        totalNet += net
        totalWagered += wagered
        for r in handResults {
            handsPlayed += 1
            switch r.outcome {
            case .blackjack: blackjacks += 1; wins += 1
            case .win:       wins += 1
            case .loss:      losses += 1
            case .bust:      busts += 1; losses += 1
            case .push:      pushes += 1
            case .surrender: surrenders += 1
            }
        }
        appendBankrollPoint(net: net)
    }

    private mutating func appendBankrollPoint(net: Double) {
        let last = bankrollHistory.last?.bankroll ?? 0
        bankrollHistory.append(BankrollPoint(round: roundsPlayed, bankroll: last + net))
        let lastExpected = expectedHistory.last?.bankroll ?? 0
        expectedHistory.append(BankrollPoint(round: roundsPlayed, bankroll: expectedNet))
        _ = lastExpected
        // cap to last 500 rounds for memory; chart still renders
        if bankrollHistory.count > 500 {
            bankrollHistory.removeFirst(bankrollHistory.count - 500)
        }
        if expectedHistory.count > 500 {
            expectedHistory.removeFirst(expectedHistory.count - 500)
        }
    }

    mutating func reset() { self = SessionStats() }
}

struct BankrollPoint: Codable, Hashable, Identifiable {
    var id: Int { round }
    let round: Int
    let bankroll: Double
}
