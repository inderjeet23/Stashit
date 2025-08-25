import SwiftUI
import UIKit

enum RecentGroupType: String { case link, text, photo, voice }

struct RecentGroup: Identifiable {
    let id = UUID()
    let type: RecentGroupType
    let items: [StashItem]
}

func collapseByType(_ items: [StashItem]) -> [RecentGroup] {
    // Limit to 12 most recent items first to keep grouping cheap
    let first12 = Array(items.prefix(12))

    // Build groups explicitly to avoid type-checker blowups
    var buckets: [RecentGroupType: [StashItem]] = [:]
    for item in first12 {
        let key: RecentGroupType
        switch item.type ?? "" {
        case "link": key = .link
        case "voice": key = .voice
        case "photo", "screenshot": key = .photo
        default: key = .text
        }
        buckets[key, default: []].append(item)
    }

    // Map into RecentGroup with items sorted newest-first
    var groups: [RecentGroup] = []
    groups.reserveCapacity(buckets.count)
    for (key, value) in buckets {
        let sorted = value.sorted { (a, b) in
            let ad = a.createdAt ?? .distantPast
            let bd = b.createdAt ?? .distantPast
            return ad > bd
        }
        groups.append(RecentGroup(type: key, items: sorted))
    }

    // Sort groups by their most-recent item and trim to 3
    groups.sort { lhs, rhs in
        let l = lhs.items.first?.createdAt ?? .distantPast
        let r = rhs.items.first?.createdAt ?? .distantPast
        return l > r
    }
    if groups.count > 3 { return Array(groups.prefix(3)) }
    return groups
}

struct RecentlyAddedCarousel: View {
  @Environment(\.colorScheme) private var colorScheme
  let groups: [RecentGroup]
  let onOpen: (RecentGroup) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: UI.gapM) {
        ForEach(groups) { group in
          Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpen(group)
          } label: {
            ZStack(alignment: .topTrailing) {
              // Base gradient background
              RoundedRectangle(cornerRadius: UI.corner, style: .continuous)
                .fill(gradientFor(type: group.type))

              // Content preview centered above background
              preview(for: group)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
              // Count badge (top-right) when more than one
              if group.items.count > 1 {
                Text("\(group.items.count) items")
                  .font(.system(size: 12, weight: .semibold))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 3)
                  .foregroundColor(.white)
                  .background(Color.black.opacity(0.75))
                  .clipShape(Capsule())
                  .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
                  .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                  .padding(8)
              }
              // Type chip (bottom-left) for clarity
              VStack { Spacer() }
                .overlay(alignment: .bottomLeading) {
                  Text(title(for: group.type))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: UI.corner, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: UI.corner, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Recently added. \(title(for: group.type)). \(group.items.count) items.")
        }
      }
      .padding(.horizontal, UI.inset)
    }
  }

  @ViewBuilder private func preview(for group: RecentGroup) -> some View {
    if let first = group.items.first, let data = first.content, let ui = UIImage(data: data), group.type == .photo {
      ZStack {
        Image(uiImage: ui)
          .resizable()
          .scaledToFill()
          .clipped()
        // Subtle gradient overlay for readability and polish
        LinearGradient(
          gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)]),
          startPoint: .top,
          endPoint: .bottom
        )
      }
    } else {
      // Non-photo: single bold icon above label (for voice, only one bold waveform)
      VStack(spacing: 8) {
        Image(systemName: iconName(group.type))
          .font(.system(size: 22, weight: .bold))
        Text(title(for: group.type))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func gradientFor(type: RecentGroupType) -> LinearGradient {
    switch type {
    case .photo:
      return LinearGradient(colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .voice:
      return LinearGradient(colors: [DesignSystem.accent(colorScheme).opacity(0.35), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .link:
      return LinearGradient(colors: [Color.blue.opacity(0.35), Color.teal.opacity(0.25)], startPoint: .top, endPoint: .bottom)
    case .text:
      return LinearGradient(colors: [Color.green.opacity(0.3), Color.mint.opacity(0.25)], startPoint: .top, endPoint: .bottomTrailing)
    }
  }

  private func iconName(_ t: RecentGroupType) -> String {
    switch t { case .link: return "link"; case .text: return "text.alignleft"; case .photo: return "photo"; case .voice: return "waveform" }
  }
  private func title(for t: RecentGroupType) -> String {
    switch t { case .link: return "Link"; case .text: return "Text"; case .photo: return "Photo"; case .voice: return "Voice" }
  }
}
