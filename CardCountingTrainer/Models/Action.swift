import Foundation

enum PlayerAction: String, CaseIterable, Codable, Hashable, Identifiable {
    case hit
    case stand
    case double
    case split
    case surrender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hit:       return "Hit"
        case .stand:     return "Stand"
        case .double:    return "Double"
        case .split:     return "Split"
        case .surrender: return "Surrender"
        }
    }

    var shortLabel: String {
        switch self {
        case .hit:       return "H"
        case .stand:     return "S"
        case .double:    return "D"
        case .split:     return "P"   // "P" for "pair"/split, conventional in strategy charts
        case .surrender: return "R"
        }
    }
}
