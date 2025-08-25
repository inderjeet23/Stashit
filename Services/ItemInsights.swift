import Foundation
import UIKit

enum ItemInsights {
    static func smartDescription(for item: StashItem) -> String {
        // Prefer OCR text if available
        if let text = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            // Heuristics
            if text.localizedCaseInsensitiveContains("recipe") {
                return "Recipe you saved"
            }
            if text.localizedCaseInsensitiveContains("stars") || text.localizedCaseInsensitiveContains("review") {
                return "Something highly rated"
            }
            if text.count > 80 {
                let prefix = String(text.prefix(80))
                return "\(prefix)…"
            }
            return text
        }

        // URL-based heuristics
        if let urlString = item.url, let url = URL(string: urlString) {
            let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.host ?? ""
            if host.contains("amazon") { return "Product you're considering" }
            if host.contains("youtube") || host.contains("youtu.be") { return "Video to watch later" }
            if host.contains("twitter") || host.contains("x.com") { return "Post to revisit" }
            if host.contains("slack") { return "From your Slack research" }
            if host.contains("notion") { return "Notion page you saved" }
            return "Link from \(host)"
        }

        // Type-based fallback
        switch item.type {
        case "screenshot": return "That thing you screenshotted"
        case "photo": return "Photo you captured"
        case "voice": return "Voice note"
        case "link": return "Saved link"
        case "text": return "Quick note"
        default: return "Captured item"
        }
    }

    static func dashboardSummary(from items: [StashItem]) -> String {
        guard !items.isEmpty else { return "" }
        // Group by bucket (or infer from type if inbox)
        var ideas = 0, shopping = 0, work = 0, personal = 0
        for i in items {
            let bucket = i.bucket ?? "inbox"
            switch bucket {
            case "ideas": ideas += 1
            case "shopping": shopping += 1
            case "work": work += 1
            case "personal": personal += 1
            default:
                // Infer inbox items
                switch i.type {
                case "text": ideas += 1
                case "link": work += 1
                case "photo", "screenshot": personal += 1
                default: break
                }
            }
        }
        var parts: [String] = []
        if ideas > 0 { parts.append("💡 \(ideas) ideas") }
        if shopping > 0 { parts.append("🛒 \(shopping) to consider") }
        if work > 0 { parts.append("💼 \(work) work refs") }
        if personal > 0 { parts.append("👤 \(personal) personal") }
        return parts.prefix(3).joined(separator: ", ")
    }

    static func sourceApp(for item: StashItem) -> String? {
        guard let urlString = item.url, let url = URL(string: urlString) else { return nil }
        let host = (url.host ?? "").replacingOccurrences(of: "www.", with: "")
        if host.contains("slack") { return "Slack" }
        if host.contains("amazon") { return "Amazon" }
        if host.contains("youtube") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("notion") { return "Notion" }
        if host.contains("twitter") || host.contains("x.com") { return "Twitter" }
        if host.contains("github") { return "GitHub" }
        if host.contains("calendar") || host.contains("google.com/calendar") { return "Calendar" }
        if host.contains("docs.google") { return "Google Docs" }
        if host.contains("apple.com") { return "Apple" }
        if !host.isEmpty { return host }
        return nil
    }

    static func softCaption(for item: StashItem) -> String? {
        guard let created = item.createdAt else { return nil }
        let time = created.formatted(date: .omitted, time: .shortened)
        if let app = sourceApp(for: item) {
            return "From \(app) at \(time)"
        }
        return "\(time)"
    }

    static func tags(for item: StashItem) -> [String] {
        var tags: [String] = []
        let text = (item.ocrText ?? "") + " " + (item.url ?? "")
        let lower = text.lowercased()
        if lower.contains("recipe") { tags.append("Recipe") }
        if lower.contains("star") || lower.contains("rating") { tags.append("Rating") }
        if lower.contains("calendar") || lower.contains("schedule") { tags.append("Calendar") }
        if lower.contains("ai") || lower.contains("gpt") || lower.contains("llm") { tags.append("AI") }
        if lower.contains("doc") || lower.contains("notion") || lower.contains("docs.google") { tags.append("Doc") }

        if let urlString = item.url, let url = URL(string: urlString) {
            let host = (url.host ?? "")
            if host.contains("amazon") { tags.append("Product") }
            if host.contains("youtube") || host.contains("youtu.be") { tags.append("Video") }
        }
        // Dedup and cap at 3
        var seen = Set<String>()
        let unique = tags.filter { seen.insert($0).inserted }
        return Array(unique.prefix(3))
    }

    static func hint(for item: StashItem) -> String? {
        if let urlString = item.url, let url = URL(string: urlString) {
            let host = (url.host ?? "")
            if host.contains("amazon") { return "Price may change soon" }
            if host.contains("youtube") || host.contains("youtu.be") { return "Watch later" }
        }
        return nil
    }
}
