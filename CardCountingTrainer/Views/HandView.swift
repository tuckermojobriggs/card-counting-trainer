import SwiftUI

struct HandView: View {
    let cards: [Card]
    var hideSecondCard: Bool = false
    var label: String?
    var total: Int?
    var isSoft: Bool = false
    var isActive: Bool = false
    var resultBadge: String? = nil
    var size: CardSize = .regular
    /// When true, new cards slide in from above with a brief fade. Disabled by the "Fast dealing"
    /// setting so power users can rip through hands without waiting for the cosmetic delay.
    var animateInsertion: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let total {
                        let display = isSoft ? "Soft \(total)" : "\(total)"
                        Text(display)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isActive ? Color.accentColor : .primary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    if let resultBadge {
                        Text(resultBadge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            HStack(spacing: -size.width * 0.55) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                    let hidden = hideSecondCard && idx == 1
                    CardView(card: card, faceUp: !hidden, size: size)
                        .zIndex(Double(idx))
                        .transition(
                            animateInsertion
                            ? .asymmetric(
                                insertion: .offset(y: -size.height * 1.2)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.85, anchor: .top)),
                                removal: .opacity)
                            : .identity
                        )
                }
            }
            .frame(minHeight: size.height)
            .animation(
                animateInsertion ? .spring(response: 0.35, dampingFraction: 0.78) : nil,
                value: cards.map(\.id)
            )
        }
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Color.accentColor : .clear, lineWidth: 2)
                .padding(-6)
        )
    }
}
