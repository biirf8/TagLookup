import Foundation

enum LookupKind: String, CaseIterable, Identifiable {
    case playerID = "Player ID"
    case displayName = "Exact name"
    var id: String { rawValue }
}

struct LookupQuery: Equatable {
    let kind: LookupKind
    let value: String

    init(kind: LookupKind, text: String) throws {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LookupFailure.input("Enter a player ID or exact account name.") }
        switch kind {
        case .playerID:
            guard clean.count <= 64, clean.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil else {
                throw LookupFailure.input("Use a PlayFab player ID containing only letters A-F and numbers.")
            }
        case .displayName:
            guard clean.count <= 128, clean.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw LookupFailure.input("Enter an exact account name with 128 characters or fewer.")
            }
        }
        self.kind = kind
        self.value = kind == .playerID ? clean.uppercased() : clean
    }

    var body: [String: String] {
        [kind == .playerID ? "PlayFabId" : "TitleDisplayName": value]
    }
}

struct PlayerRecord: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let platforms: [String]
    let fetchedAt: Date

    var platformSummary: String {
        platforms.isEmpty ? "Not exposed" : platforms.joined(separator: ", ")
    }
}

struct OwnedItem: Identifiable, Equatable {
    let id: String
    let itemID: String
    let name: String
    let itemClass: String?
    let quantity: Int
}

struct AccountResult: Decodable {
    let AccountInfo: AccountInfo
}

// Only decode fields used by the UI. Email, locations, external user IDs,
// device IDs, custom IDs, and other account fields are never persisted.
struct AccountInfo: Decodable {
    struct Title: Decodable { let DisplayName: String? }
    struct LinkedAccount: Decodable {}

    let PlayFabId: String
    let TitleInfo: Title?
    let SteamInfo: LinkedAccount?
    let PsnInfo: LinkedAccount?
    let AndroidDeviceInfo: LinkedAccount?
    let IosDeviceInfo: LinkedAccount?
    let XboxInfo: LinkedAccount?

    func record(at date: Date = Date()) throws -> PlayerRecord {
        let validated = try LookupQuery(kind: .playerID, text: PlayFabId)
        var platforms: [String] = []
        if SteamInfo != nil { platforms.append("Steam") }
        if PsnInfo != nil { platforms.append("PlayStation") }
        if AndroidDeviceInfo != nil { platforms.append("Android") }
        if IosDeviceInfo != nil { platforms.append("iOS") }
        if XboxInfo != nil { platforms.append("Xbox") }
        let name = TitleInfo?.DisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlayerRecord(
            id: validated.value,
            displayName: name.flatMap { $0.isEmpty ? nil : $0 } ?? "Unnamed player",
            platforms: platforms,
            fetchedAt: date
        )
    }
}

struct InventoryResult: Decodable {
    let Inventory: [InventoryEntry]?

    func items() -> [OwnedItem] {
        let groups = Dictionary(grouping: Inventory ?? []) {
            "\($0.CatalogVersion ?? ""):\($0.ItemId)"
        }
        return groups.map { key, entries in
            let first = entries[0]
            let name = entries.compactMap(\.DisplayName).first { !$0.isEmpty } ?? first.ItemId
            return OwnedItem(id: key, itemID: first.ItemId, name: name,
                             itemClass: first.ItemClass, quantity: entries.count)
        }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }
}

struct InventoryEntry: Decodable {
    let ItemId: String
    let DisplayName: String?
    let ItemClass: String?
    let CatalogVersion: String?
}

enum LookupFailure: LocalizedError, Equatable {
    case input(String)
    case expired
    case blocked
    case notFound
    case rateLimited(Int?)
    case network
    case invalidResponse
    case service(String)

    var errorDescription: String? {
        switch self {
        case .input(let message): return message
        case .expired: return "Your session expired or was rejected. Add a current client session in Session."
        case .blocked: return "The game blocks this client request. This app respects the server's access settings."
        case .notFound: return "No matching account was returned. Try the exact PlayFab ID. In-game nicknames might differ from account names, and duplicate account names prevent name lookup."
        case .rateLimited(let seconds):
            if let seconds { return "Too many requests. Try again after \(seconds) seconds." }
            return "Too many requests. Wait before trying again."
        case .network: return "The request failed. Check your connection and try again."
        case .invalidResponse: return "The service returned an unexpected response. No player details were assumed."
        case .service(let code): return "The service rejected this request (\(code))."
        }
    }
}
