import SwiftUI

// MARK: - Cinematic Animation Modifiers

/// A view modifier that applies the cinematic background effect (blur + scale)
/// when the app is presenting a cinematic overlay
private struct CinematicBackgroundModifier: ViewModifier {
    let isActive: Bool
    let blurRadius: CGFloat
    let scaleAmount: CGFloat
    let animationDuration: Double
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? blurRadius : 0)
            .scaleEffect(isActive ? scaleAmount : 1)
            .animation(.easeInOut(duration: animationDuration), value: isActive)
            .disabled(isActive)
    }
}

/// A view modifier that applies the cinematic overlay transition
/// (scale in from 0.8, scale out to 1.2 with opacity)
private struct CinematicOverlayModifier: ViewModifier {
    let insertionScale: CGFloat
    let removalScale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: insertionScale).combined(with: .opacity),
                removal: .scale(scale: removalScale).combined(with: .opacity)
            ))
            .zIndex(1) // Ensure overlay is on top
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the cinematic background effect when presenting overlays
    /// - Parameters:
    ///   - isActive: Whether the cinematic effect should be active
    ///   - blurRadius: The blur radius to apply (default: 10)
    ///   - scaleAmount: The scale factor to apply (default: 0.95)
    ///   - animationDuration: The animation duration (default: 0.3)
    func cinematicBackground(
        isActive: Bool,
        blurRadius: CGFloat = 10,
        scaleAmount: CGFloat = 0.95,
        animationDuration: Double = 0.3
    ) -> some View {
        modifier(CinematicBackgroundModifier(
            isActive: isActive,
            blurRadius: blurRadius,
            scaleAmount: scaleAmount,
            animationDuration: animationDuration
        ))
    }
    
    /// Applies the cinematic overlay transition effect
    /// - Parameters:
    ///   - insertionScale: The scale factor when appearing (default: 0.8)
    ///   - removalScale: The scale factor when disappearing (default: 1.2)
    func cinematicOverlay(
        insertionScale: CGFloat = 0.8,
        removalScale: CGFloat = 1.2
    ) -> some View {
        modifier(CinematicOverlayModifier(
            insertionScale: insertionScale,
            removalScale: removalScale
        ))
    }
}

// MARK: - Cinematic Container

/// A container view that manages cinematic presentation of content
/// Handles both the background effects and overlay presentation
struct CinematicContainer<Background: View, Overlay: View>: View {
    let background: Background
    let overlay: Overlay?
    let isPresented: Bool
    let animationDuration: Double
    
    init(
        isPresented: Bool,
        animationDuration: Double = 0.3,
        @ViewBuilder background: () -> Background,
        @ViewBuilder overlay: () -> Overlay?
    ) {
        self.isPresented = isPresented
        self.animationDuration = animationDuration
        self.background = background()
        self.overlay = overlay()
    }
    
    var body: some View {
        ZStack {
            // Background content with cinematic effect
            background
                .cinematicBackground(isActive: isPresented)
            
            // Overlay content with cinematic transition
            if let overlay = overlay {
                overlay
                    .cinematicOverlay()
            }
        }
    }
}

// MARK: - Cinematic State Manager

/// A class to manage multiple cinematic overlays in a single view
/// Useful when you have multiple different cinematic presentations
@MainActor
class CinematicStateManager: ObservableObject {
    @Published private var activeOverlays: Set<String> = []
    
    /// Check if any cinematic overlay is currently active
    var isAnyActive: Bool {
        !activeOverlays.isEmpty
    }
    
    /// Check if a specific overlay is active
    func isActive(_ overlayId: String) -> Bool {
        activeOverlays.contains(overlayId)
    }
    
    /// Present a cinematic overlay
    func present(_ overlayId: String, withAnimation duration: Double = 0.3) {
        _ = withAnimation(.easeInOut(duration: duration)) {
            activeOverlays.insert(overlayId)
        }
    }
    
    /// Dismiss a cinematic overlay
    func dismiss(_ overlayId: String, withAnimation duration: Double = 0.3) {
        _ = withAnimation(.easeInOut(duration: duration)) {
            activeOverlays.remove(overlayId)
        }
    }
    
    /// Dismiss all cinematic overlays
    func dismissAll(withAnimation duration: Double = 0.3) {
        withAnimation(.easeInOut(duration: duration)) {
            activeOverlays.removeAll()
        }
    }
}

// MARK: - Convenience Extensions for Common Patterns

extension View {
    /// A convenience method that combines background effect with overlay presentation
    /// This replicates the exact pattern used in DashboardView
    func cinematicPresentation<Content: View>(
        isPresented: Bool,
        animationDuration: Double = 0.3,
        @ViewBuilder overlay: @escaping () -> Content
    ) -> some View {
        ZStack {
            // Apply background effect to self
            self.cinematicBackground(
                isActive: isPresented,
                animationDuration: animationDuration
            )
            
            // Show overlay if presented
            if isPresented {
                overlay()
                    .cinematicOverlay()
            }
        }
    }
}

// MARK: - Animation Presets

/// Common animation configurations for different types of presentations
struct CinematicPresets {
    /// Standard cinematic presentation (matches DashboardView)
    static let standard = CinematicConfig(
        blurRadius: 10,
        backgroundScale: 0.95,
        insertionScale: 0.8,
        removalScale: 1.2,
        duration: 0.3
    )
    
    /// Subtle cinematic effect for less dramatic presentations
    static let subtle = CinematicConfig(
        blurRadius: 5,
        backgroundScale: 0.98,
        insertionScale: 0.9,
        removalScale: 1.1,
        duration: 0.25
    )
    
    /// Dramatic cinematic effect for important presentations
    static let dramatic = CinematicConfig(
        blurRadius: 15,
        backgroundScale: 0.9,
        insertionScale: 0.7,
        removalScale: 1.3,
        duration: 0.4
    )
}

/// Configuration struct for cinematic animations
struct CinematicConfig {
    let blurRadius: CGFloat
    let backgroundScale: CGFloat
    let insertionScale: CGFloat
    let removalScale: CGFloat
    let duration: Double
}

extension View {
    /// Apply cinematic effect with a preset configuration
    func cinematicPresentation<Content: View>(
        isPresented: Bool,
        preset: CinematicConfig,
        @ViewBuilder overlay: @escaping () -> Content
    ) -> some View {
        ZStack {
            self.cinematicBackground(
                isActive: isPresented,
                blurRadius: preset.blurRadius,
                scaleAmount: preset.backgroundScale,
                animationDuration: preset.duration
            )
            
            if isPresented {
                overlay()
                    .cinematicOverlay(
                        insertionScale: preset.insertionScale,
                        removalScale: preset.removalScale
                    )
            }
        }
    }
} 