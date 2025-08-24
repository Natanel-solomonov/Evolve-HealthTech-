import SwiftUI

struct MaxMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isCurrentUser: Bool
    var isTyping: Bool = false // Added for typing indicator
}

enum KeyboardInputType {
    case standard
    case numberPad
    // Add other types like custom selectors if needed later
}

struct TypingIndicatorView: View {
    @State private var scale: [CGFloat] = [0.5, 0.5, 0.5]
    private let animation = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 6
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .foregroundColor(theme.secondaryText.opacity(0.7)) // light-mode dot colour
                    .scaleEffect(scale[index])
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                            withAnimation(animation) {
                                scale[index] = 1.0
                            }
                        }
                    }
            }
        }
        .padding(10)
        .background(theme.background) // light-mode typing indicator bg
        .cornerRadius(16)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.2, alignment: .leading) // Similar to message bubble
    }
}

struct ChatView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var messages: [MaxMessage] = []
    @State private var currentMessage: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var currentKeyboardType: KeyboardInputType = .standard // Added for dynamic keyboard
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.theme) private var theme: any Theme

    // MARK: - Suggested Prompts
    // You can later make this list come from your backend.
    private let maxInputLines = 5

    // NEW: allow optional initial user message to pre-populate the chat
    private let initialMessage: String?

    // Flag so we only inject the initial message once
    @State private var didSendInitialMessage: Bool = false

    // Control header visibility
    private let showHeader: Bool
    
    // Control demo messages for demonstration purposes
    private let showDemoMessages: Bool
    
    // Background configuration - same as DashboardView
    @State private var useGradientBackground = false
    private let leftGradientColor: Color = Color("Fitness")
    private let rightGradientColor: Color = Color("Sleep")

    // Add a custom initializer so callers can pass in the first message
    init(initialMessage: String? = nil, showHeader: Bool = true, showDemoMessages: Bool = false) {
        self.initialMessage = initialMessage
        self.showHeader = showHeader
        self.showDemoMessages = showDemoMessages
        
        // Initialize with demo messages if requested
        if showDemoMessages {
            self._messages = .init(initialValue: [
                .init(text: "My hamstrings have been really tight since I woke up. What should I do?", isCurrentUser: true),
                .init(text: "Here's a custom stretching routine to help you out. Would you like me to add it to your morning routine?", isCurrentUser: false),
                .init(text: "Yeah please", isCurrentUser: true),
                .init(text: "Got it, added.", isCurrentUser: false)
            ])
        } else {
            self._messages = .init(initialValue: [])
        }
    }
    
    // Preview initializer
    init(messages: [MaxMessage], showHeader: Bool = true) {
        self.initialMessage = nil
        self.showHeader = showHeader
        self.showDemoMessages = false
        self._messages = .init(initialValue: messages)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background – same as DashboardView
                GridBackground()
                
                // Top gradient/solid overlay - full screen
                if useGradientBackground {
                    TopHorizontalGradient(leftColor: leftGradientColor, rightColor: rightGradientColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                } else {
                    TopSolidColor(color: Color("OffWhite"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }
                
                // Layer 0: Main chat content
                VStack(spacing: 0) {
                    messageListView

                    inputArea
                }
                .padding(.top, showHeader ? 90 : 0) // Accommodate for the header height + padding
                .zIndex(0)

                // Layer 2: Custom Header, positioned at the top
                if showHeader {
                customHeader
                    .zIndex(2)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // NEW: automatically send the initial message if provided
            if !didSendInitialMessage, let initial = initialMessage, !initial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentMessage = initial
                sendMessage()
                didSendInitialMessage = true
            }

            // Automatically focus the text input to present the keyboard immediately.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    private var messageListView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                if messages.isEmpty {
                    VStack {
                        Spacer()
                        HelloUserView
                        Spacer()
                    }
                    .frame(minHeight: UIScreen.main.bounds.height * 0.6)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .onChange(of: messages) {
                scrollToBottom(scrollViewProxy: scrollViewProxy)
            }
            .onAppear {
                 // Scroll to bottom initially if there are messages
                if !messages.isEmpty {
                    scrollToBottom(scrollViewProxy: scrollViewProxy, animated: false)
                }
            }
        }
    }

    private var inputArea: some View {
        HStack(alignment: .center, spacing: 8) {
            if #available(iOS 16.0, *) {
                TextField("", text: $currentMessage, axis: .vertical)
                    .lineLimit(1...maxInputLines)
                    .focused($isTextFieldFocused)
                    .padding(.vertical, 8)
                    .foregroundColor(theme.primaryText)
                    .accentColor(theme.accent) // Cursor color
                    .keyboardType(keyboardTypeForCurrentInput())
                    .placeholder(when: currentMessage.isEmpty) {
                        Text("Ask anything")
                            .foregroundColor(theme.secondaryText)
                            .font(.system(size: 17))
                    }
            } else {
                ZStack(alignment: .leading) {
                    if currentMessage.isEmpty {
                        Text("Ask anything")
                            .foregroundColor(theme.secondaryText)
                            .padding(.leading, 5)
                            .padding(.bottom, 8)
                            .font(.system(size: 17))
                    }
                    TextEditor(text: $currentMessage)
                        .frame(minHeight: 30, maxHeight: CGFloat(maxInputLines) * 22)
                        .padding(.vertical, 4)
                        .scrollContentBackground(.hidden) // Allow TextEditor background to be transparent
                        .background(Color.clear)
                        .foregroundColor(theme.primaryText)
                        .accentColor(theme.accent) // Cursor color
                        .onAppear {
                            isTextFieldFocused = true
                        }
                }
            }

            if !currentMessage.isEmpty {
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black)
                                .frame(width: 30, height: 30)
                        )
                }
                .disabled(currentMessage.isEmpty)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .themedFill(theme.translucentCardStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
                
        )
        .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        .padding(.horizontal)
        .padding(.vertical, 7)
    }

    private func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newMessage = MaxMessage(text: currentMessage, isCurrentUser: true)
        messages.append(newMessage)
        currentMessage = ""
        // isTextFieldFocused = false // Keep keyboard open

        // Ask the AI for a response
        Task { await fetchAIResponse(for: newMessage.text) }
    }

    private func fetchAIResponse(for userInput: String) async {
        // 1. Show typing indicator
        let typingMessage = MaxMessage(text: "", isCurrentUser: false, isTyping: true)
        await MainActor.run { messages.append(typingMessage) }

        do {
            let responseText = try await sendRequestToBackend(message: userInput)
            await MainActor.run {
                messages.removeAll { $0.id == typingMessage.id }
                let aiMessage = MaxMessage(text: responseText, isCurrentUser: false)
                messages.append(aiMessage)
                setKeyboardType(for: responseText)
            }
        } catch {
            await MainActor.run {
                messages.removeAll { $0.id == typingMessage.id }
                let errorMessage = MaxMessage(text: "Something went wrong. Please try again.", isCurrentUser: false)
                messages.append(errorMessage)
            }
        }
    }

    private func sendRequestToBackend(message: String) async throws -> String {
        // NOTE: Replace the URL below with your actual Groq endpoint.
        guard let url = URL(string: "https://your-backend-endpoint/chat") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        return decoded.message
    }

    private func calculateTypingDuration(for text: String) -> TimeInterval {
        let charactersPerSecond = 10.0 // Adjust as needed
        let minDuration = 1.0         // Minimum time for the indicator
        let maxDuration = 4.0         // Maximum time for the indicator
        let calculatedDuration = Double(text.count) / charactersPerSecond
        return min(maxDuration, max(minDuration, calculatedDuration))
    }

    private func simulateReceivingMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let receivedMessage = MaxMessage(text: "Hey, I got your message!", isCurrentUser: false)
            messages.append(receivedMessage)
        }
    }
    
    private func simulateReceivingMessageAfterDelay(responseTo userMessage: String) {
        let responseText = determineResponse(basedOn: userMessage) // Modified to get a contextual response
        let typingDuration = calculateTypingDuration(for: responseText)

        // 1. Show typing indicator
        let typingMessage = MaxMessage(text: "", isCurrentUser: false, isTyping: true)
        messages.append(typingMessage)
        scrollToBottomAfterMessageUpdate()

        // 2. After typing duration, replace with actual message
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            // Remove typing indicator
            messages.removeAll { $0.id == typingMessage.id }

            // Add actual message
            let actualMessage = MaxMessage(text: responseText, isCurrentUser: false)
            messages.append(actualMessage)
            
            // Determine and set next keyboard type based on the bot's message
            setKeyboardType(for: responseText)
            
            scrollToBottomAfterMessageUpdate()
        }
    }

    private func scrollToBottomAfterMessageUpdate() {
        // Need to ensure the ScrollViewReader proxy is available or this won't work as intended
        // This is a simplified call; direct access to the proxy is better if possible from here
        // For now, we rely on the onChange of messages in messageListView
    }

    private func scrollToBottom(scrollViewProxy: ScrollViewProxy, animated: Bool = true) {
        guard !messages.isEmpty, let lastMessageId = messages.last?.id else { return }
        if animated {
            withAnimation {
                scrollViewProxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        } else {
            scrollViewProxy.scrollTo(lastMessageId, anchor: .bottom)
        }
    }

    private func keyboardTypeForCurrentInput() -> UIKeyboardType {
        switch currentKeyboardType {
        case .standard:
            return .default
        case .numberPad:
            return .numberPad
        // Handle other cases if you add more keyboard types
        }
    }

    private func determineResponse(basedOn userInput: String) -> String {
        // Simple example logic:
        if userInput.lowercased().contains("hello") || userInput.lowercased().contains("hi") {
            return "Hi there! What's your name?"
        } else if userInput.lowercased().range(of: #"^\d+$"#, options: .regularExpression) != nil { // If user sent a number (presumably age)
            return "Thanks! And what's your favorite color?"
        } else if messages.last(where: { !$0.isCurrentUser })?.text.contains("What's your name?") == true {
             return "Nice to meet you, \(userInput)! How old are you?"
        }
        return "Okay, I see you wrote: blank. That's interesting!"
    }

    private func setKeyboardType(for botMessage: String) {
        if botMessage.lowercased().contains("how old are you?") || botMessage.lowercased().contains("age?") {
            currentKeyboardType = .numberPad
        } else {
            currentKeyboardType = .standard
        }
        // Add more rules as needed
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack {
            // Invisible spacer to balance the history button on the right
            HStack {
                Spacer()
            }
            .frame(width: 52) // Match the history button width + padding
            
            Spacer()

            Text("Max")
                .font(.system(size: 22))

            Spacer()

            Button(action: {
                // TODO: Implement history action
                print("History button tapped")
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 40, height: 40)
                    .background(theme.background)
                    .clipShape(Circle())
                    .shadow(color: theme.defaultShadow.color, radius: 6, x: 0, y: 6)
            }
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 72)
    }

    // MARK: - Hello User View
    private var HelloUserView: some View {
        Text("What can I do for you?")
            .font(.system(size: 34))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color("Fitness"), Color("Mind")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

struct MessageView: View {
    let message: MaxMessage
    @Environment(\.theme) private var theme: any Theme
    
    /// Determines if this message should show a stretching routine card
    private var shouldShowStretchingCard: Bool {
        !message.isCurrentUser && 
        !message.isTyping && 
        (message.text.lowercased().contains("stretching routine") || 
         message.text.lowercased().contains("custom stretching"))
    }

    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16).fill(
                            theme.maxInputButtonGradient
                        )
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 17))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if message.isTyping {
                        TypingIndicatorView()
                    } else {
                        Text(message.text)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            .foregroundColor(.black)
                            .font(.system(size: 17))
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                        
                        // Show stretching routine card if conditions are met
                        if shouldShowStretchingCard {
                            stretchingRoutineCard
                        }
                    }
                }
                Spacer()
            }
        }
    }
    
    /// Card view for the stretching routine
    private var stretchingRoutineCard: some View {
        HStack {
            Text("Hamstring Stretches")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Added NavigationView for preview context
//            VStack {
//                Text("Legacy Theme")
//                ChatView() // Ensuring preview is original
//                    .environmentObject(AuthenticationManager())
//                    .liquidGlassTheme()
                
//                Text("Liquid Glass Theme (Modal)")
                ChatView(showDemoMessages: true)
                    .environmentObject(AuthenticationManager())
                    .environment(\.theme, LiquidGlassTheme())
                
//                Text("Liquid Glass Theme (Tab)")
//                ChatView(showHeader: false) // Ensuring preview is original
//                    .environmentObject(AuthenticationManager())
//                    .environment(\.theme, LiquidGlassTheme())
//            }
        }
    }
    
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct GroqResponse: Decodable { let message: String }
