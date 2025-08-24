import SwiftUI

// MARK: - New Style Structs
struct ThemeBackgroundStyle {
    let color: Color
    let material: Material?
}

// MARK: - Theme Protocol
protocol Theme {
    // MARK: - Colors
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var accent: Color { get }
    var background: Color { get }

    // MARK: - Styles
    var cardStyle: ThemeBackgroundStyle { get }
    var translucentCardStyle: ThemeBackgroundStyle { get }

    // MARK: - Materials
    var navigationBarMaterial: Material { get }

    // MARK: - Fonts
    var headlineFont: Font { get }
    var bodyFont: Font { get }
    var captionFont: Font { get }

    // MARK: - Corner Radii
    var componentRadius: CGFloat { get }

    // MARK: - Shadows
    var defaultShadow: ShadowStyle { get }

    // MARK: - Specific Component Styles
    func tabStyle(isSelected: Bool) -> TabStyle
    var maxInputButtonGradient: LinearGradient { get }
    
    // MARK: - Button Styles
    @ViewBuilder
    func closeButtonBackground() -> AnyView
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct TabStyle {
    let iconColor: Color
    let textColor: Color
    let iconFontWeight: Font.Weight
    let textFontWeight: Font.Weight
    let backgroundFill: AnyShapeStyle
    let iconVariant: SymbolVariants
}


// MARK: - Legacy Theme
struct LegacyTheme: Theme {
    // MARK: - Colors
    let primaryText: Color = .primary
    let secondaryText: Color = .secondary
    let accent: Color = .accentColor
    let background: Color = Color(red: 254/255, green: 1.0, blue: 1.0)

    // MARK: - Styles
    let cardStyle = ThemeBackgroundStyle(color: Color(uiColor: .systemBackground), material: nil)
    let translucentCardStyle = ThemeBackgroundStyle(color: .white.opacity(0.95), material: nil)

    // MARK: - Materials
    let navigationBarMaterial: Material = .ultraThinMaterial

    // MARK: - Fonts
    let headlineFont: Font = .headline
    let bodyFont: Font = .body
    let captionFont: Font = .caption

    // MARK: - Corner Radii
    let componentRadius: CGFloat = 999 // For capsules

    // MARK: - Shadows
    let defaultShadow = ShadowStyle(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

    // MARK: - Specific Component Styles
    func tabStyle(isSelected: Bool) -> TabStyle {
        if isSelected {
            return TabStyle(
                iconColor: .white,
                textColor: .white,
                iconFontWeight: .regular,
                textFontWeight: .regular,
                backgroundFill: AnyShapeStyle(Color.black.opacity(0.3)),
                iconVariant: .none
            )
        } else {
            return TabStyle(
                iconColor: .primary,
                textColor: .primary,
                iconFontWeight: .regular,
                textFontWeight: .regular,
                backgroundFill: AnyShapeStyle(Color.clear),
                iconVariant: .none
            )
        }
    }

    var maxInputButtonGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color("Sleep"), Color("Fitness")]),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

        // MARK: - Button Styles
    @ViewBuilder
    func closeButtonBackground() -> AnyView {
        AnyView(
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.05))
                )
                .frame(width: 36, height: 36)
        )
    }
} 

// MARK: - Liquid Glass Theme
struct LiquidGlassTheme: Theme {
    // MARK: - Colors
    let primaryText: Color = .primary
    let secondaryText: Color = .secondary
    let accent: Color = .accentColor
    let background: Color = Color(red: 254/255, green: 1.0, blue: 1.0)
    
    // MARK: - Styles
    let cardStyle = ThemeBackgroundStyle(color: .clear, material: .regularMaterial)
    let translucentCardStyle = ThemeBackgroundStyle(color: .clear, material: .regularMaterial)
    
    // MARK: - Materials
    let navigationBarMaterial: Material = .regularMaterial
    
    // MARK: - Fonts
    let headlineFont: Font = .headline
    let bodyFont: Font = .body
    let captionFont: Font = .caption
    
    // MARK: - Corner Radii
    let componentRadius: CGFloat = 999 // For capsules
    
    // MARK: - Shadows
    let defaultShadow = ShadowStyle(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    
    // MARK: - Specific Component Styles
    func tabStyle(isSelected: Bool) -> TabStyle {
        if isSelected {
            let gradient = LinearGradient(
                gradient: Gradient(colors: [Color("Fitness").opacity(0.8), Color("Mind").opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            return TabStyle(
                iconColor: .white,
                textColor: .white,
                iconFontWeight: .regular,
                textFontWeight: .bold,
                backgroundFill: AnyShapeStyle(gradient),
                iconVariant: .fill
            )
        } else {
            return TabStyle(
                iconColor: .secondary,
                textColor: .secondary,
                iconFontWeight: .regular,
                textFontWeight: .regular,
                backgroundFill: AnyShapeStyle(Color.clear),
                iconVariant: .none
            )
        }
    }
    
    var maxInputButtonGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color("Sleep"), Color("Fitness")]),
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
    
    // MARK: - Button Styles
    @ViewBuilder
    func closeButtonBackground() -> AnyView {
        AnyView(Color.clear)
    }
}
