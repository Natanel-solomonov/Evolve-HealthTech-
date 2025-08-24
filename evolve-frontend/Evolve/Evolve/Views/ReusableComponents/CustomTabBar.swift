import SwiftUI

struct TabItemData: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

struct CustomTabBar: View {
    @Binding var selectedIndex: Int
    @Binding var isMaxInputActive: Bool
    let tabItems: [TabItemData]
    let onSend: (String) -> Void

    @State private var currentMessage: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.theme) private var theme: any Theme
    
    @Namespace private var tabContainerTransition
    @Namespace private var maxButtonTransition

    var body: some View {
        HStack(spacing: 12) {
            tabBarContainerView
            maxInputView
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onChange(of: isMaxInputActive) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isTextFieldFocused = true
                }
            } else {
                isTextFieldFocused = false
            }
        }
        .onChange(of: isTextFieldFocused) { _, isFocused in
            if !isFocused && isMaxInputActive {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isMaxInputActive = false
                }
            }
        }
    }

    @ViewBuilder
    private var tabBarContainerView: some View {
        if isMaxInputActive {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isMaxInputActive = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 60, height: 60)
            .background(theme.navigationBarMaterial, in: Capsule())
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            .matchedGeometryEffect(id: "tab_container", in: tabContainerTransition)
        } else {
            HStack(spacing: 0) {
                ForEach(tabItems.indices, id: \.self) { index in
                    tabView(item: tabItems[index], index: index)
                }
            }
            .padding(.horizontal, 8)
            .background(theme.navigationBarMaterial, in: Capsule())
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            .frame(height: 60)
            .matchedGeometryEffect(id: "tab_container", in: tabContainerTransition)
        }
    }
    
    @ViewBuilder
    private var maxInputView: some View {
        if isMaxInputActive {
            HStack(alignment: .center, spacing: 8) {
                TextField("Ask anything...", text: $currentMessage, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    

                if !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        onSend(currentMessage)
                        currentMessage = ""
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(theme.maxInputButtonGradient)
                    }
                    .padding(.trailing, 8)
                }
            }
            .frame(height: 60)
            .background(theme.navigationBarMaterial, in: Capsule())
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            .matchedGeometryEffect(id: "max_button", in: maxButtonTransition)
        } else {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isMaxInputActive = true
                }
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
            .frame(width: 60, height: 60)
            .background(theme.navigationBarMaterial, in: Capsule())
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            .matchedGeometryEffect(id: "max_button", in: maxButtonTransition)
        }
    }

    private func tabView(item: TabItemData, index: Int) -> some View {
        let isSelected = selectedIndex == index
        let style = theme.tabStyle(isSelected: isSelected)
        
        return VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.system(size: 22).weight(style.iconFontWeight))
                .symbolVariant(style.iconVariant)
                .foregroundColor(style.iconColor)

            Text(item.text)
                .font(.system(size: 10).weight(style.textFontWeight))
                .foregroundColor(style.textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedIndex = index
            }
        }
        .background(
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(style.backgroundFill)
                        .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
                        .matchedGeometryEffect(id: "selected_tab", in: tabContainerTransition)
                }
            }
        )
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    
    struct PreviewWrapper: View {
        @State var selectedIndex = 0
        @State var isMaxActive = false
        
        let tabs: [TabItemData] = [
            .init(icon: "star", text: "Dashboard"),
            .init(icon: "star", text: "Journey"),
            .init(icon: "star", text: "Social"),
            .init(icon: "star", text: "Offers")
        ]
        
        var body: some View {
            ZStack(alignment: .bottom) {
                Color(red: 254/255, green: 1.0, blue: 1.0).ignoresSafeArea()
                
                VStack {
                    Text("Max Active: \(isMaxActive ? "Yes" : "No")")
                    Button("Toggle Max") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMaxActive.toggle()
                        }
                    }
                }
                
                CustomTabBar(
                    selectedIndex: $selectedIndex,
                    isMaxInputActive: $isMaxActive,
                    tabItems: tabs,
                    onSend: { message in
                        print("Sent: \(message)")
                        isMaxActive = false
                    }
                )
            }
        }
    }
    
    static var previews: some View {
        VStack {
            Text("Legacy Theme")
            PreviewWrapper()
                .liquidGlassTheme() // This will apply LegacyTheme on current OS
            
            Text("Liquid Glass Theme")
        PreviewWrapper()
                .environment(\.theme, LiquidGlassTheme()) // Manually apply LiquidGlassTheme
        }
    }
} 