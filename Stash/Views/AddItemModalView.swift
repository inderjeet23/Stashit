import SwiftUI
import CoreData

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
                    // Content Type Selection
                    TypeSelectionView(selectedType: $selectedType)
                    
                    // Content Input Area
                    ContentInputView(selectedType: selectedType, content: $content)
                    
                    // Bucket Selection
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
    
    private var canAdd: Bool {
        // For now, always allow adding. Later we can add validation
        true
    }
    
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
            
            // Add content if available
            if !content.isEmpty {
                // For text content, we can store it directly
                // For other types, this will be expanded later
                if selectedType == .text {
                    newItem.ocrText = content
                }
            }
            
            dataController.save()
        }
    }
}

#Preview {
    AddItemModalView()
        .environmentObject(DataController())
}