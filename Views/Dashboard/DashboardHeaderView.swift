import SwiftUI
import CoreData

struct DashboardHeaderView: View {
    @EnvironmentObject var dataController: DataController
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    // Optional action to start reviewing (e.g., open Inbox)
    var onReviewNow: (() -> Void)? = nil
    
    // Fetch request for today's items and overall unprocessed
    @FetchRequest private var todaysItems: FetchedResults<StashItem>
    @FetchRequest private var unprocessedItems: FetchedResults<StashItem>
    
    init(onReviewNow: (() -> Void)? = nil) {
        self.onReviewNow = onReviewNow
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        self._todaysItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        )
        self._unprocessedItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "isProcessed == NO")
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UI.gapL) {
            HeroCard(
                unsorted: unsortedCount,
                reviewed: reviewedToday,
                streak: streakCount ?? 0,
                date: Date(),
                onClear: { onReviewNow?() }
            )

            // Summary moved nearer to buckets for better relevance
        }
        .padding(.horizontal, UI.inset)
        .padding(.vertical, UI.gapS)
        .background(
            DesignSystem.cardBackground(colorScheme)
                .cornerRadius(0)
                .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
        )
    }
}

private extension DashboardHeaderView {
    var unsortedCount: Int { unprocessedItems.count }
    var reviewedToday: Int { todaysItems.filter { $0.isProcessed }.count }
    var urgencyColor: Color { unsortedCount > 10 ? .orange : .green }

    var summaryLine: String {
        let items = Array(todaysItems)
        let summary = ItemInsights.dashboardSummary(from: items)
        return summary.isEmpty ? "items captured today" : summary
    }

    var yesterdayClearsText: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let context = viewContext
        let request = NSFetchRequest<StashItem>(entityName: "StashItem")
        request.predicate = NSPredicate(format: "isProcessed == YES AND updatedAt >= %@ AND updatedAt < %@", start as NSDate, end as NSDate)
        let count = (try? context.fetch(request))?.count ?? 0
        return count > 0 ? "Cleared \(count) items yesterday" : ""
    }

    var averageProcessingMinutesText: String? {
        // Average time from createdAt to updatedAt for processed items
        let context = viewContext
        let request = NSFetchRequest<StashItem>(entityName: "StashItem")
        request.predicate = NSPredicate(format: "isProcessed == YES AND createdAt != nil AND updatedAt != nil")
        request.fetchLimit = 500
        guard let results = try? context.fetch(request), results.count > 0 else { return nil }
        let timestamps: [Double] = results.compactMap { res in
            guard let created = res.createdAt?.timeIntervalSince1970, let updated = res.updatedAt?.timeIntervalSince1970 else { return nil }
            return updated - created
        }
        let intervals = timestamps.filter { $0 > 0 }
        guard intervals.count > 0 else { return nil }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        let minutes = max(1, Int(round(avg / 60.0)))
        return "\(minutes)m"
    }

    var streakCount: Int? {
        // Count consecutive days ending today with at least 1 processed item
        let context = viewContext
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var streak = 0
        while streak < 30 { // cap
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let req = NSFetchRequest<NSNumber>(entityName: "StashItem")
            req.predicate = NSPredicate(format: "isProcessed == YES AND updatedAt >= %@ AND updatedAt < %@", day as NSDate, next as NSDate)
            req.resultType = .countResultType
            let count = (try? context.count(for: req)) ?? 0
            if count > 0 { streak += 1 } else { break }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak >= 2 ? streak : nil
    }
}

// Progress ring now lives in Views/Dashboard/HeroCard.swift

#Preview {
    DashboardHeaderView()
        .environment(\.managedObjectContext, DataController().container.viewContext)
        .environmentObject(DataController())
}
