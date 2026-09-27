import XCTest
@testable import TagLookupCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class ClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func client() -> PlayFabClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return PlayFabClient(session: URLSession(configuration: config))
    }

    func testLookupUsesFixedHostAndOnlyClientCredentials() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host?.lowercased(), "63fdd.playfabapi.com")
            XCTAssertEqual(request.url?.path, "/Client/GetAccountInfo")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Authorization"), "TEST-SESSION")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-SecretKey"))
            return (200, Data(#"{"code":200,"data":{"AccountInfo":{"PlayFabId":"AB12","TitleInfo":{"DisplayName":"Test player"},"SteamInfo":{}}}}"#.utf8))
        }
        let record = try await client().account(ticket: "TEST-SESSION", query: LookupQuery(kind: .playerID, text: "ab12"))
        XCTAssertEqual(record.id, "AB12")
        XCTAssertEqual(record.displayName, "Test player")
        XCTAssertEqual(record.platforms, ["Steam"])
    }

    func testLookupBodyIsExactNotPartialSearch() throws {
        let query = try LookupQuery(kind: .displayName, text: " Name With Spaces ")
        XCTAssertEqual(query.body, ["TitleDisplayName": "Name With Spaces"])
        let request = try PlayFabClient.request(endpoint: .account, ticket: "TEST-SESSION", body: query.body)
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body, ["TitleDisplayName": "Name With Spaces"])
        XCTAssertEqual(try LookupQuery(kind: .playerID, text: " ab12 ").body, ["PlayFabId": "AB12"])
    }

    func testMissingPlatformIsNotGuessedAsQuest() throws {
        let account = try JSONDecoder().decode(AccountInfo.self, from: Data(#"{"PlayFabId":"123ABC","CustomIdInfo":{"CustomId":"OCULUSanything"},"TitleInfo":{"Origination":"CustomId"}}"#.utf8))
        let record = try account.record()
        XCTAssertTrue(record.platforms.isEmpty)
        XCTAssertEqual(record.platformSummary, "Not exposed")
        XCTAssertEqual(record.displayName, "Unnamed player")
    }

    func testAndroidIsNotAssumedToBeAHeadset() throws {
        let account = try JSONDecoder().decode(AccountInfo.self, from: Data(#"{"PlayFabId":"123ABC","AndroidDeviceInfo":{},"SteamInfo":{}}"#.utf8))
        XCTAssertEqual(try account.record().platforms, ["Steam", "Android"])
    }

    func testSavedRecordDoesNotContainOtherAccountFields() throws {
        let account = try JSONDecoder().decode(AccountInfo.self, from: Data(#"{"PlayFabId":"123ABC","PrivateInfo":{"Email":"fixture@example.invalid"},"SteamInfo":{"SteamId":"private-id"},"CustomIdInfo":{"CustomId":"private-custom"}}"#.utf8))
        let record = try account.record()
        let encoded = String(decoding: try JSONEncoder().encode(record), as: UTF8.self)
        XCTAssertFalse(encoded.contains("private-id"))
        XCTAssertFalse(encoded.contains("private-custom"))
        XCTAssertFalse(encoded.contains("example.invalid"))
        XCTAssertEqual(try JSONDecoder().decode(PlayerRecord.self, from: JSONEncoder().encode(record)), record)
    }

    func testInventoryRequestCannotTargetSomeoneElse() throws {
        let request = try PlayFabClient.request(endpoint: .inventory, ticket: "TEST-SESSION", body: [:])
        XCTAssertEqual(request.url?.path, "/Client/GetUserInventory")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body, [:])
        XCTAssertEqual(ClientEndpoint.allCases.map(\.rawValue).sorted(), ["GetAccountInfo", "GetUserInventory"])
    }

    func testInventoryGroupsInstancesWithoutAssumingTheyAreEquipped() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/Client/GetUserInventory")
            return (200, Data(#"{"code":200,"data":{"Inventory":[{"ItemId":"ITEM_A","DisplayName":"Hat","CatalogVersion":"v1"},{"ItemId":"ITEM_A","DisplayName":"Hat","CatalogVersion":"v1"},{"ItemId":"ITEM_B","CatalogVersion":"v1"},{"ItemId":"ITEM_A","DisplayName":"Hat","CatalogVersion":"v2"}]}}"#.utf8))
        }
        let items = try await client().ownInventory(ticket: "TEST-SESSION")
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.first { $0.id == "v1:ITEM_A" }?.quantity, 2)
        XCTAssertEqual(items.first { $0.itemID == "ITEM_B" }?.name, "ITEM_B")
    }

    func testExpiredSessionReturnsActionableError() async throws {
        MockURLProtocol.handler = { _ in
            (400, Data(#"{"code":400,"error":"InvalidSessionTicket","errorMessage":"raw-secret-should-not-appear"}"#.utf8))
        }
        do {
            _ = try await client().account(ticket: "TEST-SESSION")
            XCTFail("Expected expired session")
        } catch {
            XCTAssertEqual(error as? LookupFailure, .expired)
            XCTAssertFalse(error.localizedDescription.contains("raw-secret"))
        }
    }

    func testMalformedResponseIsNotAnEmptySuccess() async throws {
        MockURLProtocol.handler = { _ in (200, Data(#"{"code":200,"data":{}}"#.utf8)) }
        do {
            _ = try await client().account(ticket: "TEST-SESSION")
            XCTFail("Expected invalid response")
        } catch { XCTAssertEqual(error as? LookupFailure, .invalidResponse) }
    }

    func testMismatchedPlayerIDIsRejected() async throws {
        MockURLProtocol.handler = { _ in (200, Data(#"{"code":200,"data":{"AccountInfo":{"PlayFabId":"BBBB"}}}"#.utf8)) }
        do {
            _ = try await client().account(ticket: "TEST-SESSION", query: LookupQuery(kind: .playerID, text: "AAAA"))
            XCTFail("Expected mismatch rejection")
        } catch { XCTAssertEqual(error as? LookupFailure, .invalidResponse) }
    }

    func testInvalidIDsAndHeaderInjectionAreRejected() throws {
        for value in ["", "user-name", "https://example.invalid", "AB\n12", String(repeating: "A", count: 65)] {
            XCTAssertThrowsError(try LookupQuery(kind: .playerID, text: value))
        }
        for value in ["", "abc def", "abc\r\nX-Evil: yes", String(repeating: "A", count: 16_385)] {
            XCTAssertThrowsError(try PlayFabClient.cleanTicket(value))
        }
    }

    func testPermissionAndRateLimitErrorsRemainDistinct() {
        XCTAssertEqual(PlayFabClient.failure(status: 403, code: "APIAccessDenied", retryAfter: nil), .blocked)
        XCTAssertEqual(PlayFabClient.failure(status: 400, code: "AccountNotFound", retryAfter: nil), .notFound)
        XCTAssertEqual(PlayFabClient.failure(status: 429, code: nil, retryAfter: "30"), .rateLimited(30))
        XCTAssertEqual(PlayFabClient.failure(status: 400, code: "unsafe secret here", retryAfter: nil), .service("RequestRejected"))
    }
}
