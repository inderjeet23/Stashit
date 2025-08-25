import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var openInboxRequested = false

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // Register category (placeholder for future actions)
        let category = UNNotificationCategory(identifier: "SCREENSHOT_CATEGORY",
                                              actions: [],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        center.setNotificationCategories([category])
        center.delegate = self
    }

    // Open Inbox on tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "SCREENSHOT_CATEGORY" {
            DispatchQueue.main.async { [weak self] in
                self?.openInboxRequested = true
            }
        }
        completionHandler()
    }
}

