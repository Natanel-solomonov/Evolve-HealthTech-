import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = LegacyTheme()
}

extension EnvironmentValues {
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func liquidGlassTheme() -> some View {
        modifier(LiquidGlassThemeModifier())
    }
}

private struct LiquidGlassThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Runtime check for iOS version
        if isIOS26OrLater() {
            content.environment(\.theme, LiquidGlassTheme())
        } else {
            content.environment(\.theme, LegacyTheme())
        }
    }
    
    /// Runtime check to determine if the device is running iOS 26.0 or later
    private func isIOS26OrLater() -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 26
    }
}

extension Shape {
    @ViewBuilder
    func themedFill(_ style: ThemeBackgroundStyle) -> some View {
        if let material = style.material {
            self.fill(material)
        } else {
            self.fill(style.color)
        }
    }
} 