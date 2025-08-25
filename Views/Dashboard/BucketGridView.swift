import SwiftUI

struct BucketGridView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bucket.createdAt, ascending: true)],
        animation: .default
    ) private var buckets: FetchedResults<Bucket>
    
    @Binding var selectedBucketForEditing: Bucket?
    
    // Responsive grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(buckets, id: \.id) { bucket in
                BucketCardView(
                    bucket: bucket,
                    selectedBucketForEditing: $selectedBucketForEditing
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    let context = DataController().container.viewContext
    
    // Create sample buckets
    let buckets = [
        ("inbox", "Inbox", "tray", "gray"),
        ("work", "Work", "briefcase.fill", "blue"),
        ("shopping", "Shopping", "cart.fill", "green"),
        ("ideas", "Ideas", "lightbulb.fill", "orange"),
        ("personal", "Personal", "person.fill", "purple")
    ]
    
    for (systemName, displayName, icon, colorName) in buckets {
        let bucket = Bucket(context: context)
        bucket.id = UUID()
        bucket.systemName = systemName
        bucket.customName = displayName
        bucket.icon = icon
        bucket.colorName = colorName
        bucket.createdAt = Date()
    }
    
    return BucketGridView(selectedBucketForEditing: .constant(nil))
        .environmentObject(DataController())
}