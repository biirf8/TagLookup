import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ClientEndpoint: String, CaseIterable {
    case account = "GetAccountInfo"
    case inventory = "GetUserInventory"
}

struct APIEnvelope<Value: Decodable>: Decodable {
    let code: Int?
    let data: Value?
    let error: String?
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class PlayFabClient {
    static let titleID = "63FDD"
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config, delegate: RejectRedirects(), delegateQueue: nil)
        }
    }

    static func cleanTicket(_ raw: String) throws -> String {
        let ticket = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ticket.isEmpty, ticket.utf8.count <= 16_384,
              ticket.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }) else {
            throw LookupFailure.input("Paste one client session ticket without spaces or line breaks.")
        }
        return ticket
    }

    static func request(endpoint: ClientEndpoint, ticket: String, body: [String: String]) throws -> URLRequest {
        let clean = try cleanTicket(ticket)
        // Fixed production host and fixed read-only Client endpoint allowlist.
        let url = URL(string: "https://63FDD.playfabapi.com/Client/\(endpoint.rawValue)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clean, forHTTPHeaderField: "X-Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func account(ticket: String, query: LookupQuery? = nil) async throws -> PlayerRecord {
        let result: AccountResult = try await call(.account, ticket: ticket, body: query?.body ?? [:])
        let record = try result.AccountInfo.record()
        if let query, query.kind == .playerID, record.id != query.value {
            throw LookupFailure.invalidResponse
        }
        return record
    }

    // No target-player parameter exists. This endpoint only reads the ticket owner's inventory.
    func ownInventory(ticket: String) async throws -> [OwnedItem] {
        let result: InventoryResult = try await call(.inventory, ticket: ticket, body: [:])
        return result.items()
    }

    private func call<Value: Decodable>(_ endpoint: ClientEndpoint, ticket: String,
                                       body: [String: String]) async throws -> Value {
        let request = try Self.request(endpoint: endpoint, ticket: ticket, body: body)
        let bytes: Data
        let response: URLResponse
        do {
            (bytes, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw LookupFailure.network
        }
        guard let http = response as? HTTPURLResponse, bytes.count <= 8_388_608 else {
            throw LookupFailure.invalidResponse
        }
        let envelope = try? JSONDecoder().decode(APIEnvelope<Value>.self, from: bytes)
        if !(200...299).contains(http.statusCode) || envelope?.error != nil {
            throw Self.failure(status: http.statusCode, code: envelope?.error,
                               retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        }
        guard let envelope, envelope.code == 200, let value = envelope.data else {
            throw LookupFailure.invalidResponse
        }
        return value
    }

    static func failure(status: Int, code: String?, retryAfter: String?) -> LookupFailure {
        let value = code ?? "HTTP\(status)"
        if status == 401 || ["InvalidSessionTicket", "SessionTicketExpired", "AuthTokenDoesNotExist", "AuthTokenExpired"].contains(value) {
            return .expired
        }
        if status == 429 || ["APIRequestLimitExceeded", "ClientAPIRateLimitExceeded", "APIRateLimitExceeded"].contains(value) {
            return .rateLimited(retryAfter.flatMap(Int.init).map { max(1, $0) })
        }
        if ["AccountNotFound", "UserNotFound", "PlayerNotInGame"].contains(value) { return .notFound }
        if status == 403 || ["NotAuthorized", "APIRequestsDisabledForTitle", "APINotEnabledForGameClient", "APIAccessDenied"].contains(value) {
            return .blocked
        }
        // Never show raw errorMessage or response bodies, which might echo credentials.
        let safe = value.range(of: "^[A-Za-z0-9_]{1,64}$", options: .regularExpression) != nil
        return .service(safe ? value : "RequestRejected")
    }
}
