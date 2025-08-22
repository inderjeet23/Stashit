import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var dataController: DataController
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StashItem>
    
    @State private var selectedBucketForEditing: Bucket?
    @State private var showingItemsList = false
    @State private var showAddModal = false
    @State private var showingInboxView = false
    @State private var selectedItemForCategorization: StashItem?
    @State private var selectedBucketForViewing: Bucket?
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Dashboard Header
                    DashboardHeaderView()
                    
                    if items.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Welcome to Stash")
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("Capture everything. Deal with it later. Actually deal with it.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Bucket Grid
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Buckets")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: { showingItemsList = true }) {
                                    HStack(spacing: 4) {
                                        Text("View All")
                                            .font(.subheadline)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            UpdatedBucketGridView(
                                selectedBucketForEditing: $selectedBucketForEditing,
                                showingInboxView: $showingInboxView,
                                selectedBucketForViewing: $selectedBucketForViewing
                            )
                        }
                    }
                }
            }
            .navigationTitle("Stash")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddModal = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(item: $selectedBucketForEditing) { bucket in
            BucketEditModal(bucket: bucket)
        }
        .sheet(isPresented: $showingItemsList) {
            ItemsListView()
        }
        .sheet(isPresented: $showAddModal) {
            AddItemModalView()
        }
        .sheet(isPresented: $showingInboxView) {
            InboxItemsView(selectedItemForCategorization: $selectedItemForCategorization)
        }
        .sheet(item: $selectedItemForCategorization) { item in
            ItemCategorizationModal(item: item)
        }
        .sheet(item: $selectedBucketForViewing) { bucket in
            BucketItemsView(bucket: bucket, selectedItemForCategorization: $selectedItemForCategorization)
        }
        .onAppear {
            dataController.createDefaultBuckets()
            setupScreenshotDetection()
        }
        .onDisappear {
            removeScreenshotDetection()
        }
    }
    
    private func addSampleItem() {
        withAnimation {
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = "sample"
            newItem.bucket = "inbox"
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = false
            newItem.userCorrectedBucket = false
            newItem.confidence = 0.0
            
            dataController.save()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            dataController.save()
        }
    }
    
    // MARK: - Screenshot Detection
    private func setupScreenshotDetection() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleScreenshotTaken()
        }
    }
    
    private func removeScreenshotDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }
    
    private func handleScreenshotTaken() {
        withAnimation {
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = "screenshot"
            newItem.bucket = "inbox"
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = false
            newItem.userCorrectedBucket = false
            newItem.confidence = 0.0
            newItem.ocrText = "Screenshot taken at \(Date().formatted(date: .abbreviated, time: .shortened))"
            
            dataController.save()
            
            // Optional: Show a brief confirmation
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

struct StashItemRow: View {
    let item: StashItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type?.capitalized ?? "Unknown")
                    .font(.headline)
                
                Text(item.bucket?.capitalized ?? "Inbox")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(bucketColor.opacity(0.2))
                    .foregroundColor(bucketColor)
                    .clipShape(Capsule())
                
                if let createdAt = item.createdAt {
                    Text(createdAt, format: .dateTime.day().month().hour().minute())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !item.isProcessed {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var bucketColor: Color {
        switch item.bucket {
        case "work":
            return .blue
        case "shopping":
            return .green
        case "ideas":
            return .orange
        case "personal":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Data Models
enum ItemType: String, CaseIterable, Identifiable {
    case screenshot = "screenshot"
    case link = "link"  
    case voice = "voice"
    case text = "text"
    case photo = "photo"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .link: return "Link"
        case .voice: return "Voice"
        case .text: return "Text"
        case .photo: return "Photo"
        }
    }
    
    var systemImage: String {
        switch self {
        case .screenshot: return "camera.viewfinder"
        case .link: return "link"
        case .voice: return "waveform"
        case .text: return "text.alignleft"
        case .photo: return "photo"
        }
    }
    
    var placeholder: String {
        switch self {
        case .screenshot: return "Tap to add screenshot"
        case .link: return "Tap to add link"
        case .voice: return "Tap to record voice"
        case .text: return "Tap to add text"
        case .photo: return "Tap to add photo"
        }
    }
    
    var shortName: String { displayName }
}

enum BucketType: String, CaseIterable, Identifiable {
    case work = "work"
    case shopping = "shopping"
    case ideas = "ideas"
    case personal = "personal"
    case inbox = "inbox"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .shopping: return "Shopping"
        case .ideas: return "Ideas"
        case .personal: return "Personal"
        case .inbox: return "Inbox"
        }
    }
    
    var emoji: String {
        switch self {
        case .work: return "💼"
        case .shopping: return "🛒"
        case .ideas: return "💡"
        case .personal: return "👤"
        case .inbox: return "📥"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return .blue
        case .shopping: return .green
        case .ideas: return .orange
        case .personal: return .purple
        case .inbox: return .gray
        }
    }
}

// MARK: - Add Item Modal
struct AddItemModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var dataController: DataController
    
    @State private var selectedType: ItemType = .screenshot
    @State private var selectedBucket: BucketType = .inbox
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    TypeSelectionView(selectedType: $selectedType)
                    ContentInputView(selectedType: selectedType, content: $content)
                    BucketSelectionView(selectedBucket: $selectedBucket)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                        dismiss()
                    }
                    .foregroundColor(canAdd ? .primary : .gray)
                    .disabled(!canAdd)
                }
            }
        }
    }
    
    private var canAdd: Bool { true }
    
    private func addItem() {
        withAnimation {
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = selectedType.rawValue
            newItem.bucket = selectedBucket.rawValue
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = false
            newItem.userCorrectedBucket = false
            newItem.confidence = 0.0
            
            if !content.isEmpty {
                switch selectedType {
                case .text:
                    newItem.ocrText = content
                case .link:
                    newItem.url = content
                case .photo, .screenshot:
                    newItem.ocrText = content
                case .voice:
                    newItem.ocrText = content
                }
            }
            
            dataController.save()
        }
    }
}

