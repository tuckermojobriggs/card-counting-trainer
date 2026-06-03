import SwiftUI

/// Top-of-screen count summary. The hands-on stepper for Medium lives in `GameView` as a horizontal
/// bar above the action buttons; this view is read-only display.
struct CountDisplayView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        let difficulty = session.difficulty
        let isBalanced = session.counter.system.kind.isBalanced
        let actualTC = session.counter.trueCount(decksRemaining: session.engine.shoe.decksRemaining)
        let actualRC = session.counter.runningCount
        let playerTC = session.playerTrueCount()

        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 12) {
                switch difficulty {
                case .easy, .casual:
                    countPill(label: "Running", value: formatted(actualRC))
                    if isBalanced {
                        countPill(label: "True", value: formatted(actualTC))
                    }
                case .medium:
                    if isBalanced {
                        countPill(label: "True", value: formatted(playerTC))
                    }
                case .hard:
                    // Hard difficulty hides every count helper. The trainer surfaces a random
                    // count-check overlay 10% of the time — that's the only place numbers appear.
                    EmptyView()
                }
                Spacer(minLength: 0)
                Text("\(session.engine.shoe.remaining) cards left")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            edgeRow(actualTC: actualTC, playerTC: playerTC)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Edge row

    @ViewBuilder
    private func edgeRow(actualTC: Double, playerTC: Double) -> some View {
        switch session.difficulty {
        case .easy, .casual:
            let edge = session.rules.playerEdge(atTrueCount: actualTC)
            HStack(spacing: 8) {
                edgePill(edge: edge)
                Spacer(minLength: 0)
                Text(edgeAdvice(edge: edge))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .medium:
            let edge = session.rules.playerEdge(atTrueCount: playerTC)
            HStack(spacing: 8) {
                edgePill(edge: edge)
                Spacer(minLength: 0)
                Text("Edge from your tracked count")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .hard:
            HStack(spacing: 8) {
                Text("Count it yourself — the trainer will quiz you")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Shared

    private func edgePill(edge: Double) -> some View {
        let color: Color = edge > 0.0005 ? .green : (edge < -0.0005 ? .red : .secondary)
        let prefix = edge >= 0 ? "+" : ""
        return HStack(spacing: 4) {
            Text("Edge")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text("\(prefix)\(String(format: "%.2f", edge * 100))%")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func edgeAdvice(edge: Double) -> String {
        if edge > 0.005 { return "Bet bigger — you have the edge" }
        if edge > 0      { return "Slight edge to you" }
        if edge > -0.005 { return "Roughly even" }
        return "House has the edge — bet small"
    }

    private func countPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func formatted(_ d: Double) -> String {
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%+d", Int(d))
        }
        return String(format: "%+.1f", d)
    }
}

/// A self-test mode where the user types in their running count and we tell them if they're right.
struct CountQuizSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var userGuess: String = ""
    @State private var feedback: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("What's the running count?")
                    .font(.title2.weight(.semibold))
                Text("Cards seen this shoe: \(session.engine.shoe.totalCards - session.engine.shoe.remaining)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Your guess", text: $userGuess)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .multilineTextAlignment(.center)

                Button("Check") {
                    let actual = Int(session.counter.runningCount.rounded())
                    let guess = Int(userGuess) ?? Int.min
                    if guess == actual {
                        feedback = "Correct — running count is \(actual)."
                    } else {
                        feedback = "Off — running count is actually \(actual)."
                    }
                }
                .buttonStyle(.borderedProminent)

                if let feedback {
                    Text(feedback)
                        .font(.callout)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Count Check")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
