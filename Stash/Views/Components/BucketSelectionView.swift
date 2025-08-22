import SwiftUI

struct BucketSelectionView: View {
    @Binding var selectedBucket: BucketType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bucket")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(BucketType.allCases) { bucket in
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

#Preview {
    BucketSelectionView(selectedBucket: .constant(.inbox))
        .padding()
}