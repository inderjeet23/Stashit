import Foundation
import SwiftUI

enum BucketType: String, CaseIterable, Identifiable {
    case work = "work"
    case shopping = "shopping"
    case ideas = "ideas"
    case personal = "personal"
    case inbox = "inbox"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .work:
            return "Work"
        case .shopping:
            return "Shopping"
        case .ideas:
            return "Ideas"
        case .personal:
            return "Personal"
        case .inbox:
            return "Inbox"
        }
    }
    
    var emoji: String {
        switch self {
        case .work:
            return "💼"
        case .shopping:
            return "🛒"
        case .ideas:
            return "💡"
        case .personal:
            return "👤"
        case .inbox:
            return "📥"
        }
    }
    
    var color: Color {
        switch self {
        case .work:
            return .blue
        case .shopping:
            return .green
        case .ideas:
            return .orange
        case .personal:
            return .purple
        case .inbox:
            return .gray
        }
    }
}