import SwiftUI
import UIKit

struct LookupScreen: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        Page {
            HStack {
                Label("GORILLA TAG", systemImage: "viewfinder")
                    .font(.caption.weight(.bold)).tracking(1.5)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label(model.connected ? "Connected" : "Offline",
                      systemImage: model.connected ? "checkmark.circle.fill" : "circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Find a player.").font(.largeTitle.bold())
            Text("Look up an exact account and keep the IDs you need.")
                .foregroundStyle(.secondary)

            if !model.connected {
                Card {
                    Notice(message: "Connect your client session before searching.")
                    Button("Open Session") { model.tab = 3 }.fontWeight(.semibold)
                }
            }

            Card {
                Picker("Search using", selection: $model.kind) {
                    ForEach(LookupKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }.pickerStyle(.segmented).disabled(model.isSearching)
                TextField(model.kind == .playerID ? "PlayFab player ID" : "Exact account display name", text: $model.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($inputFocused)
                    .padding(14)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(model.isSearching)
                    .onSubmit { search() }
                if model.kind == .displayName {
                    Notice(message: "Exact account names only. Nicknames with duplicate names are not searchable.")
                }
                ActionButton(title: model.isSearching ? "Searching" : "Find player",
                             symbol: "magnifyingglass", busy: model.isSearching) { search() }
                    .disabled(!model.connected || model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = model.lookupMessage { Notice(message: message, symbol: "exclamationmark.circle") }
            if let result = model.result { PlayerCard(player: result) }
            if let message = model.saveMessage { Notice(message: message) }
            if model.result == nil && model.lookupMessage == nil {
                EmptyCard(symbol: "person.crop.square", title: "An ID is the best starting point",
                          detail: "Player details appear here after a successful lookup. A complete player directory is unavailable.")
            }
        }
        .navigationTitle("Tag Lookup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func search() {
        inputFocused = false
        Task { await model.lookup() }
    }
}

struct PlayerCard: View {
    let player: PlayerRecord
    @EnvironmentObject var model: AppModel
    @State private var copied = false

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "person.fill")
                    .font(.title).foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.displayName).font(.title2.bold()).textSelection(.enabled)
                    Text("ACCOUNT RESULT").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { model.toggleSave(player) } label: {
                    Image(systemName: model.isSaved(player) ? "bookmark.fill" : "bookmark")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(model.isSaved(player) ? "Remove saved player" : "Save player")
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("PLAYER ID").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(alignment: .top) {
                    Text(player.id).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button {
                        UIPasteboard.general.setItems([["public.utf8-plain-text": player.id]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel(copied ? "Player ID copied" : "Copy player ID")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("LINKED PLATFORMS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(player.platformSummary).font(.headline)
                Text("Linked accounts do not identify the headset or platform currently in use. Hidden platform data stays unknown.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text("Fetched \(player.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Text("Saved results show the last fetched details. Search again to refresh.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: player.id) { _ in copied = false }
    }
}

struct SavedScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var filter = ""
    @State private var confirmClear = false

    private var filtered: [PlayerRecord] {
        model.saved.filter { filter.isEmpty || $0.id.localizedCaseInsensitiveContains(filter) || $0.displayName.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        Group {
            if model.saved.isEmpty {
                Page {
                    EmptyCard(symbol: "bookmark", title: "Your saved players",
                              detail: "Tap the bookmark on a lookup result. Saved details stay on this device and work offline.")
                }
            } else {
                List {
                    Section {
                        ForEach(filtered) { player in
                            Button { model.openSaved(player) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(player.displayName).font(.headline).foregroundStyle(.primary)
                                    Text(player.id).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                    Text(player.platformSummary).font(.caption).foregroundStyle(Theme.accent)
                                }.padding(.vertical, 6)
                            }
                            .disabled(model.isSearching)
                            .swipeActions {
                                Button("Remove", role: .destructive) { model.toggleSave(player) }
                            }
                            .listRowBackground(Theme.card)
                        }
                    } footer: {
                        Text("\(model.saved.count) of 100 saved. Swipe a row to remove.")
                    }
                    if filtered.isEmpty { Text("No saved players match your search.").foregroundStyle(.secondary) }
                }
                .searchable(text: $filter, prompt: "Search saved names or IDs")
                .scrollContentBackground(.hidden)
                .background(Theme.background)
            }
        }
        .navigationTitle("Saved")
        .toolbar {
            if !model.saved.isEmpty { Button("Clear", role: .destructive) { confirmClear = true } }
        }
        .confirmationDialog("Remove all saved players from this device?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Remove all", role: .destructive) { model.clearSaved() }
        }
    }
}
