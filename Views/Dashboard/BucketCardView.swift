import SwiftUI

struct BucketCardView: View {
    @Environment(\.colorScheme) private var colorScheme
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: bucket.icon ?? "folder")
                    .font(.title3)
                    .foregroundColor(cardColor)
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if items.count > 0 {
                    // Small count badge (notification style)
                    Text("\(unprocessedItems.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(unprocessedItems.count > 0 ? cardColor : Color(.systemGray4))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            // Minimal progress dot/bar
            HStack {
                Capsule()
                    .fill(cardColor)
                    .frame(width: max(6, min(60, CGFloat(unprocessedItems.count) * 6)), height: 6)
                    .opacity(unprocessedItems.count > 0 ? 1 : 0.25)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 90)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.cardBackground(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.tintedCardBackground(cardColor, colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardColor.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: DesignSystem.shadowColor(colorScheme, intensity: isPressed ? 0.12 : 0.04),
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

    // MARK: - Visual State Helpers
    @State private var pulse = true
    // Visual noise reductions: no last-updated or verbose stats here
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