// MARK: - Supporting Views
struct TypeSelectionView: View {
    @Binding var selectedType: ItemType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ItemType.allCases) { type in
                        TypeSelectionButton(type: type, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct TypeSelectionButton: View {
    let type: ItemType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ContentInputView: View {
    let selectedType: ItemType
    @Binding var content: String
    @State private var showingTextInput = false
    @State private var showingURLInput = false
    @State private var showingImagePicker = false
    @State private var tempText = ""
    @State private var tempURL = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: handleContentInput) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: selectedType.systemImage)
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            
                            Text(selectedType.placeholder)
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(content)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
        }
        .sheet(isPresented: $showingTextInput) {
            TextInputSheet(text: $tempText) {
                content = tempText
            }
        }
        .sheet(isPresented: $showingURLInput) {
            URLInputSheet(url: $tempURL) {
                content = tempURL
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerSheet { selectedImage in
                content = "Photo selected from library"
            }
        }
    }
    
    private func handleContentInput() {
        switch selectedType {
        case .text:
            tempText = content
            showingTextInput = true
        case .link:
            tempURL = content
            showingURLInput = true
        case .photo:
            showingImagePicker = true
        case .screenshot:
            // Future: Implement screenshot capture functionality
            content = "Screenshot capture coming soon"
        case .voice:
            // Future: Implement voice recording functionality
            content = "Voice recording coming soon"
        }
    }
}

struct BucketSelectionView: View {
    @Binding var selectedBucket: BucketType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bucket")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(BucketType.allCases) { bucket in
                    BucketSelectionRow(bucket: bucket, isSelected: selectedBucket == bucket) {
                        selectedBucket = bucket
                    }
                }
            }
        }
    }
}

struct BucketSelectionRow: View {
    let bucket: BucketType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(bucket.emoji)
                    .font(.title2)
                
                Text(bucket.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(bucket.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? bucket.color.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? bucket.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Inbox Views
struct InboxItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedItemForCategorization: StashItem?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "bucket == %@ AND isProcessed == NO", "inbox"),
        animation: .default
    ) private var inboxItems: FetchedResults<StashItem>
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if inboxItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Inbox is Empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Items you add will appear here for categorization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(inboxItems, id: \.id) { item in
                            InboxItemCard(item: item) {
                                selectedItemForCategorization = item
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InboxItemCard: View {
    let item: StashItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Type icon and timestamp
                HStack {
                    Image(systemName: itemTypeIcon)
                        .font(.title3)
                        .foregroundColor(itemTypeColor)
                    
                    Spacer()
                    
                    if let createdAt = item.createdAt {
                        Text(createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content preview
                Text(contentPreview)
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                // Type label
                Text(item.type?.capitalized ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(itemTypeColor.opacity(0.1))
                    .foregroundColor(itemTypeColor)
                    .clipShape(Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return .purple
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var contentPreview: String {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            return ocrText
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot captured"
            case "photo": return "Photo captured" 
            case "voice": return "Voice recording"
            case "link": return "Link captured"
            case "text": return "Text content"
            default: return "Content captured"
            }
        }
    }
}

struct ItemCategorizationModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var dataController: DataController
    
    let item: StashItem
    @State private var selectedBucket: BucketType = .inbox
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Item preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Item Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: itemTypeIcon)
                                .font(.title2)
                                .foregroundColor(itemTypeColor)
                                .frame(width: 40, height: 40)
                                .background(itemTypeColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.type?.capitalized ?? "Unknown")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(contentPreview)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)
                                
                                if let createdAt = item.createdAt {
                                    Text(createdAt, format: .dateTime.day().month().hour().minute())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Bucket selection
                    BucketSelectionView(selectedBucket: $selectedBucket)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Categorize Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        moveItem()
                    }
                    .foregroundColor(selectedBucket != BucketType(rawValue: item.bucket ?? "") ? .blue : .gray)
                    .disabled(selectedBucket == BucketType(rawValue: item.bucket ?? ""))
                }
            }
        }
        .onAppear {
            selectedBucket = BucketType(rawValue: item.bucket ?? "inbox") ?? .inbox
        }
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return .purple
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var contentPreview: String {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            return ocrText
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot captured"
            case "photo": return "Photo captured" 
            case "voice": return "Voice recording"
            case "link": return "Link captured"
            case "text": return "Text content"
            default: return "Content captured"
            }
        }
    }
    
    private func moveItem() {
        withAnimation {
            item.bucket = selectedBucket.rawValue
            item.isProcessed = selectedBucket != .inbox
            item.updatedAt = Date()
            
            dataController.save()
            dismiss()
        }
    }
}

