import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // Preview data for SwiftUI previews only.
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for index in 0..<8 {
            let entity = VaultEntity(context: viewContext)
            entity.id = UUID()
            entity.originalName = "Sample-\(index).txt"
            entity.mimeType = "text/plain"
            entity.size = 128
            entity.createdAt = Date()
            entity.fileName = UUID().uuidString
            entity.category = index % 2 == 0 ? "Notes" : "Reports"
            entity.folder = entity.category
            entity.sha256 = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            entity.isImage = false
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Preview data error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    // Creates the Core Data stack for the app.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SilentStore")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Persistent store error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
