import SwiftUI

// New View for the Grainy/Noise Overlay
struct NoiseOverlayView: View {
    var body: some View {
        Canvas {
            context, size in
            // Adjust density for performance vs. visual effect
            // Higher density = more grain, but potentially slower
            let density = 0.1 // Try values like 0.05, 0.1, 0.2
            let numberOfGrains = Int(size.width * size.height * density)

            for _ in 0..<numberOfGrains {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let grainSize = CGFloat.random(in: 9...25) // Small grains
                
                // Subtle gray color for the grain, with some transparency
                // You can experiment with other colors or opacities
                let grainColor = Color.gray.opacity(Double.random(in: 0.05...0.15))
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: grainSize, height: grainSize)),
                    with: .color(grainColor)
                )
            }
        }
        .allowsHitTesting(false) // Ensure the overlay doesn't interfere with interactions
    }
}

struct GradientBackgroundView: View {
    // State for Linear Gradient
    @State private var linearStartPoint = UnitPoint(x: 0.5, y: 0)
    @State private var linearEndPoint = UnitPoint(x: 0.5, y: 1)

    // State for first Radial Gradient
    @State private var radialCenter1 = UnitPoint(x: 0.7, y: 0.3)
    @State private var radialRadius1: CGFloat = 300
    @State private var radialOpacity1: Double = 0.15

    // State for second Radial Gradient
    @State private var radialCenter2 = UnitPoint(x: 0.3, y: 0.7)
    @State private var radialRadius2: CGFloat = 400
    @State private var radialOpacity2: Double = 0.3

    // State for third Radial Gradient
    @State private var radialCenter3 = UnitPoint(x: 0.5, y: 0.5)
    @State private var radialRadius3: CGFloat = 250
    @State private var radialOpacity3: Double = 0.2

    // State for fourth Radial Gradient
    @State private var radialCenter4 = UnitPoint(x: 0.8, y: 0.8)
    @State private var radialRadius4: CGFloat = 350
    @State private var radialOpacity4: Double = 0.25
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.black, Color(red: 0.1, green: 0.1, blue: 0.2), .black]),
                startPoint: linearStartPoint,
                endPoint: linearEndPoint
            )
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(radialOpacity1), Color.clear]),
                center: radialCenter1,
                startRadius: 5,
                endRadius: radialRadius1
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color.blue.opacity(radialOpacity2), Color.clear]),
                center: radialCenter2,
                startRadius: 50,
                endRadius: radialRadius2
            )
            .blendMode(.overlay)
            .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.3, green: 0.6, blue: 0.8).opacity(radialOpacity3), Color.clear]),
                center: radialCenter3,
                startRadius: 20,
                endRadius: radialRadius3
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.8, green: 0.3, blue: 0.5).opacity(radialOpacity4), Color.clear]),
                center: radialCenter4,
                startRadius: 30,
                endRadius: radialRadius4
            )
            .blendMode(.overlay)
            .ignoresSafeArea()
            
            // Add the Noise Overlay
            NoiseOverlayView()
                .opacity(0.5) // Adjust opacity for subtlety
                .blendMode(.overlay) // Experiment with blend modes
                .ignoresSafeArea()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 15)) {
                // Animate Linear Gradient
                linearStartPoint = UnitPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: -0.3...0.3))
                linearEndPoint = UnitPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: 0.7...1.3))

                // Animate First Radial Gradient
                radialCenter1 = UnitPoint(x: CGFloat.random(in: 0.2...0.8), y: CGFloat.random(in: 0.2...0.8))
                radialRadius1 = CGFloat.random(in: 250...400)
                radialOpacity1 = Double.random(in: 0.1...0.25)

                // Animate Second Radial Gradient
                radialCenter2 = UnitPoint(x: CGFloat.random(in: 0.1...0.9), y: CGFloat.random(in: 0.1...0.9))
                radialRadius2 = CGFloat.random(in: 300...500)
                radialOpacity2 = Double.random(in: 0.2...0.4)
                
                // Animate Third Radial Gradient
                radialCenter3 = UnitPoint(x: CGFloat.random(in: 0.0...1.0), y: CGFloat.random(in: 0.0...1.0))
                radialRadius3 = CGFloat.random(in: 200...350)
                radialOpacity3 = Double.random(in: 0.15...0.3)

                // Animate Fourth Radial Gradient
                radialCenter4 = UnitPoint(x: CGFloat.random(in: 0.0...1.0), y: CGFloat.random(in: 0.0...1.0))
                radialRadius4 = CGFloat.random(in: 250...450)
                radialOpacity4 = Double.random(in: 0.2...0.35)
            }
        }
        .onAppear {
            // Initial randomization for a more varied start
            // This ensures they don't all start from the same hardcoded values before the first timer tick
            linearStartPoint = UnitPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: -0.3...0.3))
            linearEndPoint = UnitPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: 0.7...1.3))
            radialCenter1 = UnitPoint(x: CGFloat.random(in: 0.2...0.8), y: CGFloat.random(in: 0.2...0.8))
            radialRadius1 = CGFloat.random(in: 250...400)
            radialOpacity1 = Double.random(in: 0.1...0.25)
            radialCenter2 = UnitPoint(x: CGFloat.random(in: 0.1...0.9), y: CGFloat.random(in: 0.1...0.9))
            radialRadius2 = CGFloat.random(in: 300...500)
            radialOpacity2 = Double.random(in: 0.2...0.4)
            radialCenter3 = UnitPoint(x: CGFloat.random(in: 0.0...1.0), y: CGFloat.random(in: 0.0...1.0))
            radialRadius3 = CGFloat.random(in: 200...350)
            radialOpacity3 = Double.random(in: 0.15...0.3)
            radialCenter4 = UnitPoint(x: CGFloat.random(in: 0.0...1.0), y: CGFloat.random(in: 0.0...1.0))
            radialRadius4 = CGFloat.random(in: 250...450)
            radialOpacity4 = Double.random(in: 0.2...0.35)
        }
    }
}

