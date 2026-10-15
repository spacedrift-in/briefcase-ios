import Foundation
import XCTest
@testable import SpacedriftCore

final class ApprovalAPIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handlers.set(nil)
        super.tearDown()
    }

    func testLivenessDecodesHealthResponseWithoutAuthentication() async throws {
        StubURLProtocol.handlers.set { request in
            XCTAssertEqual(request.url?.path, "/health/live")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return Self.response(status: 200, body: #"{"status":"alive"}"#)
        }

        let response = try await Self.client().liveness()
        XCTAssertEqual(response, APIHealthResponse(status: "alive"))
    }

    func testProjectsDecodesTypedResponseWithConfiguredTokenProvider() async throws {
        let projectID = UUID()
        StubURLProtocol.handlers.set { request in
            XCTAssertEqual(request.url?.path, "/api/v1/projects")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            let body = "[{\"id\":\"\(projectID.uuidString)\",\"name\":\"Northstar\",\"summary\":\"Brand system\"}]"
            return Self.response(status: 200, body: body)
        }

        let projects = try await Self.client(tokenProvider: TestTokenProvider()).projects()
        XCTAssertEqual(projects, [ProjectSummary(id: projectID, name: "Northstar", summary: "Brand system")])
    }

    func testMissingAuthenticationDoesNotSendProtectedRequest() async {
        StubURLProtocol.handlers.set { _ in
            XCTFail("Protected endpoint should not be contacted without a token provider")
            return Self.response(status: 200, body: "[]")
        }

        do {
            _ = try await Self.client().projects()
            XCTFail("Expected missing authentication configuration")
        } catch let error as ApprovalAPIError {
            XCTAssertEqual(error, .authenticationNotConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNonSuccessResponseMapsToServiceUnavailable() async {
        StubURLProtocol.handlers.set { _ in Self.response(status: 503, body: #"{"detail":"database_unavailable"}"#) }

        do {
            _ = try await Self.client().readiness()
            XCTFail("Expected service unavailable")
        } catch let error as ApprovalAPIError {
            XCTAssertEqual(error, .serviceUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedJSONIsRejected() async {
        StubURLProtocol.handlers.set { _ in Self.response(status: 200, body: #"{"status":42}"#) }

        do {
            _ = try await Self.client().liveness()
            XCTFail("Expected invalid response")
        } catch let error as ApprovalAPIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConnectionFailureIsReported() async {
        StubURLProtocol.handlers.set { _ in throw URLError(.cannotConnectToHost) }

        do {
            _ = try await Self.client().liveness()
            XCTFail("Expected network unavailable")
        } catch let error as ApprovalAPIError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConfigurationRejectsMissingOrUnsafeBaseURL() {
        XCTAssertThrowsError(try APIConfiguration(baseURLString: ""))
        XCTAssertThrowsError(try APIConfiguration(baseURLString: "file:///tmp/api"))
        XCTAssertThrowsError(try APIConfiguration(baseURLString: "https://user:password@example.com"))
        XCTAssertNoThrow(try APIConfiguration(baseURLString: "https://api.example.test"))
    }

    private static func client(tokenProvider: (any AccessTokenProviding)? = nil) -> ApprovalAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let apiConfiguration = try! APIConfiguration(baseURLString: "https://api.example.test")
        return ApprovalAPIClient(configuration: apiConfiguration, tokenProvider: tokenProvider, session: session)
    }

    private static func response(status: Int, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.test")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }
}

private struct TestTokenProvider: AccessTokenProviding {
    func validAccessToken() async throws -> String { "test-access-token" }
}

private final class StubURLProtocol: URLProtocol {
    static let handlers = StubURLProtocolHandlerBox()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlers.get() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class StubURLProtocolHandlerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    func set(_ handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func get() -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }
}
