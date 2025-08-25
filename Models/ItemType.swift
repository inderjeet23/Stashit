import Foundation

enum ItemType: String, CaseIterable, Identifiable {
    case link = "link"
    case voice = "voice"
    case text = "text"
    case photo = "photo"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .link:
            return "Link"
        case .voice:
            return "Voice"
        case .text:
            return "Text"
        case .photo:
            return "Photo"
        }
    }
    
    var systemImage: String {
        switch self {
        case .link:
            return "link"
        case .voice:
            return "waveform"
        case .text:
            return "text.alignleft"
        case .photo:
            return "photo"
        }
    }
    
    var placeholder: String {
        switch self {
        case .link:
            return "Tap to add link"
        case .voice:
            return "Tap to record voice"
        case .text:
            return "Tap to add text"
        case .photo:
            return "Tap to add photo"
        }
    }
    
    var shortName: String {
        switch self {
        case .link:
            return "Link"
        case .voice:
            return "Voice"
        case .text:
            return "Text"
        case .photo:
            return "Photo"
        }
    }
}