// Custom Shape for rounding specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

//struct LandingViewIdea: View {
//    @EnvironmentObject var authManager: AuthenticationManager
//
//    var body: some View {
//        GradientBackgroundView()
//            .overlay(
//                ZStack(alignment: .topTrailing) { // Use ZStack for layering and alignment
//                    // Image positioned at the top right
//                    Image("IconTrans")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 50)
//                        .padding([.top, .trailing]) // Add padding from edges
//
//                    // Title positioned below the image area, aligned left
//                    VStack(alignment: .leading) {
//                        Spacer()
//                        Text("Evolve")
//                            .font(.custom("Georgia", size: 60).weight(.black))
//                            .foregroundColor(.white.opacity(0.9))
//                            .padding(.leading)
//                        Text("the best")
//                            .font(.custom("Georgia", size: 60).weight(.black))
//                            .foregroundColor(.white.opacity(0.9))
//                            .padding(.leading)
//                        Text("version")
//                            .font(.custom("Georgia", size: 60).weight(.black))
//                            .foregroundColor(.white.opacity(0.9))
//                            .padding(.leading)
//                        Text("of you")
//                            .font(.custom("Georgia", size: 60).weight(.black))
//                            .foregroundColor(.white.opacity(0.9))
//                            .padding(.leading)
//                        Spacer()
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes full width for alignment
//                }
//            )
//    }
//}

