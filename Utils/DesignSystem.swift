import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 20
    static let animationDuration: Double = 0.3
    static let primaryAction: Color = .blue
    static let successColor: Color = .green
    static let pendingColor: Color = .orange
    
    /// Dynamic accent color that works in both light and dark modes
    static func accent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color(red: 69/255, green: 131/255, blue: 233/255) // #4583E9 - Notion's bright blue accent
            : Color.black // Black accent for light mode
    }
    
    /// Button background colors
    static func buttonBackground(_ colorScheme: ColorScheme, isSecondary: Bool = false) -> Color {
        if isSecondary {
            return colorScheme == .dark 
                ? Color(red: 55/255, green: 60/255, blue: 63/255) // #373C3F - Notion's divider color for secondary buttons
                : Color(.systemGray5)
        } else {
            return colorScheme == .dark 
                ? Color(red: 69/255, green: 131/255, blue: 233/255) // #4583E9 - Notion's blue for primary buttons
                : Color.black // Primary button is black in light mode
        }
    }
    
    /// Button text colors
    static func buttonText(_ colorScheme: ColorScheme, isSecondary: Bool = false) -> Color {
        if isSecondary {
            return colorScheme == .dark 
                ? Color.white.opacity(0.87) // Notion's soft white text for secondary buttons
                : Color.primary
        } else {
            return colorScheme == .dark 
                ? Color.white // White text on blue button in dark mode
                : Color.white // White text on black button in light mode
        }
    }
    
    // MARK: - Adaptive Surface Colors (Notion-inspired)
    
    /// Main background - page background
    static func pageBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color(red: 47/255, green: 52/255, blue: 55/255) // #2F3437 - Notion's main page background
            : Color(.systemBackground)
    }
    
    /// Primary card background - elevated surface
    static func cardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color(red: 32/255, green: 35/255, blue: 36/255) // #202324 - Notion's content background
            : Color(.systemBackground)
    }
    
    /// Secondary card background - slightly elevated
    static func secondaryCardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color(red: 55/255, green: 60/255, blue: 63/255) // #373C3F - Notion's dividers/borders
            : Color(.secondarySystemBackground)
    }
    
    /// Enhanced text color for better contrast
    static func primaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.87) // #FFFFFF at ~87% opacity - Notion's soft white text
            : Color.primary
    }
    
    /// Secondary text color
    static func secondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color(red: 179/255, green: 179/255, blue: 179/255) // #B3B3B3 - Notion's secondary text
            : Color.secondary
    }
    
    /// Tinted card background for category cards
    static func tintedCardBackground(_ color: Color, _ colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            // Layer the tint over the card background for dark mode
            return color.opacity(0.08)
        } else {
            // Light mode uses existing tinted background
            return color.opacity(0.1)
        }
    }
    
    /// Enhanced icon color for better dark mode visibility
    static func enhancedIconColor(_ color: Color, _ colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            // Brighten the color for dark mode
            return color.opacity(0.9)
        } else {
            return color
        }
    }
    
    // MARK: - Adaptive Shadows
    
    /// Adaptive shadow color based on color scheme (Notion-style)
    static func shadowColor(_ colorScheme: ColorScheme, intensity: Double = 0.15) -> Color {
        colorScheme == .dark 
            ? Color.black.opacity(intensity * 1.5) // Deeper black shadows in dark mode for more definition
            : Color.black.opacity(intensity)       // Black shadows in light mode
    }
}

// MARK: - View Extensions for Adaptive Shadows

extension View {
    /// Light shadow for subtle depth (cards, list items)
    func adaptiveLightShadow(_ colorScheme: ColorScheme) -> some View {
        shadow(
            color: DesignSystem.shadowColor(colorScheme, intensity: 0.05),
            radius: 2, x: 0, y: 1
        )
    }
    
    /// Medium shadow for prominent elements (floating buttons, modals)
    func adaptiveMediumShadow(_ colorScheme: ColorScheme) -> some View {
        shadow(
            color: DesignSystem.shadowColor(colorScheme, intensity: 0.15),
            radius: 8, x: 0, y: 4
        )
    }
    
    /// Strong shadow for hero elements (main CTAs)
    func adaptiveStrongShadow(_ colorScheme: ColorScheme) -> some View {
        shadow(
            color: DesignSystem.shadowColor(colorScheme, intensity: 0.20),
            radius: 12, x: 0, y: 6
        )
    }
    
    /// Colored shadow for selected/active states
    func adaptiveColoredShadow(_ color: Color, _ colorScheme: ColorScheme, isActive: Bool = true) -> some View {
        shadow(
            color: isActive ? color.opacity(colorScheme == .dark ? 0.4 : 0.25) : .clear,
            radius: isActive ? 8 : 0, 
            x: 0, 
            y: isActive ? 4 : 0
        )
    }
}
