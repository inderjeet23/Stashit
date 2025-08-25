import CoreData
import Foundation

extension DataController {
    private var demoSeedKey: String { "stash_demo_seeded_v1" }

    func seedDemoIfNeeded() {
        guard UserDefaults.standard.bool(forKey: demoSeedKey) == false else { return }

        let ctx = container.viewContext
        let now = Date()

        func makeItem(type: String, bucket: String, text: String?, url: String? = nil, offsetMinutes: Int) {
            let item = StashItem(context: ctx)
            item.id = UUID()
            item.type = type
            item.bucket = bucket
            item.createdAt = Calendar.current.date(byAdding: .minute, value: -offsetMinutes, to: now)
            item.updatedAt = item.createdAt
            item.isProcessed = bucket != "inbox"
            item.userCorrectedBucket = bucket != "inbox"
            item.confidence = 0.0
            item.ocrText = text
            item.url = url
        }

        // Inbox demo items (unprocessed)
        makeItem(type: "photo", bucket: "inbox", text: "Newest screenshot will land here", offsetMinutes: 1)
        makeItem(type: "link", bucket: "inbox", text: "Review this later", url: "https://example.com", offsetMinutes: 3)

        // Work
        makeItem(type: "text", bucket: "work", text: "Follow up: client feedback", offsetMinutes: 10)
        makeItem(type: "link", bucket: "work", text: "Spec doc", url: "https://company.example/spec", offsetMinutes: 15)

        // Shopping
        makeItem(type: "photo", bucket: "shopping", text: "Running shoes to compare", offsetMinutes: 20)
        makeItem(type: "link", bucket: "shopping", text: "Cart – monitor price drop", url: "https://store.example/cart", offsetMinutes: 25)

        // Ideas
        makeItem(type: "text", bucket: "ideas", text: "Concept: quick stash keyboard shortcut", offsetMinutes: 30)
        makeItem(type: "link", bucket: "ideas", text: "Inspiration article", url: "https://example.com/ux-flow", offsetMinutes: 35)

        // Personal
        makeItem(type: "photo", bucket: "personal", text: "Weekend plan: hiking spot", offsetMinutes: 40)
        makeItem(type: "text", bucket: "personal", text: "Gift ideas for Sam", offsetMinutes: 45)

        save()
        UserDefaults.standard.set(true, forKey: demoSeedKey)
    }
}

