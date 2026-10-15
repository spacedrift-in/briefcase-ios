import CoreData
import Foundation

public struct CachedProjectSummary: Equatable, Sendable {
    public let project: ProjectSummary
    public let lastSuccessfulSync: Date
    public let isStale: Bool
}

public struct CachedVersionSummary: Equatable, Sendable {
    public let version: VersionSummary
    public let lastSuccessfulSync: Date
    public let isStale: Bool
}

public enum SummaryCacheError: Error {
    case projectNotCached
}

/// Read-only local metadata cache. It has no method that can write review state.
@MainActor
public final class CoreDataSummaryCache {
    private let container: NSPersistentContainer
    private let staleAfter: TimeInterval

    public init(inMemory: Bool = false, storeURL: URL? = nil, staleAfter: TimeInterval = 24 * 60 * 60) {
        self.staleAfter = staleAfter
        container = NSPersistentContainer(name: "SpacedriftSummaryCache", managedObjectModel: Self.makeModel())
        let description = NSPersistentStoreDescription(url: storeURL ?? Self.defaultStoreURL())
        if inMemory { description.type = NSInMemoryStoreType }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.undoManager = nil
    }

    public func load() async throws {
        if container.persistentStoreDescriptions.first?.type != NSInMemoryStoreType,
           let storeURL = container.persistentStoreDescriptions.first?.url {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    public func replaceProjects(_ projects: [ProjectSummary], syncedAt: Date = .now) throws {
        let context = container.viewContext
        let incoming = Set(projects.map { $0.id.uuidString.lowercased() })
        let existing = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CachedProject"))
        for object in existing {
            let id = object.value(forKey: "id") as? String ?? ""
            if !incoming.contains(id) {
                try deleteVersions(projectID: id, in: context)
                context.delete(object)
            }
        }

        for project in projects {
            let id = project.id.uuidString.lowercased()
            let object = try fetchOrInsert(entity: "CachedProject", id: id, in: context)
            object.setValue(id, forKey: "id")
            object.setValue(project.name, forKey: "name")
            object.setValue(project.summary, forKey: "summary")
            object.setValue(syncedAt, forKey: "lastSyncAt")
        }
        try context.save()
    }

    public func projects(now: Date = .now) throws -> [CachedProjectSummary] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedProject")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try container.viewContext.fetch(request).compactMap { object in
            guard
                let id = object.value(forKey: "id") as? String,
                let uuid = UUID(uuidString: id),
                let name = object.value(forKey: "name") as? String,
                let summary = object.value(forKey: "summary") as? String,
                let syncedAt = object.value(forKey: "lastSyncAt") as? Date
            else { return nil }
            return CachedProjectSummary(
                project: ProjectSummary(id: uuid, name: name, summary: summary),
                lastSuccessfulSync: syncedAt,
                isStale: now.timeIntervalSince(syncedAt) > staleAfter
            )
        }
    }

    public func replaceVersions(_ versions: [VersionSummary], for projectID: UUID, syncedAt: Date = .now) throws {
        let context = container.viewContext
        let projectKey = projectID.uuidString.lowercased()
        let projectRequest = NSFetchRequest<NSManagedObject>(entityName: "CachedProject")
        projectRequest.predicate = NSPredicate(format: "id == %@", projectKey)
        guard let project = try context.fetch(projectRequest).first else {
            throw SummaryCacheError.projectNotCached
        }
        project.setValue(syncedAt, forKey: "lastSyncAt")

        let incoming = Set(versions.map { $0.id.uuidString.lowercased() })
        try deleteVersions(projectID: projectKey, except: incoming, in: context)
        for version in versions {
            let id = version.id.uuidString.lowercased()
            let object = try fetchOrInsert(entity: "CachedVersion", id: id, in: context)
            object.setValue(id, forKey: "id")
            object.setValue(projectKey, forKey: "projectID")
            object.setValue(version.deliverableID.uuidString.lowercased(), forKey: "deliverableID")
            object.setValue(version.versionNumber, forKey: "versionNumber")
            object.setValue(version.mediaType, forKey: "mediaType")
            object.setValue(version.byteSize, forKey: "byteSize")
            object.setValue(version.authorSubject, forKey: "authorSubject")
            object.setValue(version.createdAt, forKey: "createdAt")
            object.setValue(version.reviewStatus, forKey: "reviewStatus")
            object.setValue(syncedAt, forKey: "lastSyncAt")
        }
        try context.save()
    }

