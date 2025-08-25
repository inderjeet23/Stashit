import Foundation
import Photos
import UserNotifications
import UIKit
import CoreData

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

    // MARK: - Setup
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

    // MARK: - Import
    private func handleNewScreenshotAsset(_ asset: PHAsset) {
        // Avoid duplicates
        guard importedIds.contains(asset.localIdentifier) == false else { return }

        // If the app is active, ContentView handles in-app screenshots to avoid duplicates
        guard UIApplication.shared.applicationState != .active else { return }

        // Create item first (without image) to ensure it appears; then attach image
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

        // Fetch a downscaled image to store as binary content
        let targetSize = CGSize(width: 1024, height: 1024)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        imageManager.requestImage(for: asset,
                                  targetSize: targetSize,
                                  contentMode: .aspectFit,
                                  options: options) { [weak self] image, _ in
            guard let self, let img = image, let context = self.dataController?.container.viewContext else { return }
            if let data = img.jpegData(compressionQuality: 0.8) {
                newItem.content = data
                newItem.updatedAt = Date()
                self.dataController?.save()
            }
            self.markImported(assetId: asset.localIdentifier)

            // If app is not active, prompt the user to categorize
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
            if details.hasIncrementalChanges, let inserted = details.insertedObjects, !inserted.isEmpty {
                inserted.forEach { asset in
                    self?.handleNewScreenshotAsset(asset)
                }
            }
        }
    }
}
