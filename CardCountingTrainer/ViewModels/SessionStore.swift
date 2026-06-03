import Foundation
import Observation
import SwiftUI

/// Top-level session state — engine, count tracker, persisted preferences and stats.
/// Single source of truth shared across tabs via `.environment(...)`.
@Observable
final class SessionStore {

    // MARK: - Persisted preferences

    var rules: DealerRules {
        didSet { persistRules() }
    }
    var countingSystemKind: CountingSystemKind {
        didSet { persistCountingSystem(); resetEngineForRulesChange() }
    }
    var defaultBet: Double {
        didSet { UserDefaults.standard.set(defaultBet, forKey: K.defaultBet) }
    }
    var bankroll: Double {
        didSet { UserDefaults.standard.set(bankroll, forKey: K.bankroll) }
    }
    var showRunningCount: Bool {
        didSet { UserDefaults.standard.set(showRunningCount, forKey: K.showRunningCount) }
    }
    var showTrueCount: Bool {
        didSet { UserDefaults.standard.set(showTrueCount, forKey: K.showTrueCount) }
    }
    var showCorrectAction: Bool {
        didSet { UserDefaults.standard.set(showCorrectAction, forKey: K.showCorrectAction) }
    }
    var fastDealing: Bool {
        didSet { UserDefaults.standard.set(fastDealing, forKey: K.fastDealing) }
    }
    /// Flipped to true the first time the welcome sheet is dismissed. There's no way to un-set it
    /// from the UI — onboarding only ever fires on a fresh install.
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: K.hasSeenOnboarding) }
    }
    var difficulty: Difficulty {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: K.difficulty)
            // Bringing the player-tracked count back in sync with the actual count when switching
            // into a self-tracking difficulty — otherwise the first move would grade against a
            // stale value the player never had a chance to type.
            if difficulty.playerMaintainsCount && !oldValue.playerMaintainsCount {
                resyncPlayerRunningCount()
            }
        }
    }
    var savedProfiles: [DealerRules] {
        didSet { persistProfiles() }
    }

    // MARK: - Live state

    var engine: BlackjackEngine
    var counter: CountTracker
    /// Stats accumulated during the current "sitting" — wiped on Reset Session and persisted across
    /// app launches so a session survives backgrounding. Drives the top of the Play screen and the
    /// summary cards / chart at the top of the Stats screen.
    var sessionStats: SessionStats
    /// Cumulative stats across every hand the player has ever played. Only wiped by Reset Lifetime
    /// from the Stats tab.
    var lifetimeStats: SessionStats
    var currentBet: Double
    var lastFeedback: ActionFeedback? = nil
    var lastInsuranceFeedback: InsuranceFeedback? = nil
    var pendingResultBanner: String? = nil

    /// True when the most recent action attempt was rejected because the player's tracked count
    /// didn't match the actual count. Set inside each action method on Medium when the guard fails;
    /// cleared automatically as soon as the player adjusts their count back to correct.
    var actionBlocked: Bool = false

    /// On Hard difficulty, the action the player just attempted that has been gated behind a count
    /// quiz. The view layer observes this and presents the prompt overlay when it's non-nil.
    var pendingHardAction: HardAction? = nil

    /// IDs of cards currently "placed" on the table. Newly dealt cards are added to this set one at a
    /// time on a timer so the deal looks like a dealer pitching cards from the shoe. Tracked by ID
    /// rather than a count because a hit inserts a card into the middle of the deal order.
    var revealedCardIDs: Set<UUID> = []
    private var dealRevealWorkItems: [DispatchWorkItem] = []

    /// Seconds between each card landing during a non-fast deal.
    static let dealInterval: Double = 0.32

    /// Brief pause between the player tapping a non-deal action (hit, stand, double, split,
    /// insurance) and the resulting card(s) starting to land, so the play feels deliberate rather
    /// than instant.
    static let postActionPause: Double = 0.5

    /// Internal flag set after a correct count guess so the action method that re-runs doesn't roll
    /// the 10% check a second time and trap the user in a loop.
    private var hardCheckBypass: Bool = false

    /// The running count as the player believes it to be — only meaningful when
    /// `difficulty.playerMaintainsCount` is true. The trainer compares this to the actual
    /// `counter.runningCount` after each decision on Medium difficulty.
    var playerRunningCount: Int = 0 {
        didSet {
            // Any time the player corrects their count back to matching, drop the "you tried an
            // action with the wrong count" block so the warning banner clears on its own.
            if !mustCorrectCount { actionBlocked = false }
        }
    }


    init() {
        let loadedRules = Self.loadRules() ?? .default
        let loadedSystem = Self.loadCountingSystem() ?? .hiLo
        let loadedBet = UserDefaults.standard.object(forKey: K.defaultBet) as? Double ?? 5
        let loadedBankroll = UserDefaults.standard.object(forKey: K.bankroll) as? Double ?? 1000
        let loadedShowRC = UserDefaults.standard.object(forKey: K.showRunningCount) as? Bool ?? true
        let loadedShowTC = UserDefaults.standard.object(forKey: K.showTrueCount) as? Bool ?? true
        let loadedShowCA = UserDefaults.standard.object(forKey: K.showCorrectAction) as? Bool ?? true
        let loadedFastDealing = UserDefaults.standard.object(forKey: K.fastDealing) as? Bool ?? false
        let loadedHasSeenOnboarding = UserDefaults.standard.object(forKey: K.hasSeenOnboarding) as? Bool ?? false
        let loadedDifficulty: Difficulty = {
            if let raw = UserDefaults.standard.string(forKey: K.difficulty),
               let d = Difficulty(rawValue: raw) {
                return d
            }
            return .easy
        }()
        let loadedProfiles = Self.loadProfiles()
        let loadedSessionStats = Self.loadSessionStats() ?? SessionStats()
        let loadedLifetimeStats = Self.loadLifetimeStats() ?? SessionStats()
        let counter = CountTracker(system: CountingSystems.make(loadedSystem), decks: loadedRules.deckCount)

        self.rules = loadedRules
        self.countingSystemKind = loadedSystem
        self.defaultBet = loadedBet
        self.bankroll = loadedBankroll
        self.showRunningCount = loadedShowRC
        self.showTrueCount = loadedShowTC
        self.showCorrectAction = loadedShowCA
        self.fastDealing = loadedFastDealing
        self.hasSeenOnboarding = loadedHasSeenOnboarding
        self.difficulty = loadedDifficulty
        self.savedProfiles = loadedProfiles
        self.engine = BlackjackEngine(rules: loadedRules)
        self.counter = counter
        self.sessionStats = loadedSessionStats
        self.lifetimeStats = loadedLifetimeStats
        self.currentBet = loadedBet
        self.playerRunningCount = Int(counter.runningCount.rounded())
    }

    // MARK: - Round actions (proxy to engine, updating counter + stats)

    /// Begin a new round. Observes any cards that were just dealt and clears stale feedback.
    func deal() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.deal) { return }
        lastFeedback = nil
        lastInsuranceFeedback = nil
        pendingResultBanner = nil
        // New round: clear the table and re-deal cards one at a time.
        cancelPendingReveals()
        revealedCardIDs.removeAll()
        let beforeRemaining = engine.shoe.remaining
        engine.startRound(bet: currentBet)
        observeDealtCards(beforeRemaining: beforeRemaining)
        // `recountVisibleCards` already skips the dealer's hole card on the deal — the phase is
        // playerTurn or insuranceOffered at this point, so only the upcard joins the count. No
        // hole-card adjustment is needed here.
        // Pre-deal baseline expected value: edge × bet. This is what perfect play averages over many
        // trials at the current count. Skill-cost adjustments later subtract from this baseline when
        // the player makes suboptimal decisions. The realized outcome (win, loss, blackjack, etc.)
        // doesn't change this — that's the variance we're trying to separate from skill.
        let tc = counter.trueCount(decksRemaining: engine.shoe.decksRemaining)
        let edge = rules.playerEdge(atTrueCount: tc)
        applyToBothStats { $0.expectedNet += edge * engine.round.initialBet }

        if engine.round.phase == .complete { recordRoundResult() }
        else { evaluateBannerForOpening() }
        scheduleCardReveals()
    }

    func hit() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.hit) { return }
        ensureFeedback(action: .hit)
        let before = engine.shoe.remaining
        engine.hit()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        else { evaluateBannerForOpening() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func stand() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.stand) { return }
        ensureFeedback(action: .stand)
        let before = engine.shoe.remaining
        engine.stand()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func double() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.double) { return }
        ensureFeedback(action: .double)
        let before = engine.shoe.remaining
        engine.double()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func split() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.split) { return }
        ensureFeedback(action: .split)
        let before = engine.shoe.remaining
        engine.split()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func surrender() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.surrender) { return }
        ensureFeedback(action: .surrender)
        let before = engine.shoe.remaining
        engine.surrender()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func takeInsurance() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.takeInsurance) { return }
        // Grade BEFORE we reveal the hole card to the count — feedback uses pre-peek information only.
        gradeInsurance(took: true)
        let beforeRemaining = engine.shoe.remaining
        engine.takeInsurance()
        // The dealer's peek is private unless they actually have blackjack. `recountVisibleCards`
        // gates the hole card behind a phase check — it only flips into the count when the round
        // ends on dealer blackjack (or play reaches dealer turn). No manual hole-card add needed.
        observeDealtCards(beforeRemaining: beforeRemaining)
        if engine.round.phase == .complete { recordRoundResult() }
        else { evaluateBannerForOpening() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    func declineInsurance() {
        if blockIfCountWrong() { return }
        if rollHardCheck(.declineInsurance) { return }
        gradeInsurance(took: false)
        let before = engine.shoe.remaining
        engine.declineInsurance()
        observeDealtCards(beforeRemaining: before)
        if engine.round.phase == .complete { recordRoundResult() }
        else { evaluateBannerForOpening() }
        scheduleCardReveals(leadDelay: Self.postActionPause)
    }

    // MARK: - Card-deal animation

    private func tableCardsInDealOrder() -> [Card] {
        var result: [Card] = []
        for hand in engine.round.hands { result.append(contentsOf: hand.cards) }
        result.append(contentsOf: engine.round.dealerHand.cards)
        return result
    }

    private func cancelPendingReveals() {
        for item in dealRevealWorkItems { item.cancel() }
        dealRevealWorkItems.removeAll()
    }

    /// Reveal any newly dealt cards. With Fast dealing they all appear at once; otherwise the first
    /// new card waits `leadDelay` seconds, and each subsequent card lands `dealInterval` seconds
    /// after it. The lead delay gives a beat after a hit / stand / double / split before cards
    /// start arriving; pass 0 for the opening deal so the table starts filling immediately.
    private func scheduleCardReveals(leadDelay: Double = 0) {
        let newCards = tableCardsInDealOrder().filter { !revealedCardIDs.contains($0.id) }
        guard !newCards.isEmpty else { return }
        if fastDealing {
            for card in newCards { revealedCardIDs.insert(card.id) }
            return
        }
        for (offset, card) in newCards.enumerated() {
            let item = DispatchWorkItem { [weak self] in
                self?.revealedCardIDs.insert(card.id)
            }
            dealRevealWorkItems.append(item)
            let delay = leadDelay + Double(offset) * Self.dealInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    /// Guard called at the top of every action method. On Medium difficulty, refuses the action when
    /// the player's tracked count doesn't match the actual count, flips `actionBlocked` so the UI can
    /// show a corrective banner, and returns true to short-circuit the caller. Returns false (and
    /// clears any prior block) when the action is allowed to proceed.
    @discardableResult
    private func blockIfCountWrong() -> Bool {
        if mustCorrectCount {
            actionBlocked = true
            return true
        }
        actionBlocked = false
        return false
    }

    /// On Hard difficulty, roll the random spot-check at the top of an action. With probability
    /// `Self.hardCheckProbability`, the action is suspended, `pendingHardAction` is set so the UI can
    /// surface a count quiz, and the method returns true. Easy/Casual/Medium always pass through.
    /// `hardCheckBypass` short-circuits the second call when the user passes the check — otherwise
    /// the re-invocation would roll again and could loop indefinitely.
    @discardableResult
    private func rollHardCheck(_ action: HardAction) -> Bool {
        guard difficulty == .hard else { return false }
        if hardCheckBypass {
            hardCheckBypass = false
            return false
        }
        if Double.random(in: 0..<1) < Self.hardCheckProbability {
            pendingHardAction = action
            return true
        }
        return false
    }

    static let hardCheckProbability: Double = 0.10

    /// Compare a player's count guess against the actual running count. Pure check — does not mutate
    /// state or execute the pending action. The UI uses this to show "Higher" / "Lower" hints on
    /// every wrong guess before eventually calling `applyHardCountCorrect()` on a right one.
    func checkHardCountGuess(_ guess: Int) -> HardCountResult {
        let actual = actualRunningCountInt
        if guess == actual { return .correct }
        return actual > guess ? .higher : .lower
    }

    /// Player got the count right — clear the pending action and re-run it. `hardCheckBypass` keeps
    /// the re-run from rolling another 10% check.
    func applyHardCountCorrect() {
        let action = pendingHardAction
        pendingHardAction = nil
        hardCheckBypass = true
        guard let action else { return }
        switch action {
        case .deal:             deal()
        case .hit:              hit()
        case .stand:            stand()
        case .double:           double()
        case .split:            split()
        case .surrender:        surrender()
        case .takeInsurance:    takeInsurance()
        case .declineInsurance: declineInsurance()
        }
    }

    // MARK: - Counting

    /// Recount visible cards after an engine action. Always runs — phase transitions (e.g. dealer
    /// blackjack revealed after insurance peek) can expose previously-hidden cards even when no
    /// new cards were drawn from the shoe. `recountVisibleCards` dedupes via `observedCardIDs`.
    private func observeDealtCards(beforeRemaining: Int) {
        _ = beforeRemaining
        recountVisibleCards()
    }

    /// Re-derive running count from the cards currently visible on the table + cards already removed
    /// from prior rounds. We track what we've already counted via a private offset.
    private var observedCardIDs: Set<UUID> = []

    private func recountVisibleCards() {
        var visible: [Card] = []
        for h in engine.round.hands { visible.append(contentsOf: h.cards) }
        // Dealer's upcard (cards[0]) is always visible. Hole card (cards[1]) is visible only after dealer turn.
        let dealer = engine.round.dealerHand
        if !dealer.cards.isEmpty { visible.append(dealer.cards[0]) }
        if engine.round.phase == .complete || engine.round.phase == .dealerTurn || engine.round.endedOnDealerBlackjack {
            for c in dealer.cards.dropFirst() { visible.append(c) }
        }

        for c in visible where !observedCardIDs.contains(c.id) {
            counter.runningCount += counter.system.tag(for: c.rank)
            observedCardIDs.insert(c.id)
        }
    }

    // MARK: - Stats + correctness feedback

    /// Grade the player's decision against the highest-expected-value action computed from the actual
    /// remaining shoe composition. The session expected-value tracker subtracts each suboptimal
    /// decision's "skill cost" from the pre-deal baseline that was added in `deal()`.
    private func ensureFeedback(action userAction: PlayerAction) {
        guard engine.round.phase == .playerTurn,
              let hand = engine.round.currentHand,
              let upcard = engine.round.dealerHand.cards.first
        else { return }
        let legal = engine.availableActions()
        let composition = engine.shoe.rankCounts
        let evs = EVCalculator.evaluate(
            hand: hand,
            dealerUpcard: upcard,
            rules: rules,
            composition: composition,
            legal: legal
        )
        let optimal = EVCalculator.bestAction(evs) ?? .stand
        let isCorrect = userAction == optimal
        let tc = counter.trueCount(decksRemaining: engine.shoe.decksRemaining)
        // Use the chart's raw (basic-strategy) recommendation rather than the legality-resolved one,
        // and only surface it as a deviation when it's actually a legal action. Otherwise the chart's
        // fallback (e.g. Surrender → Stand on a 3-card hand) gets misreported as a count deviation.
        let rawChart = BasicStrategy.rawRecommendation(hand: hand, dealerUpcard: upcard, rules: rules)
        let chartAction: PlayerAction? = (legal.contains(rawChart) && rawChart != optimal) ? rawChart : nil
        lastFeedback = ActionFeedback(
            chosen: userAction,
            optimal: optimal,
            chartAction: chartAction,
            isCorrect: isCorrect,
            chosenEV: evs[userAction],
            optimalEV: evs[optimal],
            handTotal: hand.total,
            isSoft: hand.isSoft,
            dealerUpcardLabel: upcard.label,
            trueCountAtDecision: tc
        )
        applyToBothStats { $0.recordDecision(isCorrect: isCorrect) }

        // Skill cost in dollars. EV values are per-unit-of-original-bet (double already includes its
        // 2x multiplier; split already sums both sub-hands).
        let evChosen = evs[userAction] ?? 0
        let evBest = evs[optimal] ?? 0
        let skillCost = max(0, evBest - evChosen) * hand.bet
        applyToBothStats {
            $0.expectedNet -= skillCost
            $0.skillCostDollars += skillCost
        }
    }

    /// Probability that the dealer's hole card is a ten-valued card, using the live shoe composition.
    /// By exchangeability the hole card is distributed identically to the next card from the shoe, so
    /// `tens-in-shoe / cards-in-shoe` is the count-aware estimate consistent with the EV calculator.
    /// At high true counts the shoe is rich in tens and this rises above the 1/3 break-even, which is
    /// exactly when insurance becomes correct.
    private func probabilityOfTenInHole() -> Double {
        let total = engine.shoe.remaining
        guard total > 0 else { return 0 }
        return Double(engine.shoe.tenCount) / Double(total)
    }

    private func gradeInsurance(took: Bool) {
        let pTen = probabilityOfTenInHole()
        let optimalTook = pTen > 1.0 / 3.0
        let isCorrect = took == optimalTook
        let tc = counter.trueCount(decksRemaining: engine.shoe.decksRemaining)
        lastInsuranceFeedback = InsuranceFeedback(
            took: took,
            optimalTook: optimalTook,
            isCorrect: isCorrect,
            probabilityOfTen: pTen,
            trueCountAtDecision: tc
        )
        applyToBothStats { $0.recordInsuranceDecision(took: took, wasCorrect: isCorrect) }

        // Insurance is a side bet (half the original bet, pays 2:1 if dealer has a ten). EV in dollars:
        //   take    = (3*pTen - 1) * (initialBet / 2)
        //   decline = 0
        // The pre-deal baseline assumed perfect insurance play (taking +EV insurance when offered), so
        // the only adjustment we need here is the skill cost when the player diverges from optimal.
        let initialBet = engine.round.initialBet
        let insuranceBet = initialBet / 2.0
        let evTake = (3 * pTen - 1) * insuranceBet
        let evChosen = took ? evTake : 0
        let evBest = max(evTake, 0)
        let skillCost = max(0, evBest - evChosen)
        applyToBothStats {
            $0.expectedNet -= skillCost
            $0.skillCostDollars += skillCost
        }
    }

    private func evaluateBannerForOpening() {
        // Used for visible signal, no-op currently.
    }

    // MARK: - Player-tracked count (Medium / Hard difficulty)

    func incrementPlayerCount() { playerRunningCount += 1 }
    func decrementPlayerCount() { playerRunningCount -= 1 }

    /// True count derived from the player's *tracked* running count. This is what gets shown to the
    /// player on Medium difficulty, and what the eye peek reveals on Hard — even if their tracked
    /// count is wrong, we honor it so the resulting strategy advice reflects what they believe.
    func playerTrueCount() -> Double {
        let decks = engine.shoe.decksRemaining
        guard decks > 0 else { return 0 }
        return Double(playerRunningCount) / decks
    }

    /// Snap the player's count to the actual running count. Called when the shoe reshuffles, when
    /// the player resets the session, and when they switch into a self-tracking difficulty mid-shoe.
    private func resyncPlayerRunningCount() {
        playerRunningCount = Int(counter.runningCount.rounded())
    }

    /// The actual running count rounded to the nearest integer — surfaced to the player when their
    /// tracked count is wrong and they need to match it before acting.
    var actualRunningCountInt: Int {
        Int(counter.runningCount.rounded())
    }

    /// On Medium difficulty, the trainer refuses actions until the player's tracked running count
    /// matches the actual count. Returns true exactly when the player needs to fix their count
    /// before deal / hit / stand / etc. can fire. Easy, Casual, and Hard always return false.
    var mustCorrectCount: Bool {
        guard difficulty.gradesPlayerCount else { return false }
        return playerRunningCount != actualRunningCountInt
    }

    /// After a round completes, settle bankroll and update stats. Expected value already reflects the
    /// pre-deal baseline (added in `deal()`) minus any skill costs from suboptimal decisions, so we
    /// don't touch `expectedNet` here — that's the whole point of the skill-vs-luck split.
    private func recordRoundResult() {
        let payout = engine.round.totalPayout
        bankroll += payout
        let totalBet = engine.round.totalAmountWagered
        applyToBothStats {
            $0.recordRound(
                net: payout,
                wagered: totalBet,
                handResults: engine.round.results,
                insuranceTaken: engine.round.insuranceTaken
            )
        }
        observedCardIDs.removeAll()
        if engine.shoe.needsShuffle {
            counter.runningCount = counter.system.initialRunningCount(decks: rules.deckCount)
            resyncPlayerRunningCount()
        }
    }

    /// Apply the same mutation to both `sessionStats` and `lifetimeStats` so every recorded round /
    /// decision / skill cost shows up in both tiers.
    private func applyToBothStats(_ apply: (inout SessionStats) -> Void) {
        apply(&sessionStats)
        apply(&lifetimeStats)
    }

    // MARK: - Settings / resets

    func resetEngineForRulesChange() {
        engine = BlackjackEngine(rules: rules)
        counter = CountTracker(system: CountingSystems.make(countingSystemKind), decks: rules.deckCount)
        observedCardIDs.removeAll()
        cancelPendingReveals()
        revealedCardIDs.removeAll()
        resyncPlayerRunningCount()
    }

    /// "Reset session" from the Play screen. Returns bankroll to the starting amount, wipes the
    /// session stats, reshuffles the shoe, resets the count, and applies any pending settings
    /// changes (which only take effect on reset). Lifetime stats are preserved.
    func resetSession(startingBankroll: Double = 1000) {
        engine = BlackjackEngine(rules: rules)
        counter = CountTracker(system: CountingSystems.make(countingSystemKind), decks: rules.deckCount)
        observedCardIDs.removeAll()
        cancelPendingReveals()
        revealedCardIDs.removeAll()
        resyncPlayerRunningCount()
        actionBlocked = false
        pendingHardAction = nil
        hardCheckBypass = false
        lastFeedback = nil
        lastInsuranceFeedback = nil
        pendingResultBanner = nil
        bankroll = startingBankroll
        sessionStats = SessionStats()
        Self.persistSessionStats(sessionStats)
    }

    /// "Reset lifetime" from the Stats screen. Wipes both tiers of stats and resets the bankroll —
    /// effectively a clean slate as if the app had just been installed.
    func resetLifetime(startingBankroll: Double = 1000) {
        resetSession(startingBankroll: startingBankroll)
        lifetimeStats = SessionStats()
        Self.persistLifetimeStats(lifetimeStats)
    }

    // MARK: - Persistence

    private enum K {
        static let rules            = "rules"
        static let countingSystem   = "countingSystem"
        static let defaultBet       = "defaultBet"
        static let bankroll         = "bankroll"
        static let showRunningCount = "showRunningCount"
        static let showTrueCount    = "showTrueCount"
        static let showCorrectAction = "showCorrectAction"
        static let fastDealing      = "fastDealing"
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let difficulty       = "difficulty"
        static let profiles         = "profiles"
        static let sessionStats     = "sessionStats"
        static let lifetimeStats    = "lifetimeStats"
        /// Pre-split key — read once on launch and migrated into `lifetimeStats`.
        static let legacyStats      = "stats"
    }

    private func persistRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: K.rules)
        }
    }
    private func persistCountingSystem() {
        UserDefaults.standard.set(countingSystemKind.rawValue, forKey: K.countingSystem)
    }
    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(savedProfiles) {
            UserDefaults.standard.set(data, forKey: K.profiles)
        }
    }
    static func persistSessionStats(_ stats: SessionStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: K.sessionStats)
        }
    }
    static func persistLifetimeStats(_ stats: SessionStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: K.lifetimeStats)
        }
    }
    func saveStats() {
        Self.persistSessionStats(sessionStats)
        Self.persistLifetimeStats(lifetimeStats)
    }

    private static func loadRules() -> DealerRules? {
        guard let data = UserDefaults.standard.data(forKey: K.rules) else { return nil }
        return try? JSONDecoder().decode(DealerRules.self, from: data)
    }
    private static func loadCountingSystem() -> CountingSystemKind? {
        guard let s = UserDefaults.standard.string(forKey: K.countingSystem) else { return nil }
        return CountingSystemKind(rawValue: s)
    }
    private static func loadProfiles() -> [DealerRules] {
        guard let data = UserDefaults.standard.data(forKey: K.profiles) else { return [] }
        return (try? JSONDecoder().decode([DealerRules].self, from: data)) ?? []
    }
    private static func loadSessionStats() -> SessionStats? {
        guard let data = UserDefaults.standard.data(forKey: K.sessionStats) else { return nil }
        return try? JSONDecoder().decode(SessionStats.self, from: data)
    }
    private static func loadLifetimeStats() -> SessionStats? {
        if let data = UserDefaults.standard.data(forKey: K.lifetimeStats),
           let decoded = try? JSONDecoder().decode(SessionStats.self, from: data) {
            return decoded
        }
        // Migration: prior versions persisted a single stats blob under `stats`. Treat it as lifetime.
        if let data = UserDefaults.standard.data(forKey: K.legacyStats),
           let decoded = try? JSONDecoder().decode(SessionStats.self, from: data) {
            return decoded
        }
        return nil
    }
}

