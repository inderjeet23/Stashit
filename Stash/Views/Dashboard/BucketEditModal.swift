import SwiftUI

struct BucketEditModal: View {
    let bucket: Bucket
    @EnvironmentObject var dataController: DataController
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header with bucket icon
                VStack(spacing: 16) {
                    Image(systemName: bucket.icon ?? "folder")
                        .font(.system(size: 40))
                        .foregroundColor(cardColor)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(cardColor.opacity(0.1))
                        )
                    
                    Text("Edit Bucket Name")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 20)
                
                // Text field for editing
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bucket Name")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter bucket name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            saveBucketName()
                        }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBucketName()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            editedName = bucket.customName ?? bucket.systemName?.capitalized ?? ""
            isTextFieldFocused = true
        }
    }
    
    private func saveBucketName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        // Update the bucket name
        bucket.customName = trimmedName
        dataController.save()
        
        // Haptic feedback for successful save
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        dismiss()
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
    
    return BucketEditModal(bucket: sampleBucket)
        .environmentObject(DataController())
}