struct LandingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.8
    @Environment(\.theme) private var theme: any Theme

    // MARK: - Phone + OTP Flow State
    @State private var phoneDigits: String = ""             // Raw 0-9 digits only
    @State private var phoneDisplay: String = ""            // Formatted for display
    @State private var showOTPSection: Bool = false          // Controls fade between phone + OTP UI
    @State private var otpDigits: String = ""              // Raw OTP digits
    @State private var formattedPhoneForDisplay: String = "" // E.g. (555) 555-5555

    @State private var resendSeconds: Int = 30               // Countdown before resend enabled
    @State private var isResendAvailable: Bool = false
    @State private var resendTimer: Timer? = nil             // Retain timer to invalidate later

    // Focus state for OTP hidden textfield
    @FocusState private var isOTPFieldFocused: Bool

    // MARK: - OTP Validation State
    @State private var otpValidationState: OTPValidationState = .neutral
    @State private var shakeOffset: CGFloat = 0
    
    enum OTPValidationState {
        case neutral
        case correct
        case incorrect
    }

    // Country metadata for picker
    struct Country: Identifiable, Hashable {
        var id: String { dialCode }
        let name: String
        let dialCode: String
        let flag: String
    }

    // NOTE: Backend currently validates only 11-digit US phone numbers (+1XXXXXXXXXX).
    // Restricting available country codes to US to align with backend validation.
    private let countries: [Country] = [
        Country(name: "United States", dialCode: "1", flag: "🇺🇸")
    ]

    @State private var selectedCountry: Country = Country(name: "United States", dialCode: "1", flag: "🇺🇸")

    var body: some View {
        GradientBackgroundView()
            .overlay(
                ZStack {
                    // IconTrans higher up
                    VStack {
                        Image("IconTrans")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .padding(.top, 80)
                        Spacer()
                    }

                    // Bottom area – phone or OTP section
                    VStack {
                        Spacer()

                        Group {
                            if showOTPSection {
                                otpInputSection
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            } else {
                                phoneInputSection
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .animation(.easeInOut, value: showOTPSection)
                    }
                    .padding([.horizontal, .bottom])
                }
            )
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    logoOpacity = 1.0
                    logoScale = 1.0
                }
                // Removed button animation logic from here
            }
    }

    // MARK: - UI Sections

    private var phoneInputSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                // Country code selector matching image style
                Menu {
                    ScrollView {
                        VStack {
                            ForEach(countries) { country in
                                Button(action: { selectedCountry = country }) {
                                    HStack {
                                        Text(country.flag)
                                        Text("+\(country.dialCode)")
                                        Spacer()
                                        if country == selectedCountry {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }.frame(height: 250)
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCountry.flag)
                        Text("+\(selectedCountry.dialCode)")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.leading, 8)
                }

                Divider()
                    .frame(height: 24)

                // Formatted phone number field
                ZStack(alignment: .leading) {
                    if phoneDisplay.isEmpty {
                        Text("Phone Number")
                            .foregroundColor(theme.secondaryText)
                            .padding(.leading, 4)
                    }
                    TextField("", text: $phoneDisplay)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .foregroundColor(theme.primaryText)
                        .colorScheme(.dark)
                        .onChange(of: phoneDisplay) { _, newVal in
                            let raw = newVal.filter { "0123456789".contains($0) }
                            let limited = String(raw.prefix(10))
                            phoneDigits = limited
                            let formatted = formatPhoneNumberInput(limited)
                            if phoneDisplay != formatted {
                                phoneDisplay = formatted
                            }
                        }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                
                // Chevron continue button (only show when 10 digits entered)
                if phoneDigits.count == 10 {
                    Button(action: handleContinueTapped) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.trailing, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .themedFill(theme.translucentCardStyle)
            )
            .animation(.easeInOut(duration: 0.2), value: phoneDigits.count == 10)
        }
    }

    private var otpInputSection: some View {
        VStack(spacing: 18) {
            Text("We've sent a verification code to \(formatPhoneForOTPDisplay())")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            // OTP six-box input
            otpBoxes

            // Resend area
            if isResendAvailable {
                Button("Resend code", action: resendOTP)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Text("Resend code in \(resendSeconds)s")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // Helper to format phone for OTP display (no country code)
    private func formatPhoneForOTPDisplay() -> String {
        // phoneDigits is always 10 digits (raw US number)
        return formatPhoneNumberInput(phoneDigits)
    }

    // MARK: - Helper Computed

    // MARK: - Actions

    private func handleContinueTapped() {
        let fullNumber = "+" + selectedCountry.dialCode + phoneDigits
        formattedPhoneForDisplay = formatPhoneNumberForDisplay(fullNumber)

        sendOTPRequest(phone: fullNumber)

        withAnimation {
            showOTPSection = true
        }
        startResendTimer()
        // Give keyboard focus to OTP hidden field after small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isOTPFieldFocused = true
        }
    }

    private func resendOTP() {
        let fullNumber = "+" + selectedCountry.dialCode + phoneDigits
        sendOTPRequest(phone: fullNumber)
        startResendTimer()
    }

    private func startResendTimer() {
        resendTimer?.invalidate()
        resendSeconds = 60
        isResendAvailable = false
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendSeconds > 0 {
                resendSeconds -= 1
            } else {
                timer.invalidate()
                isResendAvailable = true
            }
        }
    }

    // MARK: - Networking (Send OTP)

    private func sendOTPRequest(phone: String) {
        guard let url = URL(string: AppConfig.apiBaseURL + "/send-otp/") else {
            print("LandingView: Invalid URL for send-otp")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["phone": phone]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("LandingView: Error encoding send-otp payload: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("LandingView: send-otp error: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("LandingView: send-otp status \(httpResponse.statusCode)")
            }
        }.resume()
    }

    // MARK: - Formatting Helpers (copied from Onboarding)

    private func getRawPhoneNumber(_ formatted: String) -> String {
        formatted.filter { "0123456789".contains($0) }
    }

    private func formatPhoneNumberInput(_ input: String) -> String {
        let digits = getRawPhoneNumber(input)
        let mask = "(XXX) XXX-XXXX"
        var result = ""
        var digitIndex = digits.startIndex
        var maskIndex = mask.startIndex
        while digitIndex < digits.endIndex && maskIndex < mask.endIndex {
            if mask[maskIndex] == "X" {
                result.append(digits[digitIndex])
                digitIndex = digits.index(after: digitIndex)
            } else {
                result.append(mask[maskIndex])
            }
            maskIndex = mask.index(after: maskIndex)
        }
        return result
    }

    private func formatPhoneNumberForDisplay(_ phoneNumber: String) -> String {
        // Display as "+Code ##########" split with space for readability
        let cleaned = phoneNumber.filter { "0123456789+".contains($0) }
        if let plusIndex = cleaned.firstIndex(of: "+") {
            let codeAndRest = cleaned[plusIndex...]
            // Insert space after country code for display
            if codeAndRest.count > 2 {
                // Find where digits after '+' stop for country code (assuming up to 3)
                let start = codeAndRest.index(after: plusIndex)
                let end = codeAndRest.index(start, offsetBy: selectedCountry.dialCode.count)
                let code = codeAndRest[start..<end]
                let number = codeAndRest[end...]
                return "+\(code) \(number)"
            }
        }
        return phoneNumber
    }

    // Custom six-box OTP view
    private var otpBoxes: some View {
        ZStack {
            // Invisible textfield capturing all input (needs minimal size to become first responder)
            TextField("", text: $otpDigits)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .colorScheme(.dark)
                .focused($isOTPFieldFocused)
                .onChange(of: otpDigits) { _, newVal in
                    otpDigits = String(newVal.filter { "0123456789".contains($0) }.prefix(6))
                    if otpDigits.count == 6 {
                        verifyOTPRequest()
                    }
                }
                .frame(width: 0, height: 0) // Use zero frame to avoid constraint conflicts
                .opacity(0) // Completely invisible

            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(otpBorderColor, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1))
                            )
                            .frame(width: 45, height: 55)
                        Text(getOTPDigit(at: index))
                            .font(.title2).bold()
                            .foregroundColor(otpTextColor)
                    }
                }
            }
            .offset(x: shakeOffset)
            .onTapGesture { // Bring up keypad when user taps boxes
                isOTPFieldFocused = true
            }
        }
    }

    private func getOTPDigit(at index: Int) -> String {
        if index < otpDigits.count {
            let s = otpDigits[otpDigits.index(otpDigits.startIndex, offsetBy: index)]
            return String(s)
        }
        return ""
    }

    // MARK: - Networking (Verify OTP)

    private func verifyOTPRequest() {
        let fullNumber = "+" + selectedCountry.dialCode + phoneDigits
        guard let url = URL(string: AppConfig.apiBaseURL + "/verify-otp/") else {
            print("LandingView: Invalid verify-otp URL")
            return
        }

        struct VerifyPayload: Codable { let phone: String; let otp: String }
        let payload = VerifyPayload(phone: fullNumber, otp: otpDigits)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do { request.httpBody = try JSONEncoder().encode(payload) } catch {
            print("LandingView: Verify OTP encode error \(error)"); return }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("LandingView: verify-otp error: \(error)")
                DispatchQueue.main.async {
                    self.handleOTPFailure()
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.handleOTPFailure()
                }
                return
            }

            if (200...299).contains(httpResponse.statusCode), let data = data {
                do {
                    let decoded = try JSONDecoder().decode(VerifyOTPResponse.self, from: data)
                    print("LandingView: OTP verified successfully for \(decoded.user.phone). Logging in...")
                    DispatchQueue.main.async {
                        self.handleOTPSuccess()
                        // Small delay to show green state before transitioning
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            authManager.loginUser(user: decoded.user, accessToken: decoded.access_token, refreshToken: decoded.refresh_token)
                        }
                    }
                } catch {
                    print("LandingView: Decode VerifyOTPResponse error: \(error)")
                    DispatchQueue.main.async {
                        self.handleOTPFailure()
                    }
                }
            } else {
                print("LandingView: OTP verification failed, status \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.handleOTPFailure()
                }
            }
        }.resume()
    }
    
    // MARK: - OTP Feedback Handlers
    
    private func handleOTPSuccess() {
        // Trigger satisfying success haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            otpValidationState = .correct
        }
    }
    
    private func handleOTPFailure() {
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Set red state and shake animation
        withAnimation(.easeInOut(duration: 0.3)) {
            otpValidationState = .incorrect
        }
        
        // Shake animation
        withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
            shakeOffset = 10
        }
        
        // Reset shake offset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shakeOffset = 0
        }
        
        // Clear OTP input and reset to neutral state after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                otpDigits = ""
                otpValidationState = .neutral
            }
            // Refocus the OTP field
            isOTPFieldFocused = true
        }
    }

    // MARK: - OTP Color Helpers
    private var otpBorderColor: Color {
        switch otpValidationState {
        case .neutral:
            return .white
        case .correct:
            return .green
        case .incorrect:
            return .red
        }
    }
    
    private var otpTextColor: Color {
        switch otpValidationState {
        case .neutral:
            return .white
        case .correct:
            return .green
        case .incorrect:
            return .red
        }
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView() // Removed onGetStartedTapped from preview
            .previewDisplayName("Landing View")
            .environmentObject(AuthenticationManager())
    }
}
