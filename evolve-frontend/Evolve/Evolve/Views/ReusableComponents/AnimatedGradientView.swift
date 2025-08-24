import SwiftUI

struct AnimatedGradientView: View {
    @State private var animate = false

    let colors: [Color] = [
        Color(.systemGray5).opacity(0.8),
        Color(.systemGray3).opacity(0.6),
        Color("Fitness").opacity(0.7),
        .white.opacity(0.5),
        Color("Fitness").opacity(0.5),
        Color(.systemGray4).opacity(0.9)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<colors.count, id: \.self) { index in
                    Blob(
                        color: colors[index],
                        animate: $animate,
                        geometry: geometry,
                        index: index
                    )
                }
            }
            .blur(radius: geometry.size.width / 3)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .aspectRatio(4/1, contentMode: .fill)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
    }
}

private struct Blob: View {
    let color: Color
    @Binding var animate: Bool
    let geometry: GeometryProxy
    let index: Int

    @State private var xOffset: CGFloat
    @State private var yOffset: CGFloat
    @State private var scale: CGFloat
    @State private var rotation: Angle

    init(color: Color, animate: Binding<Bool>, geometry: GeometryProxy, index: Int) {
        self.color = color
        self._animate = animate
        self.geometry = geometry
        self.index = index
        _xOffset = State(initialValue: .random(in: 0...geometry.size.width))
        _yOffset = State(initialValue: .random(in: 0...geometry.size.height))
        _scale = State(initialValue: .random(in: 0.8...1.5))
        _rotation = State(initialValue: .degrees(.random(in: -45...45)))
    }

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .offset(x: xOffset - geometry.size.width / 2, y: yOffset - geometry.size.height / 2)
            .onChange(of: animate) {
                let newX: CGFloat
                if index % 2 == 0 {
                    newX = animate ? geometry.size.width * 1.2 : -geometry.size.width * 0.2
                } else {
                    newX = animate ? -geometry.size.width * 0.2 : geometry.size.width * 1.2
                }
                xOffset = newX
                yOffset = .random(in: 0...geometry.size.height)
                scale = .random(in: 0.8...1.5)
                rotation = .degrees(.random(in: -45...45))
            }
    }
}

struct AnimatedGradientView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedGradientView()
            .frame(height: 200)
            .padding()
            .preferredColorScheme(.light)
    }
} 