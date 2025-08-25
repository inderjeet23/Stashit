import CoreData
import Foundation
import UserNotifications
import Photos
import UIKit

class DataController: ObservableObject {
    let container: NSPersistentContainer
    // Set this to your App Group identifier (enable in both app and extension)
    // Example: "group.com.yourcompany.stash"
    static let appGroupID: String? = "group.com.yourdomain.stash"
    
    init() {
        container = NSPersistentContainer(name: "StashDataModel")

        // If an App Group is configured, store Core Data in the shared container
        if let appGroupID = Self.appGroupID,
           let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = containerURL.appendingPathComponent("Stash.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    func fixProcessedFlags() {
        let context = container.viewContext
        let request: NSFetchRequest<StashItem> = StashItem.fetchRequest()
        
        do {
            let items = try context.fetch(request)
            var hasChanges = false
            
            for item in items {
                let shouldBeProcessed = item.bucket != "inbox"
                if item.isProcessed != shouldBeProcessed {
                    print("Fixing item: bucket=\(item.bucket ?? "nil"), isProcessed was=\(item.isProcessed), should be=\(shouldBeProcessed)")
                    item.isProcessed = shouldBeProcessed
                    hasChanges = true
                }
            }
            
            if hasChanges {
                try context.save()
                print("Fixed \(items.count) item processed flags")
            } else {
                print("All item processed flags are correct")
            }
        } catch {
            print("Failed to fix processed flags: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var openInboxRequested = false

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        // Add 'Categorize Now' action to open Inbox
        let openInbox = UNNotificationAction(identifier: "CATEGORIZE_NOW",
                                             title: "Categorize Now",
                                             options: [.foreground])
        let category = UNNotificationCategory(identifier: "SCREENSHOT_CATEGORY",
                                              actions: [openInbox],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        center.setNotificationCategories([category])
        center.delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "SCREENSHOT_CATEGORY" {
            // Open Inbox for both default tap and 'Categorize Now' action
            DispatchQueue.main.async { [weak self] in
                self?.openInboxRequested = true
            }
        }
        completionHandler()
    }
}

// MARK: - Screenshot Monitor
final class ScreenshotMonitor: NSObject, ObservableObject {
    private weak var dataController: DataController?
    private var screenshotFetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHImageManager.default()
    private let userDefaultsKey = "lastImportedScreenshotIds"
    private var importedIds: Set<String> = []

    init(dataController: DataController) {
        self.dataController = dataController
        super.init()
        self.importedIds = Self.loadImportedIds(from: userDefaultsKey)
    }

    func start() {
        requestPhotoAccessIfNeeded { [weak self] granted in
            guard let self else { return }
            guard granted else { return }
            DispatchQueue.main.async {
                self.setupFetchAndObserve()
            }
        }
    }

    func stop() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        screenshotFetchResult = nil
    }

    private func setupFetchAndObserve() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtype & %d) != 0",
                                        PHAssetMediaType.image.rawValue,
                                        PHAssetMediaSubtype.photoScreenshot.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        screenshotFetchResult = result
        PHPhotoLibrary.shared().register(self)
    }

    private func requestPhotoAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                completion(newStatus == .authorized || newStatus == .limited)
            }
        default:
            completion(false)
        }
    }

    private func handleNewScreenshotAsset(_ asset: PHAsset) {
        // Avoid duplicates
        guard importedIds.contains(asset.localIdentifier) == false else { return }

        // If the app is active, ContentView handles in-app screenshots
        guard UIApplication.shared.applicationState != .active else { return }

        guard let context = dataController?.container.viewContext else { return }
        let newItem = StashItem(context: context)
        newItem.id = UUID()
        newItem.type = "screenshot"
        newItem.bucket = "inbox"
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        newItem.isProcessed = false
        newItem.userCorrectedBucket = false
        newItem.confidence = 0.0
        newItem.ocrText = "Screenshot saved \(Date().formatted(date: .abbreviated, time: .shortened))"
        dataController?.save()

        let targetSize = CGSize(width: 1024, height: 1024)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        imageManager.requestImage(for: asset,
                                  targetSize: targetSize,
                                  contentMode: .aspectFit,
                                  options: options) { [weak self] image, _ in
            guard let self, let img = image else { return }
            if let data = img.jpegData(compressionQuality: 0.8) {
                newItem.content = data
                newItem.updatedAt = Date()
                self.dataController?.save()
            }
            self.markImported(assetId: asset.localIdentifier)

            if UIApplication.shared.applicationState != .active {
                self.scheduleCategorizeNotification()
            }
        }
    }

    private func scheduleCategorizeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot captured"
        content.body = "Open Inbox to categorize it now."
        content.sound = .default
        content.categoryIdentifier = "SCREENSHOT_CATEGORY"

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func markImported(assetId: String) {
        importedIds.insert(assetId)
        Self.saveImportedIds(importedIds, to: userDefaultsKey)
    }

    private static func loadImportedIds(from key: String) -> Set<String> {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            return Set(array)
        }
        return []
    }

    private static func saveImportedIds(_ ids: Set<String>, to key: String) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}

extension ScreenshotMonitor: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = screenshotFetchResult,
              let details = changeInstance.changeDetails(for: fetchResult) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.screenshotFetchResult = details.fetchResultAfterChanges
            let inserted = details.insertedObjects
            if details.hasIncrementalChanges && !inserted.isEmpty {
                inserted.forEach { asset in
                    self?.handleNewScreenshotAsset(asset)
                }
            }
        }
    }
}
