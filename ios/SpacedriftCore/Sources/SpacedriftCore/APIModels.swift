import Foundation

/// Process-level health response. `alive` only confirms that the API process
/// answered; it does not imply database readiness or authenticated access.
public struct APIHealthResponse: Codable, Equatable, Sendable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct ProjectSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let summary: String

    public init(id: UUID, name: String, summary: String) {
        self.id = id
        self.name = name
        self.summary = summary
    }
}

public struct VersionSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let deliverableID: UUID
    public let versionNumber: Int
    public let mediaType: String
    public let byteSize: Int
    public let authorSubject: String
    public let createdAt: Date
    public let reviewStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case deliverableID = "deliverable_id"
        case versionNumber = "version_number"
        case mediaType = "media_type"
        case byteSize = "byte_size"
        case authorSubject = "author_subject"
        case createdAt = "created_at"
        case reviewStatus = "review_status"
    }
}

public struct DecisionResponse: Codable, Equatable, Sendable {
    public let id: UUID
    public let versionID: UUID
    public let actorSubject: String
    public let action: String
    public let comment: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case versionID = "version_id"
        case actorSubject = "actor_subject"
        case action
        case comment
        case createdAt = "created_at"
    }
}

public enum DecisionAction: String, Codable, Sendable {
    case requestChanges = "request_changes"
    case approve
}

public struct AuditRecord: Codable, Identifiable, Equatable, Sendable {
    public let eventID: UUID
    public let decisionID: UUID
    public let versionID: UUID
    public let actorSubject: String
    public let action: String
    public let comment: String?
    public let createdAt: Date

    public var id: UUID { eventID }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case decisionID = "decision_id"
        case versionID = "version_id"
        case actorSubject = "actor_subject"
        case action
        case comment
        case createdAt = "created_at"
    }
}
