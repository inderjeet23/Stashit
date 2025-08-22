import SwiftUI

struct ContentInputView: View {
    let selectedType: ItemType
    @Binding var content: String
    
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
            
            // Show content preview if available
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
    }
    
    private func handleContentInput() {
        switch selectedType {
        case .text:
            // For now, add placeholder text. Later this would open a text input view
            content = "Sample text content"
        case .screenshot:
            // Later: integrate with screenshot capture
            content = "Screenshot captured"
        case .photo:
            // Later: integrate with photo picker
            content = "Photo selected"
        case .link:
            // Later: integrate with link input or clipboard
            content = "https://example.com"
        case .voice:
            // Later: integrate with voice recorder
            content = "Voice recording captured"
        }
    }
}

#Preview {
    ContentInputView(selectedType: .text, content: .constant(""))
        .padding()
}