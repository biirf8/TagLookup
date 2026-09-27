import SwiftUI

struct SessionScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var ticket = ""
    @State private var remember = true
    @FocusState private var ticketFocused: Bool

    var body: some View {
        Page {
            Text(model.connected ? "You're connected." : "Connect your account.")
                .font(.largeTitle.bold())
            Text("Gorilla Tag production · 63FDD")
                .font(.subheadline).foregroundStyle(.secondary)
            if let player = model.account {
                Card {
                    Label(player.displayName, systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.accent)
                    Text(player.id).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Text("Connected session verified with the service.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                Text("Client session ticket").font(.headline)
                Text("Use a current ticket from your own authorized Gorilla Tag session. A player ID, server app ID, or title ID is not a session ticket.")
                    .font(.subheadline).foregroundStyle(.secondary)
                SecureField("Paste client session ticket", text: $ticket)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.asciiCapable).submitLabel(.go)
                    .focused($ticketFocused)
                    .padding(14).background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(model.isConnecting)
                    .onSubmit { connect() }
                Toggle("Remember on this iPhone", isOn: $remember)
                    .disabled(model.isConnecting)
                ActionButton(title: model.isConnecting ? "Verifying session" : "Connect",
                             symbol: "key.fill", busy: model.isConnecting) { connect() }
                    .disabled(ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Disconnect and remove saved session", role: .destructive) {
                    ticket = ""
                    model.disconnect()
                }.frame(minHeight: 44)
            }
            if let message = model.sessionMessage { Notice(message: message, symbol: "exclamationmark.circle") }
            Card {
                Label("No title secret key", systemImage: "lock.shield").font(.headline)
                Text("The app accepts client sessions only. Saved sessions use this device's Keychain. Sessions are sent directly to PlayFab and are never included in saved player records.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Text("No session ticket?").font(.headline)
                Text("This app does not provide a Gorilla Tag sign-in flow. The supplied server IDs do not grant player access. Without a valid client ticket, live lookup and inventory stay unavailable.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Unofficial companion. No affiliation with Another Axiom. Version 1.0.0.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { ticket = "" }
    }

    private func connect() {
        ticketFocused = false
        let raw = ticket
        ticket = ""
        Task { await model.connect(raw: raw, remember: remember) }
    }
}
