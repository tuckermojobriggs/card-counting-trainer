import Foundation

/// How much hand-holding the trainer provides while you play. Each step removes a piece of automatic
/// information so the player has to do the work themselves — adding their own card totals on Casual,
/// tracking the count on Medium, doing it all without any visible counters on Hard.
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case casual
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .casual: return "Casual"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var summary: String {
        switch self {
        case .easy:
            return "Hand totals, running count, and true count all visible."
        case .casual:
            return "Running count and true count visible. You add up your own card totals."
        case .medium:
            return "Hand totals, running count, and true count all hidden. Track the count yourself with minus and plus buttons. The trainer blocks every action until your tracked count matches the actual count."
        case .hard:
            return "Nothing count-related is shown. There are no buttons to adjust a tracked count — you keep it in your head. Every action carries a 10% chance the trainer pops a count quiz: get it right to proceed, wrong answers shake the prompt and say Higher or Lower."
        }
    }

    /// Player hand totals (the small number badge next to each hand) are hidden on everything above Easy.
    var hidesPlayerHandTotals: Bool {
        self != .easy
    }

    /// The player maintains their own running-count state, adjusted with the minus and plus buttons.
    var playerMaintainsCount: Bool {
        self == .medium || self == .hard
    }

    /// The trainer's actual running count and true count are shown directly in the count row.
    var showsActualCounts: Bool {
        self == .easy || self == .casual
    }

    /// The player's own tracked count + derived true count are gated behind the peek button.
    var requiresPeekToRevealCount: Bool {
        self == .hard
    }

    /// The trainer refuses to accept any action until the player's tracked count matches the actual
    /// count. The actual count is revealed inline so the player can correct.
    var gradesPlayerCount: Bool {
        self == .medium
    }
}
