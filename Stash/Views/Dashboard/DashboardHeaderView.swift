import SwiftUI

struct DashboardHeaderView: View {
    @EnvironmentObject var dataController: DataController
    
    // Fetch request for today's items to get real-time updates
    @FetchRequest private var todaysItems: FetchedResults<StashItem>
    
    init() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        self._todaysItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Large number display inspired by MyFitnessPal
                    Text("\(todaysItems.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Subtitle with typography hierarchy
                    Text("items captured today")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Today's date
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Date(), format: .dateTime.weekday(.wide))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(Date(), format: .dateTime.month(.wide).day())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Progress indicator (subtle)
            if todaysItems.count > 0 {
                HStack(spacing: 8) {
                    let unprocessedCount = todaysItems.filter { !$0.isProcessed }.count
                    let processedCount = todaysItems.count - unprocessedCount
                    
                    Label("\(processedCount) processed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if unprocessedCount > 0 {
                        Label("\(unprocessedCount) pending", systemImage: "circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color(.systemBackground)
                .cornerRadius(0)
                .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
        )
    }
}

#Preview {
    DashboardHeaderView()
        .environmentObject(DataController())
}