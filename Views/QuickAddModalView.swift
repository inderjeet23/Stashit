import SwiftUI
import PhotosUI
import UIKit

struct QuickAddModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dataController: DataController
    
    let targetBucket: BucketType
    @State private var selectedType: ItemType? = nil
    @State private var content: String = ""
    @State private var selectedImageData: Data? = nil
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var isLoadingImage = false
    @State private var clipboardContent: String = ""
    @State private var hasClipboardLink = false
    @State private var showingSuccessConfirmation = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        animation: .default)
    private var allItems: FetchedResults<StashItem>
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Target bucket display
                    VStack(spacing: 12) {
                        Text("Adding to")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(targetBucket.emoji)
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(targetBucket.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                let count = bucketItemCount(targetBucket)
                                if count > 0 {
                                    Text("\(count) item\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(targetBucket.color.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(targetBucket.color.opacity(0.3), lineWidth: 2)
                        )
                    }
                    
                    // Capture Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How would you like to add content?")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            CaptureOptionButton(
                                icon: "keyboard",
                                title: "Type Text",
                                subtitle: "Add notes, thoughts, or quick text"
                            ) {
                                selectedType = .text
                            }
                            
                            CaptureOptionButton(
                                icon: "link",
                                title: hasClipboardLink ? "Paste Link" : "Add Link", 
                                subtitle: hasClipboardLink ? clipboardContent : "Add URLs from clipboard or type"
                            ) {
                                selectedType = .link
                                if hasClipboardLink {
                                    content = clipboardContent
                                }
                            }
                            
                            CaptureOptionButton(
                                icon: "camera.fill",
                                title: "Add Photo",
                                subtitle: "Choose from library or camera"
                            ) {
                                selectedType = .photo
                            }
                            
                            CaptureOptionButton(
                                icon: "mic.fill",
                                title: "Voice Note",
                                subtitle: "Record audio or add transcript"
                            ) {
                                selectedType = .voice
                            }
                        }
                    }
                    
                // Content Input
                VStack(alignment: .leading, spacing: 12) {
                    if selectedType == nil {
                        Text("Choose a content type to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // For text/link/voice input
                    if let st = selectedType, st == .text || st == .link || st == .voice {
                        TextField(st.placeholder, text: $content, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                            .onAppear {
                                // Auto-focus for instant keyboard
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                    }

                    // For photo/screenshot input, show a picker and preview
                    if selectedType == .photo {
                        PhotosPicker(selection: $photoPickerItem, matching: .images, preferredItemEncoding: .automatic) {
                            HStack {
                                Image(systemName: "photo.fill.on.rectangle.fill")
                                Text(isLoadingImage ? "Loading…" : (selectedImageData == nil ? "Choose from Library" : "Replace Photo"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.primaryAction)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isLoadingImage)

                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                        dismiss()
                    }
                    .foregroundColor(canAdd ? DesignSystem.accent(colorScheme) : .gray)
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
        .onChange(of: photoPickerItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer { isLoadingImage = false }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedImageData = data
                        if content.isEmpty { content = "Photo selected" }
                    }
                }
            }
        }
        .onAppear {
            checkClipboard()
        }
        .overlay(
            // Success confirmation overlay
            Group {
                if showingSuccessConfirmation {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            VStack(spacing: 4) {
                                Text("Added!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Added to \(targetBucket.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        .scaleEffect(showingSuccessConfirmation ? 1.0 : 0.8)
                        .opacity(showingSuccessConfirmation ? 1.0 : 0.0)
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    private func addItem() {
        withAnimation {
            guard let selectedType else { return }
            let newItem = StashItem(context: viewContext)
            newItem.id = UUID()
            newItem.type = selectedType.rawValue
            newItem.bucket = targetBucket.rawValue
            newItem.createdAt = Date()
            newItem.updatedAt = Date()
            newItem.isProcessed = targetBucket != .inbox
            newItem.userCorrectedBucket = targetBucket != .inbox
            newItem.confidence = 0.0
            
            if !content.isEmpty {
                switch selectedType {
                case .text:
                    newItem.ocrText = content
                case .link:
                    newItem.url = content
                case .photo:
                    newItem.ocrText = content
                case .voice:
                    newItem.ocrText = content
                }
            }

            if let imageData = selectedImageData, selectedType == .photo {
                newItem.content = imageData
            }
            
            dataController.save()
        }
        
        // Show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSuccessConfirmation = true
        }
        
        // Auto-dismiss after showing success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private var canAdd: Bool {
        guard let st = selectedType else { return false }
        switch st {
        case .text:
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .link:
            return URL(string: content) != nil
        case .photo:
            return selectedImageData != nil
        case .voice:
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func checkClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            if URL(string: trimmed) != nil {
                clipboardContent = trimmed
                hasClipboardLink = true
            }
        }
    }
    
    private func bucketItemCount(_ bucket: BucketType) -> Int {
        return allItems.filter { $0.bucket == bucket.rawValue }.count
    }
    
    private func detectContentType(from text: String) -> ItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a URL
        if URL(string: trimmed) != nil {
            return .link
        }
        
        // Default to text for everything else
        return .text
    }
}

// MARK: - Supporting Views
struct QuickTypeButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let type: ItemType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            let accentColor = DesignSystem.accent(colorScheme)
            VStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(type.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - New Capture Option Button
struct CaptureOptionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            let accentColor = DesignSystem.accent(colorScheme)
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    // Use explicit enum to avoid inference issues in previews
    QuickAddModalView(targetBucket: BucketType.work)
        .environmentObject(DataController())
}
