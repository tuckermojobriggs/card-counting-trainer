import SwiftUI

struct ActionBarView: View {
    let legal: Set<PlayerAction>
    var onAction: (PlayerAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PlayerAction.allCases) { action in
                Button {
                    onAction(action)
                } label: {
                    VStack(spacing: 2) {
                        Text(action.displayName)
                            .font(.system(.callout, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(color(for: action))
                .disabled(!legal.contains(action))
                .opacity(legal.contains(action) ? 1.0 : 0.35)
            }
        }
    }

    private func color(for action: PlayerAction) -> Color {
        switch action {
        case .hit:       return .blue
        case .stand:     return .gray
        case .double:    return .orange
        case .split:     return .purple
        case .surrender: return .red
        }
    }
}

struct InsuranceBarView: View {
    var onTake: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Dealer shows Ace — Insurance?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button {
                    onDecline()
                } label: {
                    Text("No")
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)

                Button {
                    onTake()
                } label: {
                    Text("Take Insurance")
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
}
