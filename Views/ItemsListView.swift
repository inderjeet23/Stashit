import SwiftUI
import CoreData

struct ItemsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StashItem>
    
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isInSelectionMode = false
    @State private var showingBulkDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.id) { item in
                    SelectableStashItemRow(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id ?? UUID()),
                        isInSelectionMode: isInSelectionMode
                    ) {
                        if isInSelectionMode {
                            toggleSelection(for: item)
                        }
                    }
                }
                .onDelete(perform: isInSelectionMode ? nil : deleteItems)
            }
            .navigationTitle(isInSelectionMode ? "\(selectedItemIDs.count) Selected" : "All Items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isInSelectionMode {
                        Button("Cancel") {
                            exitSelectionMode()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isInSelectionMode {
                        Menu {
                            Button("Select All") {
                                selectAll()
                            }
                            Button("Deselect All") {
                                deselectAll()
                            }
                        } label: {
                            Text("Select")
                                .fontWeight(.medium)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button("Select") {
                                enterSelectionMode()
                            }
                            .fontWeight(.medium)
                            
                            Menu {
                                Button("Select Multiple Items") {
                                    enterSelectionMode()
                                }
                                Button("Edit Mode") {
                                    // Keep the existing edit functionality - this can be expanded later
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if isInSelectionMode && !selectedItemIDs.isEmpty {
                    SelectionToolbar(
                        selectedCount: selectedItemIDs.count,
                        onDelete: {
                            showingBulkDeleteAlert = true
                        },
                        onMove: { bucket in
                            bulkMoveToBucket(bucket)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert("Delete Items", isPresented: $showingBulkDeleteAlert) {
                Button("Delete", role: .destructive) {
                    bulkDeleteSelected()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \(selectedItemIDs.count) item(s)? This action cannot be undone.")
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            dataController.save()
        }
    }
    
    // MARK: - Selection Mode Functions
    private func enterSelectionMode() {
        withAnimation {
            isInSelectionMode = true
            selectedItemIDs.removeAll()
        }
    }
    
    private func exitSelectionMode() {
        withAnimation {
            isInSelectionMode = false
            selectedItemIDs.removeAll()
        }
    }
    
    private func toggleSelection(for item: StashItem) {
        withAnimation {
            guard let itemID = item.id else { return }
            if selectedItemIDs.contains(itemID) {
                selectedItemIDs.remove(itemID)
            } else {
                selectedItemIDs.insert(itemID)
            }
        }
    }
    
    private func selectAll() {
        withAnimation {
            selectedItemIDs = Set(items.compactMap { $0.id })
        }
    }
    
    private func deselectAll() {
        withAnimation {
            selectedItemIDs.removeAll()
        }
    }
    
    private var selectedItems: [StashItem] {
        return items.filter { item in
            guard let itemID = item.id else { return false }
            return selectedItemIDs.contains(itemID)
        }
    }
    
    private func bulkDeleteSelected() {
        withAnimation {
            selectedItems.forEach { item in
                viewContext.delete(item)
            }
            dataController.save()
            selectedItemIDs.removeAll()
        }
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        // Exit selection mode after deletion
        exitSelectionMode()
    }
    
    private func bulkMoveToBucket(_ bucket: BucketType) {
        withAnimation {
            selectedItems.forEach { item in
                item.bucket = bucket.rawValue
                item.isProcessed = bucket != .inbox
                item.updatedAt = Date()
            }
            dataController.save()
        }
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        // Exit selection mode after moving
        exitSelectionMode()
    }
}

// MARK: - Supporting Components

struct SelectableStashItemRow: View {
    let item: StashItem
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isInSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                    .onTapGesture {
                        onTap()
                    }
            }
            
            // Item content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Type icon
                    Image(systemName: itemIcon)
                        .foregroundColor(itemColor)
                        .frame(width: 20)
                    
                    // Title/Content preview
                    Text(itemTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Bucket badge
                    Text(item.bucket?.capitalized ?? "Inbox")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(bucketColor.opacity(0.1))
                        .foregroundColor(bucketColor)
                        .clipShape(Capsule())
                }
                
                // Secondary info
                if let preview = contentPreview {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Timestamp
                if let createdAt = item.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isInSelectionMode {
                onTap()
            } else {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            ItemDetailView(item: item)
        }
    }
    
    private var itemIcon: String {
        switch item.type {
        case "screenshot": return "camera.viewfinder"
        case "link": return "link"
        case "voice": return "waveform"
        case "text": return "text.alignleft"
        case "photo": return "photo"
        default: return "doc"
        }
    }
    
    private var itemColor: Color {
        switch item.type {
        case "screenshot": return .blue
        case "link": return .purple
        case "voice": return .orange
        case "text": return .green
        case "photo": return .red
        default: return .gray
        }
    }
    
    private var bucketColor: Color {
        switch item.bucket {
        case "work": return .blue
        case "shopping": return .green
        case "ideas": return .orange
        case "personal": return .purple
        case "inbox": return .gray
        default: return .gray
        }
    }
    
    private var itemTitle: String {
        if let text = item.ocrText, !text.isEmpty {
            return String(text.prefix(50))
        } else if let url = item.url, !url.isEmpty {
            return url
        } else {
            switch item.type {
            case "screenshot": return "Screenshot"
            case "photo": return "Photo"
            case "voice": return "Voice Recording"
            case "link": return "Link"
            case "text": return "Text Note"
            default: return "Item"
            }
        }
    }
    
    private var contentPreview: String? {
        if let text = item.ocrText, !text.isEmpty, text.count > 50 {
            return String(text.prefix(100))
        } else if let url = item.url, !url.isEmpty {
            return url
        }
        return nil
    }
}

struct SelectionToolbar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onMove: (BucketType) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Delete button
            Button(action: onDelete) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Delete (\(selectedCount))")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Move to bucket menu
            Menu {
                ForEach(BucketType.allCases, id: \.self) { bucket in
                    Button(action: { onMove(bucket) }) {
                        HStack {
                            Text(bucket.emoji)
                            Text(bucket.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text("Move")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

#Preview {
    ItemsListView()
        .environmentObject(DataController())
}