import SwiftUI

struct BucketCardView: View {
    let bucket: Bucket
    @EnvironmentObject var dataController: DataController
    @State private var isPressed = false
    @Binding var selectedBucketForEditing: Bucket?
    
    // Fetch request for items in this bucket
    @FetchRequest private var items: FetchedResults<StashItem>
    @FetchRequest private var unprocessedItems: FetchedResults<StashItem>
    
    init(bucket: Bucket, selectedBucketForEditing: Binding<Bucket?>) {
        self.bucket = bucket
        self._selectedBucketForEditing = selectedBucketForEditing
        
        // Fetch all items for this bucket
        self._items = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@", bucket.systemName ?? "")
        )
        
        // Fetch unprocessed items for this bucket
        self._unprocessedItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@ AND isProcessed == NO", bucket.systemName ?? "")
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and count
            HStack {
                Image(systemName: bucket.icon ?? "folder")
                    .font(.title2)
                    .foregroundColor(cardColor)
                    .frame(width: 24, height: 24)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // Bucket name
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if unprocessedItems.count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        
                        Text("\(unprocessedItems.count) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if items.count > 0 {
                    Text("All processed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardColor.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.15 : 0.05),
                    radius: isPressed ? 8 : 4,
                    x: 0,
                    y: isPressed ? 4 : 2
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onLongPressGesture(minimumDuration: 0.5) {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            selectedBucketForEditing = bucket
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }
    }
    
    private var displayName: String {
        bucket.customName ?? bucket.systemName?.capitalized ?? "Unknown"
    }
    
    private var cardColor: Color {
        switch bucket.colorName {
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
}

#Preview {
    let context = DataController().container.viewContext
    let sampleBucket = Bucket(context: context)
    sampleBucket.systemName = "work"
    sampleBucket.customName = "Work"
    sampleBucket.icon = "briefcase.fill"
    sampleBucket.colorName = "blue"
    
    return BucketCardView(bucket: sampleBucket, selectedBucketForEditing: .constant(nil))
        .environmentObject(DataController())
        .padding()
}