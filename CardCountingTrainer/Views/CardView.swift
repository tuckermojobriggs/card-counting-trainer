import SwiftUI

struct CardView: View {
    let card: Card
    var faceUp: Bool = true
    var size: CardSize = .regular

    var body: some View {
        ZStack {
            frontFace
                .opacity(faceUp ? 1 : 0)
            backFace
                // Pre-rotate the back 180° around Y so that once the parent rotates the whole card
                // to 180° (face-down), the back ends up facing the camera again rather than mirrored.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(faceUp ? 0 : 1)
        }
        .frame(width: size.width, height: size.height)
        .rotation3DEffect(
            .degrees(faceUp ? 0 : 180),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .animation(.easeInOut(duration: 0.45), value: faceUp)
        .accessibilityLabel(faceUp ? "\(card.rank.label) of \(card.suit.rawValue)" : "Face-down card")
    }

    private var frontFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .stroke(.black.opacity(0.25), lineWidth: 0.5)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(card.rank.label)
                        .font(.system(size: size.rankFont, weight: .bold, design: .rounded))
                        .foregroundStyle(card.suit.isRed ? .red : .black)
                    Spacer()
                }
                HStack {
                    Text(card.suit.rawValue)
                        .font(.system(size: size.suitFont))
                        .foregroundStyle(card.suit.isRed ? .red : .black)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Text(card.suit.rawValue)
                        .font(.system(size: size.centerSuitFont))
                        .foregroundStyle(card.suit.isRed ? .red : .black)
                        .opacity(0.7)
                }
            }
            .padding(size.padding)
        }
    }

    private var backFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(Color(red: 0.15, green: 0.25, blue: 0.55))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .stroke(.black.opacity(0.25), lineWidth: 0.5)

            CardBackPattern()
                .clipShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
                .padding(2)
        }
    }
}

enum CardSize {
    case small, regular, large

    var width: CGFloat {
        switch self {
        case .small:   return 48
        case .regular: return 64
        case .large:   return 84
        }
    }
    var height: CGFloat { width * 1.4 }
    var corner: CGFloat { width * 0.12 }
    var padding: CGFloat { width * 0.1 }
    var rankFont: CGFloat { width * 0.32 }
    var suitFont: CGFloat { width * 0.22 }
    var centerSuitFont: CGFloat { width * 0.45 }
}

private struct CardBackPattern: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let step: CGFloat = 6
                for x in stride(from: -size.height, to: size.width + size.height, by: step) {
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    }
                    ctx.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
                }
            }
            .background(Color(red: 0.1, green: 0.2, blue: 0.5))
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
