import SwiftUI

struct GameView: View {
    @Environment(SessionStore.self) private var session
    @State private var showingHelp = false
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                tableBackground
                    .ignoresSafeArea()

                gameContent

                if session.pendingHardAction != nil {
                    HardCountPromptOverlay()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: session.pendingHardAction)
            .navigationTitle("Trainer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingResetConfirm = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset session")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("What is this?")
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheet()
            }
            .alert("Reset session?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    session.resetSession()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Sets bankroll back to $1,000, clears your session stats, reshuffles the shoe, and resets the count. Lifetime stats stay where they are.")
            }
        }
    }

    private var gameContent: some View {
        VStack(spacing: 12) {
            topBar
            dealerArea
            Divider().background(.white.opacity(0.2))
            playerArea
            Spacer(minLength: 0)
            feedbackArea
            if session.difficulty == .medium {
                playerCountBar
            }
            bottomBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var tableBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.30, blue: 0.18), Color(red: 0.02, green: 0.18, blue: 0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topBar: some View {
        // Expected = expected value of the decisions you actually made (perfect-play baseline minus
        // skill cost). Perfect = what perfect play would have averaged at the counts you saw — the
        // skill cost (cumulative gap) is exactly Perfect minus Expected. Both are session-scoped so
        // a Reset Session brings them back to $0 alongside the bankroll.
        let expected = session.sessionStats.expectedNet
        let perfect = expected + session.sessionStats.skillCostDollars
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                summaryColumn(label: "Bankroll",
                              value: session.bankroll,
                              tint: .white)
                summaryDivider
                summaryColumn(label: "Expected",
                              value: expected,
                              tint: expected == 0 ? .white : (expected > 0 ? .green : .red))
                summaryDivider
                summaryColumn(label: "Perfect",
                              value: perfect,
                              tint: perfect == 0 ? .white : (perfect > 0 ? .green : .red))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )

            CountDisplayView()
                .colorScheme(.dark)
        }
    }

    // MARK: - Player count bar (Medium only)

    private var playerCountBar: some View {
        HStack(spacing: 12) {
            countStepperButton(systemImage: "minus") {
                session.decrementPlayerCount()
            }
            VStack(spacing: 1) {
                Text("Your count")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(formatSigned(session.playerRunningCount))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            countStepperButton(systemImage: "plus") {
                session.incrementPlayerCount()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    private func countStepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func summaryColumn(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0...0)))
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 30)
    }

    /// Cards from `cards` that have been dealt onto the table so far. During a paced deal this grows
    /// one card at a time; the rest stay hidden until their turn to land.
    private func revealed(_ cards: [Card]) -> [Card] {
        cards.filter { session.revealedCardIDs.contains($0.id) }
    }

    private func handTotal(_ cards: [Card]) -> Int {
        var h = Hand()
        h.cards = cards
        return h.total
    }

    private func handIsSoft(_ cards: [Card]) -> Bool {
        var h = Hand()
        h.cards = cards
        return h.isSoft
    }

    private var dealerArea: some View {
        let dealer = session.engine.round.dealerHand
        let phase = session.engine.round.phase
        let shouldHide = phase == .playerTurn || phase == .insuranceOffered
        let visible = revealed(dealer.cards)
        return VStack(spacing: 6) {
            HStack {
                Text("Dealer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            if dealer.cards.isEmpty {
                emptySeat(label: "Dealer waits")
            } else {
                HandView(
                    cards: visible,
                    hideSecondCard: shouldHide && visible.count >= 2,
                    label: nil,
                    total: shouldHide ? visible.first.map { $0.rank.blackjackValue } : handTotal(visible),
                    isSoft: shouldHide ? false : handIsSoft(visible),
                    isActive: false,
                    size: .regular,
                    animateInsertion: !session.fastDealing
                )
                .colorScheme(.dark)
            }
        }
    }

    private var playerArea: some View {
        let hands = session.engine.round.hands
        let activeIdx = session.engine.round.currentHandIndex
        let phase = session.engine.round.phase
        let hideTotals = session.difficulty.hidesPlayerHandTotals
        return VStack(spacing: 8) {
            HStack {
                Text("You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            if hands.isEmpty {
                emptySeat(label: "Place a bet to deal")
            } else {
                ForEach(Array(hands.enumerated()), id: \.offset) { idx, hand in
                    let visible = revealed(hand.cards)
                    let result = session.engine.round.results.indices.contains(idx)
                        ? badge(for: session.engine.round.results[idx])
                        : nil
                    HandView(
                        cards: visible,
                        hideSecondCard: false,
                        label: hands.count > 1 ? "Hand \(idx + 1)  •  Bet $\(Int(hand.bet))" : "Bet $\(Int(hand.bet))",
                        total: hideTotals ? nil : handTotal(visible),
                        isSoft: handIsSoft(visible),
                        isActive: phase == .playerTurn && idx == activeIdx,
                        resultBadge: result,
                        size: .regular,
                        animateInsertion: !session.fastDealing
                    )
                    .colorScheme(.dark)
                }
            }
        }
    }

    private func emptySeat(label: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: CardSize.regular.height)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var feedbackArea: some View {
        VStack(spacing: 6) {
            if session.actionBlocked {
                blockedByCountBanner
            }
            if session.showCorrectAction {
                if let f = session.lastInsuranceFeedback {
                    insuranceFeedbackRow(f)
                }
                if let f = session.lastFeedback {
                    actionFeedbackRow(f)
                }
            }
        }
    }

    private var blockedByCountBanner: some View {
        let target = session.actualRunningCountInt
        let you = session.playerRunningCount
        let direction = you > target ? "down" : "up"
        let gap = Swift.abs(you - target)
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Action blocked — adjust your count to \(formatSigned(target)) to continue")
                    .foregroundStyle(.white)
                if gap > 0 {
                    Text("You have \(formatSigned(you)). Tap the \(direction) arrow \(gap) time\(gap == 1 ? "" : "s").")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .padding(8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatSigned(_ n: Int) -> String {
        n >= 0 ? "+\(n)" : "\(n)"
    }

    private func actionFeedbackRow(_ f: ActionFeedback) -> some View {
        HStack(spacing: 10) {
            Image(systemName: f.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(f.isCorrect ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                if f.isCorrect {
                    Text("\(f.optimal.displayName) was best")
                        .foregroundStyle(.white)
                } else {
                    Text("Best play was \(f.optimal.displayName) — you played \(f.chosen.displayName)")
                        .foregroundStyle(.white)
                }
                if !f.isCorrect, let chosen = f.chosenEV, let optimal = f.optimalEV {
                    let cost = optimal - chosen
                    Text(String(format: "Expected value lost: %.3f units per bet", cost))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let chart = f.chartAction {
                    Text("Count deviation — chart says \(chart.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.yellow.opacity(0.85))
                }
            }
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .padding(8)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func insuranceFeedbackRow(_ f: InsuranceFeedback) -> some View {
        HStack(spacing: 10) {
            Image(systemName: f.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(f.isCorrect ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                let action = f.took ? "took insurance" : "declined insurance"
                if f.isCorrect {
                    Text(f.optimalTook
                         ? "Correct — insurance is in your favor here"
                         : "Correct — insurance is against you here")
                        .foregroundStyle(.white)
                } else {
                    Text(f.optimalTook
                         ? "Insurance was the right call — you \(action)"
                         : "Should have declined — you \(action)")
                        .foregroundStyle(.white)
                }
                let pct = f.probabilityOfTen * 100
                let comparator = pct > (100.0 / 3.0) ? "above" : "below"
                Text(String(format: "Dealer-ten probability: %.1f%% (%@ the 33.3%% break-even)", pct, comparator))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .padding(8)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }


    @ViewBuilder
    private var bottomBar: some View {
        let phase = session.engine.round.phase
        switch phase {
        case .idle, .complete:
            VStack(spacing: 8) {
                if phase == .complete {
                    let net = session.engine.round.totalPayout
                    Text(net == 0
                         ? "Push"
                         : (net > 0 ? "Won \(currency(net))" : "Lost \(currency(-net))"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(net > 0 ? .green : (net < 0 ? .red : .white))
                }
                BetInputView(
                    bet: Binding(
                        get: { session.currentBet },
                        set: { session.currentBet = $0 }
                    ),
                    bankroll: session.bankroll
                )
                Button {
                    session.deal()
                } label: {
                    Text("Deal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(session.currentBet <= 0 || session.currentBet > session.bankroll)
            }
        case .insuranceOffered:
            InsuranceBarView(
                onTake: { session.takeInsurance() },
                onDecline: { session.declineInsurance() }
            )
        case .playerTurn:
            ActionBarView(
                legal: session.engine.availableActions(),
                onAction: { action in
                    switch action {
                    case .hit:       session.hit()
                    case .stand:     session.stand()
                    case .double:    session.double()
                    case .split:     session.split()
                    case .surrender: session.surrender()
                    }
                }
            )
        case .dealerTurn:
            Text("Dealer playing…")
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func currency(_ d: Double) -> String {
        d.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
    }

    private func badge(for r: HandResult) -> String {
        // Show fractional dollars when the payout isn't whole (Blackjack at 3:2, Surrender at half bet).
        let amount = Swift.abs(r.payout).formatted(.number.precision(.fractionLength(0...2)))
        switch r.outcome {
        case .blackjack: return "Blackjack +\(amount)"
        case .win:       return "Win +\(amount)"
        case .loss:      return "Loss -\(amount)"
        case .push:      return "Push"
        case .bust:      return "Bust -\(amount)"
        case .surrender: return "Surrender -\(amount)"
        }
    }
}

struct BetInputView: View {
    @Binding var bet: Double
    let bankroll: Double

    var body: some View {
        HStack(spacing: 8) {
            ForEach(chipValues, id: \.self) { v in
                Button {
                    bet = min(max(0, v), bankroll)
                } label: {
                    Text("$\(Int(v))")
                        .font(.footnote.weight(.bold))
                        .frame(minWidth: 44, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(bet == v ? .yellow : .white)
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
    }

    private var chipValues: [Double] {
        [5, 10, 25, 50, 100]
    }
}
