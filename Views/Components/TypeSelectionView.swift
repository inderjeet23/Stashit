import SwiftUI

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
                        TypeSelectionButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
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
                    .fill(isSelected ? DesignSystem.accent : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DesignSystem.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    TypeSelectionView(selectedType: .constant(.photo))
        .padding()
}
