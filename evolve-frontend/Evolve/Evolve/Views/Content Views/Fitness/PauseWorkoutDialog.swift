import SwiftUI

struct PauseWorkoutDialog: View {
    var onResume: () -> Void
    var onEnd: () -> Void
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            theme.background.opacity(0.6).edgesIgnoringSafeArea(.all)
                .onTapGesture(perform: onResume) // Resume on tap

            VStack(spacing: 20) {
                Text("Workout Paused")
                    .font(.system(size: 34))
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                    .padding(.bottom, 20)
                
                // Resume Button
                Button(action: onResume) {
                    Text("Resume")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(theme.background)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.primaryText)
                        .cornerRadius(15)
                }
                
                // End Workout Button
                Button(action: onEnd) {
                    Text("End Workout")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(theme.primaryText.opacity(0.8), lineWidth: 2)
                        )
                }
            }
            .padding(30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

struct PauseWorkoutDialog_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Legacy Theme")
            ZStack {
                Color.blue // Background to preview against
                PauseWorkoutDialog(onResume: {}, onEnd: {})
                    .liquidGlassTheme()
            }
            
            Text("Liquid Glass Theme")
        ZStack {
            Color.blue // Background to preview against
            PauseWorkoutDialog(onResume: {}, onEnd: {})
                    .environment(\.theme, LiquidGlassTheme())
            }
        }
    }
} 