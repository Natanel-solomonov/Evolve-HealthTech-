import SwiftUI

struct ComingSoonView: View {
    @Environment(\.theme) private var theme: any Theme
    var body: some View {
        VStack {
            Text("Coming Soon")
                .font(.system(size: 34))
                .foregroundColor(theme.secondaryText)
        }
    }
}

struct ComingSoonView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Legacy Theme")
            ComingSoonView()
                .liquidGlassTheme()
            
            Text("Liquid Glass Theme")
        ComingSoonView()
                .environment(\.theme, LiquidGlassTheme())
        }
    }
} 
