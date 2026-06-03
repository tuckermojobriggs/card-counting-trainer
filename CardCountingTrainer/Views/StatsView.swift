import SwiftUI
import Charts

struct StatsView: View {
    @Environment(SessionStore.self) private var session
    @State private var scope: StatsScope = .session
    @State private var showingResetConfirm = false

    enum StatsScope: String, CaseIterable, Identifiable {
        case session = "Session"
        case lifetime = "Lifetime"
        var id: String { rawValue }
    }

    /// Whichever stats tier the user is currently viewing. The view is otherwise identical between
    /// the two scopes — same cards, same chart, same details, same reset affordance.
    private var currentStats: SessionStats {
        scope == .session ? session.sessionStats : session.lifetimeStats
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scopePicker
                    summaryGrid
                    Section {
                        chart
                    } header: {
                        sectionHeader("Bankroll")
                    }
                    detailsBlock
                    resetButton
                }
                .padding(16)
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        session.saveStats()
                    }
                }
            }
            .alert(resetAlertTitle, isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    switch scope {
                    case .session: session.resetSession()
                    case .lifetime: session.resetLifetime()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(resetAlertMessage)
            }
        }
    }

    // MARK: - Scope picker

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(StatsScope.allCases) { s in
                Text(s.rawValue).tag(s)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary cards

    private var summaryGrid: some View {
        let stats = currentStats
        let realized = stats.totalNet
        let expected = stats.expectedNet
        let luck = realized - expected
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(title: "Realized",
                         value: realized.formatted(.currency(code: "USD").precision(.fractionLength(0...0))),
                         subtitle: "What you actually won",
                         tint: realized == 0 ? .secondary : (realized > 0 ? .green : .red))
                statCard(title: "Expected",
                         value: expected.formatted(.currency(code: "USD").precision(.fractionLength(0...0))),
                         subtitle: "What your decisions earn on average",
                         tint: expected == 0 ? .secondary : (expected > 0 ? .green : .red))
            }
            HStack(spacing: 12) {
                statCard(title: luck >= 0 ? "Lucky" : "Unlucky",
                         value: luck.formatted(.currency(code: "USD").precision(.fractionLength(0...0))),
                         subtitle: "Realized minus expected",
                         tint: .secondary)
                statCard(title: "Skill cost",
                         value: stats.skillCostDollars.formatted(.currency(code: "USD").precision(.fractionLength(0...0))),
                         subtitle: "Cost of suboptimal plays",
                         tint: stats.skillCostDollars > 0 ? .orange : .secondary)
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String? = nil, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        let stats = currentStats
        if stats.bankrollHistory.isEmpty {
            Text("Play a few hands to see your realized vs. expected profit.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    legendChip(color: .accentColor, label: "Realized")
                    legendChip(color: .orange, label: "Expected")
                }
                .padding(.horizontal, 8)
                Chart {
                    ForEach(stats.bankrollHistory) { p in
                        LineMark(
                            x: .value("Round", p.round),
                            y: .value("Realized", p.bankroll)
                        )
                        .foregroundStyle(by: .value("series", "Realized"))
                        .interpolationMethod(.monotone)
                    }
                    ForEach(stats.expectedHistory) { p in
                        LineMark(
                            x: .value("Round", p.round),
                            y: .value("Expected", p.bankroll)
                        )
                        .foregroundStyle(by: .value("series", "Expected"))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartForegroundStyleScale(["Realized": Color.accentColor, "Expected": Color.orange])
                .chartLegend(.hidden)
                .frame(height: 220)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Hand outcomes + Performance block

    private var detailsBlock: some View {
        statsBlock(currentStats)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statsBlock(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hand outcomes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                row("Hands played", "\(stats.handsPlayed)")
                row("Wins", "\(stats.wins)")
                row("Losses", "\(stats.losses)")
                row("Pushes", "\(stats.pushes)")
                row("Blackjacks", "\(stats.blackjacks)")
                row("Busts", "\(stats.busts)")
                row("Surrenders", "\(stats.surrenders)")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Performance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                row("Total wagered",
                    stats.totalWagered.formatted(.currency(code: "USD").precision(.fractionLength(0...2))))
                row("Total net",
                    stats.totalNet.formatted(.currency(code: "USD").precision(.fractionLength(0...2))))
                row("Realized expected value",
                    String(format: "%+.2f%%", stats.realizedEV * 100))
                row("Decisions made", "\(stats.decisionsMade)")
                row("Decision accuracy",
                    String(format: "%.1f%%", stats.decisionAccuracy * 100))
                if stats.insuranceDecisions > 0 {
                    row("Insurance accuracy",
                        String(format: "%.1f%%", stats.insuranceAccuracy * 100))
                }
            }
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button(role: .destructive) {
            showingResetConfirm = true
        } label: {
            Label(scope == .session ? "Reset session" : "Reset lifetime stats", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private var resetAlertTitle: String {
        scope == .session ? "Reset session?" : "Reset lifetime stats?"
    }

    private var resetAlertMessage: String {
        switch scope {
        case .session:
            return "Sets bankroll back to $1,000, clears session stats, reshuffles the shoe, and resets the count. Lifetime stats stay where they are."
        case .lifetime:
            return "Wipes lifetime stats. Also resets bankroll to $1,000 and clears session stats. This cannot be undone."
        }
    }

    // MARK: - Small building blocks

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).font(.callout.monospacedDigit())
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}
