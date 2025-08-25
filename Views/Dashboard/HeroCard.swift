import SwiftUI

struct HeroCard: View {
  @Environment(\.colorScheme) private var colorScheme
  let unsorted: Int
  let reviewed: Int
  let streak: Int
  let date: Date
  let onClear: () -> Void

  var body: some View {
    HStack(alignment: .center) {
      // Left: Unsorted count or celebration
      VStack(alignment: .leading, spacing: 4) {
        if unsorted == 0 {
          // Celebration state
          Text("✨")
            .font(.system(size: 32, weight: .bold))
            .scaleEffect(1.1)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: unsorted == 0)
          Text("All Stashed!")
            .font(.caption)
            .foregroundStyle(.green)
            .fontWeight(.semibold)
        } else {
          // Normal count state
          Text("\(unsorted)")
            .font(.system(size: 32, weight: .bold))
          Text("Unstashed")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .animation(.easeInOut(duration: 0.3), value: unsorted)

      Spacer(minLength: UI.gapM)

      // Right: Streak/date (CTA moved near FAB)
      VStack(alignment: .trailing, spacing: UI.gapM) {
        VStack(alignment: .trailing, spacing: 6) {
          Text(date.formatted(.dateTime.weekday(.wide).month().day()))
            .font(.title3)
            .fontWeight(.semibold)
          if streak > 0 {
            Label("\(streak)-day streak", systemImage: "flame.fill")
              .font(.subheadline)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(.thinMaterial)
              .clipShape(Capsule())
          }
        }
      }
      .frame(minWidth: 180, maxHeight: .infinity, alignment: .center)
      .padding(.trailing, UI.gapM)
    }
    .padding(UI.inset)
    .frame(height: UI.heroHeight)
    .background(DesignSystem.cardBackground(colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: UI.corner, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: UI.corner, style: .continuous)
        .stroke(colorScheme == .dark ? Color.white.opacity(0.22) : Color.clear, lineWidth: 1)
    )
    .adaptiveStrongShadow(colorScheme)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(unsorted == 0 ? "All stashed! Everything is organized." : "Unstashed. \(unsorted) items.")
  }
}