/// What we tell the player after they acted on a hand: were they right?
struct ActionFeedback: Hashable {
    let chosen: PlayerAction
    let optimal: PlayerAction
    /// The basic-strategy chart's call for this situation, populated only when it differs from the
    /// composition-exact optimal — i.e. a count-driven deviation worth flagging to the player.
    let chartAction: PlayerAction?
    let isCorrect: Bool
    let chosenEV: Double?     // expected value of the action the player picked
    let optimalEV: Double?    // expected value of the optimal action
    let handTotal: Int
    let isSoft: Bool
    let dealerUpcardLabel: String
    let trueCountAtDecision: Double
}

/// One of the actions the player can attempt on Hard difficulty. Used as the payload for
/// `SessionStore.pendingHardAction` so the count-quiz overlay knows what to re-run once the player
/// answers correctly.
enum HardAction: Hashable {
    case deal
    case hit
    case stand
    case double
    case split
    case surrender
    case takeInsurance
    case declineInsurance
}

/// Result of comparing a Hard-mode count guess to the actual running count.
enum HardCountResult: Hashable {
    case correct
    /// The actual count is higher than the player's guess — they need to go up.
    case higher
    /// The actual count is lower than the player's guess — they need to go down.
    case lower
}

/// Feedback for the insurance decision specifically. Insurance pays 2:1 if the dealer's hole card is a
/// ten-valued card; the optimal play is to take it whenever the chance of a ten in the unseen cards is
/// strictly above one-third.
struct InsuranceFeedback: Hashable {
    let took: Bool
    let optimalTook: Bool
    let isCorrect: Bool
    let probabilityOfTen: Double
    let trueCountAtDecision: Double
}