    public func versions(projectID: UUID, now: Date = .now) throws -> [CachedVersionSummary] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedVersion")
        request.predicate = NSPredicate(format: "projectID == %@", projectID.uuidString.lowercased())
        request.sortDescriptors = [NSSortDescriptor(key: "versionNumber", ascending: false)]
        return try container.viewContext.fetch(request).compactMap { object in
            guard
                let idString = object.value(forKey: "id") as? String,
                let id = UUID(uuidString: idString),
                let deliverableString = object.value(forKey: "deliverableID") as? String,
                let deliverableID = UUID(uuidString: deliverableString),
                let versionNumber = object.value(forKey: "versionNumber") as? Int,
                let mediaType = object.value(forKey: "mediaType") as? String,
                let byteSize = object.value(forKey: "byteSize") as? Int,
                let authorSubject = object.value(forKey: "authorSubject") as? String,
                let createdAt = object.value(forKey: "createdAt") as? Date,
                let reviewStatus = object.value(forKey: "reviewStatus") as? String,
                let syncedAt = object.value(forKey: "lastSyncAt") as? Date
            else { return nil }

            return CachedVersionSummary(
                version: VersionSummary(
                    id: id,
                    deliverableID: deliverableID,
                    versionNumber: versionNumber,
                    mediaType: mediaType,
                    byteSize: byteSize,
                    authorSubject: authorSubject,
                    createdAt: createdAt,
                    reviewStatus: reviewStatus
                ),
                lastSuccessfulSync: syncedAt,
                isStale: now.timeIntervalSince(syncedAt) > staleAfter
            )
        }
    }

    public func clear() throws {
        let context = container.viewContext
        for entity in ["CachedVersion", "CachedProject"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            for object in try context.fetch(request) { context.delete(object) }
        }
        try context.save()
    }

    private func fetchOrInsert(entity: String, id: String, in context: NSManagedObjectContext) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id)
        if let object = try context.fetch(request).first { return object }
        return NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private func deleteVersions(projectID: String, except keepIDs: Set<String> = [], in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedVersion")
        request.predicate = NSPredicate(format: "projectID == %@", projectID)
        for object in try context.fetch(request) {
            let id = object.value(forKey: "id") as? String ?? ""
            if !keepIDs.contains(id) { context.delete(object) }
        }
    }

    private static func defaultStoreURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("Spacedrift", isDirectory: true)
            .appendingPathComponent("summary-cache.sqlite")
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity("CachedProject", attributes: [
                attribute("id", .stringAttributeType), attribute("name", .stringAttributeType),
                attribute("summary", .stringAttributeType), attribute("lastSyncAt", .dateAttributeType)
            ], uniqueKeys: [["id"]]),
            entity("CachedVersion", attributes: [
                attribute("id", .stringAttributeType), attribute("projectID", .stringAttributeType),
                attribute("deliverableID", .stringAttributeType), attribute("versionNumber", .integer64AttributeType),
                attribute("mediaType", .stringAttributeType), attribute("byteSize", .integer64AttributeType),
                attribute("authorSubject", .stringAttributeType), attribute("createdAt", .dateAttributeType),
                attribute("reviewStatus", .stringAttributeType), attribute("lastSyncAt", .dateAttributeType)
            ], uniqueKeys: [["id"]])
        ]
        return model
    }

    private static func entity(_ name: String, attributes: [NSAttributeDescription], uniqueKeys: [[String]]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = attributes
        entity.uniquenessConstraints = uniqueKeys
        return entity
    }

    private static func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = false
        return attribute
    }
}
