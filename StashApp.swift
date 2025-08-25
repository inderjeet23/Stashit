import SwiftUI
import UserNotifications

@main
struct StashApp: App {
    @StateObject private var dataController: DataController
    @StateObject private var notificationDelegate: NotificationDelegate
    @StateObject private var screenshotMonitor: ScreenshotMonitor

    init() {
        let dc = DataController()
        let nd = NotificationDelegate()
        nd.requestAuthorization()
        let sm = ScreenshotMonitor(dataController: dc)
        sm.start()
        // Seed demo content on first launch
        dc.seedDemoIfNeeded()
        
        // Fix any inconsistent processed flags
        dc.fixProcessedFlags()

        _dataController = StateObject(wrappedValue: dc)
        _notificationDelegate = StateObject(wrappedValue: nd)
        _screenshotMonitor = StateObject(wrappedValue: sm)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(notificationDelegate)
        }
    }
}
