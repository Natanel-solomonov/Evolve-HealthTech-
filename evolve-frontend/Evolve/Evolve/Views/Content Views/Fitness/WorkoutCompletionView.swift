import SwiftUI

struct WorkoutCompletionView: View {
    var onFinish: () -> Void
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color("Fitness"), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()

                // Icon and Text
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(theme.primaryText)

                    Text("Workout Complete")
                        .font(.system(size: 34))
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)

                }
                
                Spacer()
                Spacer()

                // Finish Button
                Button(action: onFinish) {
                    Text("Finish")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(theme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(theme.primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
}

struct WorkoutCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Legacy Theme")
            WorkoutCompletionView(onFinish: {})
                .liquidGlassTheme()
            
            Text("Liquid Glass Theme")
        WorkoutCompletionView(onFinish: {})
                .environment(\.theme, LiquidGlassTheme())
        }
    }
} 