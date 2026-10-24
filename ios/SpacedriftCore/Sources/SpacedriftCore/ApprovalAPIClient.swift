import Foundation

public protocol AccessTokenProviding: Sendable {
    func validAccessToken() async throws -> String
}

public struct APIConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let timeoutInterval: TimeInterval

    public init(baseURLString: String, timeoutInterval: TimeInterval = 8) throws {
        guard let components = URLComponents(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              timeoutInterval.isFinite, timeoutInterval > 0,
              let url = components.url else {
            throw APIConfigurationError.invalidBaseURL
        }
        self.baseURL = url
        self.timeoutInterval = timeoutInterval
    }
}

public enum APIConfigurationError: Error, Equatable, Sendable {
    case invalidBaseURL
}

public enum ApprovalAPIError: Error, Equatable, Sendable, LocalizedError {
    case authenticationNotConfigured
    case sessionExpired
    case forbidden
    case notFound
    case conflict
    case serviceUnavailable
    case invalidResponse
    case requestFailed(statusCode: Int)
    case outcomeUncertain
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .authenticationNotConfigured: "Sign-in is not configured for this app build."
        case .sessionExpired: "Your sign-in session is unavailable or expired."
        case .forbidden: "Your account is not allowed to access this item."
        case .notFound: "The requested item was not found or is not available to this account."
        case .conflict: "The server reports that this item has changed. Refresh and try again."
        case .serviceUnavailable: "The API or one of its required services is unavailable."
        case .invalidResponse: "The API returned a response this app could not read."
        case let .requestFailed(statusCode): "The API request failed (HTTP \(statusCode))."
        case .outcomeUncertain: "The result could not be confirmed. Check server state before retrying."
        case .networkUnavailable: "The API could not be reached. Check the server address and network, then retry."
        }
    }
}

public struct ApprovalAPIClient: Sendable {
    private let baseURL: URL
    private let tokenProvider: (any AccessTokenProviding)?
    private let session: URLSession

    public init(configuration: APIConfiguration, tokenProvider: (any AccessTokenProviding)? = nil, session: URLSession? = nil) {
        self.baseURL = configuration.baseURL
        self.tokenProvider = tokenProvider
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutInterval
            sessionConfiguration.timeoutIntervalForResource = configuration.timeoutInterval
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    public init(baseURL: URL, tokenProvider: (any AccessTokenProviding)? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    public func liveness() async throws -> APIHealthResponse {
        try await send(path: "health/live", method: "GET", body: Optional<EmptyBody>.none, requiresAuthentication: false)
    }

    public func readiness() async throws -> APIHealthResponse {
        try await send(path: "health/ready", method: "GET", body: Optional<EmptyBody>.none, requiresAuthentication: false)
    }

    public func projects() async throws -> [ProjectSummary] {
        try await send(path: "api/v1/projects", method: "GET", body: Optional<EmptyBody>.none)
    }

    public func project(projectID: UUID) async throws -> ProjectSummary {
        try await send(path: "api/v1/projects/\(projectID.uuidString)", method: "GET", body: Optional<EmptyBody>.none)
    }

    public func timeline(projectID: UUID) async throws -> [VersionSummary] {
        try await send(path: "api/v1/projects/\(projectID.uuidString)/timeline", method: "GET", body: Optional<EmptyBody>.none)
    }

    public func version(versionID: UUID) async throws -> VersionSummary {
        try await send(path: "api/v1/versions/\(versionID.uuidString)", method: "GET", body: Optional<EmptyBody>.none)
    }

    public func comments(versionID: UUID) async throws -> [VersionCommentResponse] {
        try await send(path: "api/v1/versions/\(versionID.uuidString)/comments", method: "GET", body: Optional<EmptyBody>.none)
    }

    /// Reuse the same idempotency key after an uncertain result so one logical
    /// user action cannot create duplicate comments.
    public func addComment(versionID: UUID, body: String, idempotencyKey: UUID) async throws -> VersionCommentResponse {
        let url = try makeURL("api/v1/versions/\(versionID.uuidString)/comments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try Self.makeEncoder().encode(CommentPayload(body: body))

        do {
            return try await execute(request, mutation: true)
        } catch let error as ApprovalAPIError {
            throw error
        } catch {
            throw ApprovalAPIError.outcomeUncertain
        }
    }

    public func audit(projectID: UUID) async throws -> [AuditRecord] {
        try await send(path: "api/v1/projects/\(projectID.uuidString)/audit-export?format=json", method: "GET", body: Optional<EmptyBody>.none)
    }

    /// Reuse the same idempotency key when reconciling a timeout. Never mint a
    /// replacement key automatically after an uncertain network outcome.
    public func decide(
        versionID: UUID,
        action: DecisionAction,
        comment: String?,
        idempotencyKey: UUID
    ) async throws -> DecisionResponse {
        let payload = DecisionPayload(action: action.rawValue, comment: comment)
        let path = "api/v1/versions/\(versionID.uuidString)/decisions"
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try Self.makeEncoder().encode(payload)

        do {
            return try await execute(request, mutation: true)
        } catch let error as ApprovalAPIError {
            throw error
        } catch {
            throw ApprovalAPIError.outcomeUncertain
        }
    }

    private func send<T: Decodable, Body: Encodable>(path: String, method: String, body: Body?, requiresAuthentication: Bool = true) async throws -> T {
        let url = try makeURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.makeEncoder().encode(body)
        }
        do {
            return try await execute(request, mutation: false, requiresAuthentication: requiresAuthentication)
        } catch let error as ApprovalAPIError {
            throw error
        } catch {
            throw ApprovalAPIError.networkUnavailable
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest, mutation: Bool, requiresAuthentication: Bool = true) async throws -> T {
        var authorizedRequest = request
        if requiresAuthentication {
            guard let tokenProvider else { throw ApprovalAPIError.authenticationNotConfigured }
            do {
                authorizedRequest.setValue("Bearer \(try await tokenProvider.validAccessToken())", forHTTPHeaderField: "Authorization")
            } catch {
                throw ApprovalAPIError.sessionExpired
            }
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: authorizedRequest)
        } catch {
            throw mutation ? ApprovalAPIError.outcomeUncertain : ApprovalAPIError.networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else { throw ApprovalAPIError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            do { return try Self.makeDecoder().decode(T.self, from: data) }
            catch { throw ApprovalAPIError.invalidResponse }
        case 401: throw ApprovalAPIError.sessionExpired
        case 403: throw ApprovalAPIError.forbidden
        case 404: throw ApprovalAPIError.notFound
        case 409: throw ApprovalAPIError.conflict
        case 503: throw ApprovalAPIError.serviceUnavailable
        case 500..<600 where mutation: throw ApprovalAPIError.outcomeUncertain
        default: throw ApprovalAPIError.requestFailed(statusCode: http.statusCode)
        }
    }

    private func makeURL(_ path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ApprovalAPIError.invalidResponse
        }
        let pathParts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + pathParts[0]
        if pathParts.count == 2 {
            components.percentEncodedQuery = String(pathParts[1])
        }
        guard let url = components.url else { throw ApprovalAPIError.invalidResponse }
        return url
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 timestamp")
        }
        return decoder
    }
}

private struct DecisionPayload: Encodable {
    let action: String
    let comment: String?
}

private struct CommentPayload: Encodable {
    let body: String
}

private struct EmptyBody: Encodable {}
