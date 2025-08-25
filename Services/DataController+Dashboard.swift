import CoreData
import Foundation
import SwiftUI

extension DataController {
    
    // MARK: - Today's Items Count
    
    var todaysItemsCount: Int {
        let request: NSFetchRequest<StashItem> = StashItem.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            return try container.viewContext.count(for: request)
        } catch {
            print("Error fetching today's items count: \(error)")
            return 0
        }
    }
    
    // MARK: - Bucket Management
    
    func createDefaultBuckets() {
        let context = container.viewContext
        
        // Check if buckets already exist
        let request: NSFetchRequest<Bucket> = Bucket.fetchRequest()
        if let existingCount = try? context.count(for: request), existingCount > 0 {
            return // Buckets already exist
        }
        
        let defaultBuckets = [
            ("inbox", "Inbox", "tray", "gray"),
            ("work", "Work", "briefcase.fill", "blue"),
            ("shopping", "Shopping", "cart.fill", "green"),
            ("ideas", "Ideas", "lightbulb.fill", "orange"),
            ("personal", "Personal", "person.fill", "purple")
        ]
        
        for (systemName, displayName, icon, colorName) in defaultBuckets {
            let bucket = Bucket(context: context)
            bucket.id = UUID()
            bucket.systemName = systemName
            bucket.customName = displayName
            bucket.icon = icon
            bucket.colorName = colorName
            bucket.createdAt = Date()
        }
        
        save()
    }
    
    func getItemCount(for bucketSystemName: String) -> Int {
        let request: NSFetchRequest<StashItem> = StashItem.fetchRequest()
        request.predicate = NSPredicate(format: "bucket == %@", bucketSystemName)
        
        do {
            return try container.viewContext.count(for: request)
        } catch {
            print("Error fetching count for bucket \(bucketSystemName): \(error)")
            return 0
        }
    }
    
    func getUnprocessedItemCount(for bucketSystemName: String) -> Int {
        let request: NSFetchRequest<StashItem> = StashItem.fetchRequest()
        request.predicate = NSPredicate(format: "bucket == %@ AND isProcessed == NO", bucketSystemName)
        
        do {
            return try container.viewContext.count(for: request)
        } catch {
            print("Error fetching unprocessed count for bucket \(bucketSystemName): \(error)")
            return 0
        }
    }
    
    func renameBucket(systemName: String, to newName: String) {
        let context = container.viewContext
        let request: NSFetchRequest<Bucket> = Bucket.fetchRequest()
        request.predicate = NSPredicate(format: "systemName == %@", systemName)
        
        do {
            if let bucket = try context.fetch(request).first {
                bucket.customName = newName
                save()
            }
        } catch {
            print("Error renaming bucket: \(error)")
        }
    }
    
    // MARK: - Color Helpers
    
    func colorForBucket(_ systemName: String) -> Color {
        let context = container.viewContext
        let request: NSFetchRequest<Bucket> = Bucket.fetchRequest()
        request.predicate = NSPredicate(format: "systemName == %@", systemName)
        
        do {
            if let bucket = try context.fetch(request).first {
                return colorFromName(bucket.colorName ?? "gray")
            }
        } catch {
            print("Error fetching bucket color: \(error)")
        }
        
        // Fallback to legacy color mapping
        switch systemName {
        case "work": return .blue
        case "shopping": return .green
        case "ideas": return .orange
        case "personal": return .purple
        default: return .gray
        }
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        case "teal": return .teal
        default: return .gray
        }
    }

    // MARK: - Demo Seeding (First Launch)
    func seedDemoIfNeeded() {
        let key = "stash_demo_seeded_v1"
        guard UserDefaults.standard.bool(forKey: key) == false else { return }

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
        UserDefaults.standard.set(true, forKey: key)
    }
}
