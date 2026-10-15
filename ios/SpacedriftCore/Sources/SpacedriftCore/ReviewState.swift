import Foundation

/// A decision applies to exactly one immutable deliverable version.
public enum ReviewDecision: Equatable, Sendable {
    case requestChanges(comment: String)
    case approve(comment: String?)
}

public enum ReviewState: Equatable, Sendable {
    case awaitingReview
    case changesRequested
    case approved

    /// Validates the decision for this version. A new upload starts with a new
    /// `awaitingReview` state; an existing decision cannot be overwritten.
    public func applying(_ decision: ReviewDecision) throws -> ReviewState {
        guard self == .awaitingReview else {
            throw ReviewTransitionError.versionAlreadyDecided
        }

        switch decision {
        case let .requestChanges(comment):
            guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ReviewTransitionError.changeRequestNeedsComment
            }
            return .changesRequested
        case .approve:
            return .approved
        }
    }
}

public enum ReviewTransitionError: Error, Equatable, Sendable {
    case versionAlreadyDecided
    case changeRequestNeedsComment
}

/// Identity and timestamp are deliberately server-owned and not modeled here.
/// The API response must bind the returned decision to `versionID` and actor.
public struct ReviewDecisionRequest: Equatable, Sendable {
    public let versionID: UUID
    public let decision: ReviewDecision
    public let idempotencyKey: UUID

    public init(versionID: UUID, decision: ReviewDecision, idempotencyKey: UUID = UUID()) {
        self.versionID = versionID
        self.decision = decision
        self.idempotencyKey = idempotencyKey
    }
}