// MARK: - Bucket Items View
struct BucketItemsView: View {
    @Environment(\.dismiss) private var dismiss
    let bucket: Bucket
    @Binding var selectedItemForCategorization: StashItem?
    
    @FetchRequest private var bucketItems: FetchedResults<StashItem>
    
    init(bucket: Bucket, selectedItemForCategorization: Binding<StashItem?>) {
        self.bucket = bucket
        self._selectedItemForCategorization = selectedItemForCategorization
        
        self._bucketItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
            predicate: NSPredicate(format: "bucket == %@", bucket.systemName ?? ""),
            animation: .default
        )
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if bucketItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: bucket.icon ?? "folder")
                            .font(.system(size: 60))
                            .foregroundColor(bucketColor)
                        
                        Text("\(bucketDisplayName) is Empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Items you categorize here will appear in this bucket")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(bucketItems, id: \.id) { item in
                            BucketItemCard(item: item) {
                                selectedItemForCategorization = item
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(bucketDisplayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var bucketDisplayName: String {
        bucket.customName ?? bucket.systemName?.capitalized ?? "Unknown"
    }
    
    private var bucketColor: Color {
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

struct BucketItemCard: View {
    let item: StashItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Type icon and timestamp
                HStack {
                    Image(systemName: itemTypeIcon)
                        .font(.title3)
                        .foregroundColor(itemTypeColor)
                    
                    Spacer()
                    
                    if let createdAt = item.createdAt {
                        Text(createdAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content preview
                Text(contentPreview)
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                // Status and type
                HStack {
                    Text(item.type?.capitalized ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(itemTypeColor.opacity(0.1))
                        .foregroundColor(itemTypeColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if item.isProcessed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var itemTypeIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemTypeColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return .purple
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var contentPreview: String {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            return ocrText
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot captured"
            case "photo": return "Photo captured" 
            case "voice": return "Voice recording"
            case "link": return "Link captured"
            case "text": return "Text content"
            default: return "Content captured"
            }
        }
    }
}

// MARK: - Updated BucketGridView
struct UpdatedBucketGridView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bucket.createdAt, ascending: true)],
        animation: .default
    ) private var buckets: FetchedResults<Bucket>
    
    @Binding var selectedBucketForEditing: Bucket?
    @Binding var showingInboxView: Bool
    @Binding var selectedBucketForViewing: Bucket?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(buckets, id: \.id) { bucket in
                UpdatedBucketCardView(
                    bucket: bucket,
                    selectedBucketForEditing: $selectedBucketForEditing,
                    showingInboxView: $showingInboxView,
                    selectedBucketForViewing: $selectedBucketForViewing
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

struct UpdatedBucketCardView: View {
    let bucket: Bucket
    @EnvironmentObject var dataController: DataController
    @State private var isPressed = false
    @Binding var selectedBucketForEditing: Bucket?
    @Binding var showingInboxView: Bool
    @Binding var selectedBucketForViewing: Bucket?
    
    @FetchRequest private var items: FetchedResults<StashItem>
    @FetchRequest private var unprocessedItems: FetchedResults<StashItem>
    
    init(bucket: Bucket, selectedBucketForEditing: Binding<Bucket?>, showingInboxView: Binding<Bool>, selectedBucketForViewing: Binding<Bucket?>) {
        self.bucket = bucket
        self._selectedBucketForEditing = selectedBucketForEditing
        self._showingInboxView = showingInboxView
        self._selectedBucketForViewing = selectedBucketForViewing
        
        self._items = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@", bucket.systemName ?? "")
        )
        
        self._unprocessedItems = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "bucket == %@ AND isProcessed == NO", bucket.systemName ?? "")
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .onTapGesture {
            if isInboxBucket {
                showingInboxView = true
            } else {
                selectedBucketForViewing = bucket
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            selectedBucketForEditing = bucket
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressing
            }
        }
    }
    
    private var isInboxBucket: Bool {
        bucket.systemName == "inbox"
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

// MARK: - Input Sheets
struct TextInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @State private var editingText: String = ""
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter your text content")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                TextEditor(text: $editingText)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        text = editingText
                        onSave()
                        dismiss()
                    }
                    .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            editingText = text
        }
    }
}

struct URLInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @State private var editingURL: String = ""
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter URL or paste from clipboard")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                TextField("https://example.com", text: $editingURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                
                Button(action: pasteFromClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        url = editingURL
                        onSave()
                        dismiss()
                    }
                    .disabled(editingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            editingURL = url
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            editingURL = clipboardString
        }
    }
}

struct ImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: (UIImage) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Photo Integration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Photo picker integration coming soon!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    // Simulate photo selection for now
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 40)
                }
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, DataController().container.viewContext)
        .environmentObject(DataController())
}