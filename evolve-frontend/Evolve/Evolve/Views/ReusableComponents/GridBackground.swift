import SwiftUI

private struct GridPattern: View {
    let gridSize: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }

            for y in stride(from: 0, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
    }
}

struct GridBackground: View {
    @Environment(\.theme) private var theme: any Theme
    var body: some View {
        ZStack {
            theme.background
                .shadow(color: Color.black.opacity(1), radius: 1, x: 0, y: 0)
            
            // Slight darkening overlay
            Color.black.opacity(0.03)
            
            GridPattern(gridSize: 30, color: Color.gray.opacity(0.15))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview
struct GridBackground_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light theme preview
            GridBackground()
                .environment(\.theme, LiquidGlassTheme())
                .previewDisplayName("Light Theme")
            
            // With overlay content to show grid visibility
            ZStack {
                GridBackground()
                
                VStack(spacing: 20) {
                    Text("Grid Background Preview")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 200, height: 100)
                        .shadow(radius: 5)
                        .overlay(
                            Text("Sample Card")
                                .font(.headline)
                        )
                }
            }
            .environment(\.theme, LiquidGlassTheme())
            .previewDisplayName("With Content")
        }
    }
} 
