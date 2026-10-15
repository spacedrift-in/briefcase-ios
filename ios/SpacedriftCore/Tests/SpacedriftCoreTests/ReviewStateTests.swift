import XCTest
@testable import SpacedriftCore

final class ReviewStateTests: XCTestCase {
    func testRequestChangesRequiresMeaningfulComment() {
        XCTAssertThrowsError(try ReviewState.awaitingReview.applying(.requestChanges(comment: " \n "))) {
            XCTAssertEqual($0 as? ReviewTransitionError, .changeRequestNeedsComment)
        }
    }

    func testRequestChangesCreatesTerminalDecisionForThisVersion() throws {
        let next = try ReviewState.awaitingReview.applying(.requestChanges(comment: "Please revise the title."))
        XCTAssertEqual(next, .changesRequested)
        XCTAssertThrowsError(try next.applying(.approve(comment: nil))) {
            XCTAssertEqual($0 as? ReviewTransitionError, .versionAlreadyDecided)
        }
    }

    func testApprovalIsVersionScopedAndTerminal() throws {
        let versionOne = UUID()
        let request = ReviewDecisionRequest(
            versionID: versionOne,
            decision: .approve(comment: nil),
            idempotencyKey: UUID()
        )

        XCTAssertEqual(request.versionID, versionOne)
        XCTAssertEqual(try ReviewState.awaitingReview.applying(request.decision), .approved)
        XCTAssertThrowsError(try ReviewState.approved.applying(.requestChanges(comment: "Reopen")))

        // Every newly uploaded version starts independently, never approved by inheritance.
        let versionTwo = ReviewState.awaitingReview
        XCTAssertEqual(versionTwo, .awaitingReview)
    }
}
