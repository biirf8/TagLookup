import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var tab = 0
    @Published var kind: LookupKind = .playerID
    @Published var query = ""
    @Published private(set) var account: PlayerRecord?
    @Published private(set) var result: PlayerRecord?
    @Published private(set) var saved: [PlayerRecord] = []
    @Published private(set) var items: [OwnedItem] = []
    @Published private(set) var inventoryDate: Date?
    @Published private(set) var isConnecting = false
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingItems = false
    @Published private(set) var sessionMessage: String?
    @Published private(set) var lookupMessage: String?
    @Published private(set) var inventoryMessage: String?
    @Published private(set) var saveMessage: String?

    private let client = PlayFabClient()
    private var ticket: String?
    private var generation = 0
    private var restored = false
    private let savedKey = "savedPlayers.v1.63FDD"

    var connected: Bool { account != nil && ticket != nil }

    init() {
        if let bytes = UserDefaults.standard.data(forKey: savedKey),
           let records = try? JSONDecoder().decode([PlayerRecord].self, from: bytes) {
            var seen = Set<String>()
            saved = Array(records.filter { seen.insert($0.id).inserted }.prefix(100))
        }
    }

    func restoreSession() async {
        guard !restored else { return }
        restored = true
        do {
            if let ticket = try KeychainVault.read() { await connect(raw: ticket, remember: true) }
        } catch { sessionMessage = error.localizedDescription }
    }

    @discardableResult
    func connect(raw: String, remember: Bool) async -> Bool {
        guard !isConnecting else { return false }
        let clean: String
        do { clean = try PlayFabClient.cleanTicket(raw) }
        catch { sessionMessage = error.localizedDescription; return false }
        generation += 1
        let current = generation
        clearSessionMemory()
        sessionMessage = nil
        isConnecting = true
        defer { if current == generation { isConnecting = false } }
        do {
            let player = try await client.account(ticket: clean)
            guard current == generation, !Task.isCancelled else { return false }
            ticket = clean
            account = player
            do {
                if remember { try KeychainVault.write(clean) }
                else { try KeychainVault.remove() }
            } catch {
                sessionMessage = "Connected for this launch. Session storage failed. Use Disconnect to retry clearing any saved session."
            }
            return true
        } catch {
            guard current == generation else { return false }
            sessionMessage = error is CancellationError ? "Connection cancelled." : error.localizedDescription
            // Retain a previously saved session through transient network failures.
            // Rejected/expired credentials are removed.
            if (error as? LookupFailure) == .expired {
                do { try KeychainVault.remove() }
                catch { sessionMessage = "Session rejected. Saved-session removal failed. Unlock your iPhone and tap Disconnect." }
            }
            return false
        }
    }

    func disconnect() {
        generation += 1
        clearSessionMemory()
        sessionMessage = nil
        do { try KeychainVault.remove() }
        catch { sessionMessage = "Disconnected for this launch. Saved-session removal failed. Unlock your iPhone and tap Disconnect again." }
    }

    private func clearSessionMemory() {
        ticket = nil
        account = nil
        result = nil
        items = []
        inventoryDate = nil
        lookupMessage = nil
        inventoryMessage = nil
        isConnecting = false
        isSearching = false
        isLoadingItems = false
    }

    func lookup() async {
        guard !isSearching, let ticket, connected else {
            if !connected { lookupMessage = "Add your client session in the Session tab first." }
            return
        }
        let lookup: LookupQuery
        do { lookup = try LookupQuery(kind: kind, text: query) }
        catch { lookupMessage = error.localizedDescription; return }
        let current = generation
        isSearching = true
        result = nil
        lookupMessage = nil
        saveMessage = nil
        defer { if current == generation { isSearching = false } }
        do {
            let player = try await client.account(ticket: ticket, query: lookup)
            guard current == generation, !Task.isCancelled else { return }
            result = player
            if let index = saved.firstIndex(where: { $0.id == player.id }) {
                saved[index] = player
                persistSaved()
            }
        } catch {
            guard current == generation else { return }
            invalidateExpired(error)
            lookupMessage = error is CancellationError ? "Search cancelled." : error.localizedDescription
        }
    }

    func loadItems() async {
        guard !isLoadingItems, let ticket, connected else {
            if !connected { inventoryMessage = "Add your client session in the Session tab first." }
            return
        }
        let current = generation
        isLoadingItems = true
        inventoryMessage = nil
        defer { if current == generation { isLoadingItems = false } }
        do {
            let loaded = try await client.ownInventory(ticket: ticket)
            guard current == generation, !Task.isCancelled else { return }
            items = loaded
            inventoryDate = Date()
        } catch {
            guard current == generation else { return }
            invalidateExpired(error)
            inventoryMessage = error is CancellationError ? "Refresh cancelled." : error.localizedDescription
        }
    }

    private func invalidateExpired(_ error: Error) {
        guard (error as? LookupFailure) == .expired else { return }
        disconnect()
        if sessionMessage == nil { sessionMessage = LookupFailure.expired.localizedDescription }
    }

    func toggleSave(_ player: PlayerRecord) {
        saveMessage = nil
        if let index = saved.firstIndex(where: { $0.id == player.id }) { saved.remove(at: index) }
        else {
            guard saved.count < 100 else { saveMessage = "Your saved list is full. Remove a player before adding another."; return }
            saved.insert(player, at: 0)
        }
        persistSaved()
    }

    func removeSaved(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) { saved.remove(at: index) }
        persistSaved()
    }

    func clearSaved() { saved = []; persistSaved() }
    func isSaved(_ player: PlayerRecord) -> Bool { saved.contains { $0.id == player.id } }

    func openSaved(_ player: PlayerRecord) {
        guard !isSearching else { return }
        kind = .playerID
        query = player.id
        result = player
        lookupMessage = nil
        saveMessage = nil
        tab = 0
    }

    private func persistSaved() {
        if let bytes = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(bytes, forKey: savedKey) }
    }
}
