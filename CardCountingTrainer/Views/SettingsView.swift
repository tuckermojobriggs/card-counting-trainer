import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var showingProfileEditor = false
    @State private var editingProfile: DealerRules? = nil
    @State private var dealerRulesExpanded = false

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            Form {
                Section {
                    DisclosureGroup("Dealer Rules", isExpanded: $dealerRulesExpanded) {
                        Stepper(value: $session.rules.deckCount, in: 1...8) {
                            HStack {
                                Text("Decks")
                                Spacer()
                                Text("\(session.rules.deckCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Text("Penetration")
                            Spacer()
                            Text("\(Int(session.rules.penetration * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $session.rules.penetration, in: 0.5...0.95, step: 0.05)

                        Toggle("Dealer hits soft 17", isOn: $session.rules.dealerHitsSoft17)
                        Toggle("Double after split", isOn: $session.rules.doubleAfterSplit)
                        Toggle("Double on any two cards", isOn: $session.rules.doubleOnAnyTwo)
                        Toggle("Re-split allowed", isOn: $session.rules.resplitAllowed)
                        Toggle("Re-split aces", isOn: $session.rules.resplitAces)
                        Toggle("Hit split aces", isOn: $session.rules.hitSplitAces)
                        Toggle("Dealer peeks for blackjack on Ace or Ten", isOn: $session.rules.dealerPeeksOnTenAce)

                        Picker("Surrender", selection: $session.rules.surrender) {
                            ForEach(SurrenderRule.allCases) { s in
                                Text(s.displayName).tag(s)
                            }
                        }

                        Picker("Blackjack pays", selection: $session.rules.blackjackPayout) {
                            ForEach(BlackjackPayout.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }

                        Stepper(value: $session.rules.maxSplitHands, in: 2...4) {
                            HStack {
                                Text("Max split hands")
                                Spacer()
                                Text("\(session.rules.maxSplitHands)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Dealer Profiles") {
                    if session.savedProfiles.isEmpty {
                        Text("No saved profiles")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.savedProfiles) { p in
                        Button {
                            session.rules = p
                            session.resetEngineForRulesChange()
                        } label: {
                            HStack {
                                Text(p.name)
                                Spacer()
                                Text(profileSummary(p))
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { idx in
                        session.savedProfiles.remove(atOffsets: idx)
                    }
                    Button {
                        var snapshot = session.rules
                        snapshot.id = UUID()
                        snapshot.name = "Profile \(session.savedProfiles.count + 1)"
                        editingProfile = snapshot
                        showingProfileEditor = true
                    } label: {
                        Label("Save current as profile", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    Picker("Difficulty", selection: $session.difficulty) {
                        ForEach(Difficulty.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    Text(session.difficulty.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Difficulty")
                } footer: {
                    Text("Difficulty controls which helpers are visible while you play. Switching to a self-tracking level snaps your tracked count to the actual count so you start in sync.")
                }

                Section {
                    Picker("System", selection: $session.countingSystemKind) {
                        ForEach(CountingSystemKind.allCases) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    Text(session.countingSystemKind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Show correct action feedback", isOn: $session.showCorrectAction)
                } header: {
                    Text("Counting System")
                } footer: {
                    Text("The system controls how cards are tagged and how the running and true counts are calculated. Changing systems mid-shoe reshuffles the deck so the new tags start from a clean slate.")
                }

                Section {
                    Toggle("Fast dealing", isOn: $session.fastDealing)
                } header: {
                    Text("Gameplay")
                } footer: {
                    Text("By default each card slides into place with a brief animation, the way a dealer flips them at a real table. Turn this on to skip the animation and have cards appear instantly.")
                }


            }
            .navigationTitle("Settings")
            .sheet(item: $editingProfile) { profile in
                ProfileEditorSheet(profile: profile) { saved in
                    session.savedProfiles.append(saved)
                }
            }
        }
    }

    private func profileSummary(_ p: DealerRules) -> String {
        let soft17 = p.dealerHitsSoft17 ? "Hits soft 17" : "Stands on soft 17"
        let das = p.doubleAfterSplit ? "Double after split" : "No double after split"
        let surr: String = {
            switch p.surrender {
            case .none:  return "No surrender"
            case .late:  return "Late surrender"
            case .early: return "Early surrender"
            }
        }()
        let decks = p.deckCount == 1 ? "1 deck" : "\(p.deckCount) decks"
        return "\(decks) · \(soft17) · \(das) · \(surr) · Blackjack pays \(p.blackjackPayout.rawValue)"
    }
}

struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: DealerRules
    var onSave: (DealerRules) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Profile name", text: $profile.name)
                }
                Section("Rules summary (read-only here — edit on Settings before saving)") {
                    LabeledContent("Decks", value: "\(profile.deckCount)")
                    LabeledContent("Penetration", value: "\(Int(profile.penetration * 100))%")
                    LabeledContent("Soft 17", value: profile.dealerHitsSoft17 ? "Hits" : "Stands")
                    LabeledContent("Double after split", value: profile.doubleAfterSplit ? "Yes" : "No")
                    LabeledContent("Surrender", value: profile.surrender.displayName)
                    LabeledContent("Blackjack payout", value: profile.blackjackPayout.rawValue)
                }
            }
            .navigationTitle("Save Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                }
            }
        }
    }
}
