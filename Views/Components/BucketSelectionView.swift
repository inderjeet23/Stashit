import SwiftUI

struct BucketSelectionView: View {
    @Binding var selectedBucket: BucketType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stack")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(BucketType.allCases.filter { $0 != .inbox }) { bucket in
                    BucketSelectionRow(
                        bucket: bucket,
                        isSelected: selectedBucket == bucket
                    ) {
                        selectedBucket = bucket
                    }
                }
            }
        }
    }
}

struct BucketSelectionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let bucket: BucketType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Text(bucket.emoji)
                    .font(.title2)
                
                Text(bucket.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                // Always reserve checkmark space to prevent truncation on select
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(bucket.color)
                    .opacity(isSelected ? 1 : 0)
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
            // Remove scale effect to avoid layout jump that causes truncation
            .adaptiveColoredShadow(bucket.color, colorScheme, isActive: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    BucketSelectionView(selectedBucket: .constant(.inbox))
        .padding()
}
