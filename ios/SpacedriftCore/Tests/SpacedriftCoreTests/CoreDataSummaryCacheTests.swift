import CoreData
import XCTest
@testable import SpacedriftCore

final class CoreDataSummaryCacheTests: XCTestCase {
    @MainActor
    func testProjectSummariesAreStaleReadOnlyMetadataAndCanBeInvalidated() async throws {
        let cache = CoreDataSummaryCache(inMemory: true, staleAfter: 10)
        try await cache.load()
        let project = ProjectSummary(id: UUID(), name: "Synthetic Client Project", summary: "Cached summary")
        let lastSync = Date(timeIntervalSince1970: 100)

        try cache.replaceProjects([project], syncedAt: lastSync)
        let records = try cache.projects(now: Date(timeIntervalSince1970: 111))
        XCTAssertEqual(records.map(\.project), [project])
        XCTAssertTrue(records[0].isStale)
        XCTAssertEqual(records[0].lastSuccessfulSync, lastSync)

        try cache.replaceProjects([], syncedAt: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(try cache.projects().isEmpty)
    }

    @MainActor
    func testVersionMetadataIsCachedWithoutCreatingApproval() async throws {
        let cache = CoreDataSummaryCache(inMemory: true)
        try await cache.load()
        let project = ProjectSummary(id: UUID(), name: "Synthetic Project", summary: "Read only")
        let version = VersionSummary(
            id: UUID(),
            deliverableID: UUID(),
            versionNumber: 2,
            mediaType: "application/pdf",
            byteSize: 128,
            authorSubject: "synthetic-consultant",
            createdAt: Date(timeIntervalSince1970: 100),
            reviewStatus: "awaiting_review"
        )
        try cache.replaceProjects([project], syncedAt: Date(timeIntervalSince1970: 100))
        try cache.replaceVersions([version], for: project.id, syncedAt: Date(timeIntervalSince1970: 100))

        let records = try cache.versions(projectID: project.id)
        XCTAssertEqual(records.map(\.version), [version])
        XCTAssertEqual(records[0].version.reviewStatus, "awaiting_review")
        XCTAssertThrowsError(try cache.replaceVersions([], for: UUID()))
    }

    @MainActor
    func testProjectSummarySurvivesPersistentStoreRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("summary-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let project = ProjectSummary(id: UUID(), name: "Offline Demo", summary: "Persisted metadata")
        try await store(project, at: storeURL)

        let reloaded = CoreDataSummaryCache(storeURL: storeURL)
        try await reloaded.load()
        XCTAssertEqual(try reloaded.projects().map(\.project), [project])
    }

    @MainActor
    private func store(_ project: ProjectSummary, at storeURL: URL) async throws {
        let cache = CoreDataSummaryCache(storeURL: storeURL)
        try await cache.load()
        try cache.replaceProjects([project], syncedAt: Date(timeIntervalSince1970: 100))
    }
}
