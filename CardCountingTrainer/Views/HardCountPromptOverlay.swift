import SwiftUI

/// Modal that pops up on Hard difficulty when the random spot-check fires. Player types in their
/// running count and the trainer reveals whether the actual is higher or lower. The action that
/// triggered the check stays suspended until the player guesses right — at that point the overlay
/// flashes green, dismisses, and `SessionStore.applyHardCountCorrect()` re-runs the action.
struct HardCountPromptOverlay: View {
    @Environment(SessionStore.self) private var session
    @State private var guess: String = ""
    @State private var hint: HardCountResult? = nil
    @State private var showingCorrect = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { /* swallow taps so background doesn't react */ }

            card
                .offset(x: shakeOffset)
                .padding(.horizontal, 32)
        }
        .onAppear { fieldFocused = true }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text("Count check")
                .font(.title3.weight(.bold))
            Text("What's the running count right now?")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your guess", text: $guess)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.bold).monospacedDigit())
                .focused($fieldFocused)
                .onSubmit { submit() }
                .disabled(showingCorrect)

            feedbackRow

            Button {
                submit()
            } label: {
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(guess.isEmpty || showingCorrect)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var feedbackRow: some View {
        if showingCorrect {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Correct")
            }
            .font(.title3.weight(.bold))
            .foregroundStyle(.green)
            .frame(height: 28)
            .transition(.scale.combined(with: .opacity))
        } else if let hint {
            HStack(spacing: 8) {
                Image(systemName: hint == .higher ? "arrow.up" : "arrow.down")
                Text(hint == .higher ? "Higher" : "Lower")
            }
            .font(.title3.weight(.bold))
            .foregroundStyle(.red)
            .frame(height: 28)
        } else {
            Color.clear.frame(height: 28)
        }
    }

    private func submit() {
        guard let parsed = Int(guess.trimmingCharacters(in: .whitespaces)) else { return }
        let result = session.checkHardCountGuess(parsed)
        switch result {
        case .correct:
            hint = nil
            withAnimation(.spring(duration: 0.25)) { showingCorrect = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                session.applyHardCountCorrect()
            }
        case .higher, .lower:
            hint = result
            guess = ""
            shake()
        }
    }

    private func shake() {
        let steps: [CGFloat] = [-12, 12, -8, 8, -4, 4, 0]
        for (i, offset) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.easeOut(duration: 0.05)) {
                    shakeOffset = offset
                }
            }
        }
    }
}
