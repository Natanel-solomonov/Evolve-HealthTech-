import SwiftUI
import SafariServices

enum SettingType: String {
    case name = "Name"
    case birthday = "Birthday"
    case sex = "Sex"
    case height = "Height"
    case weight = "Weight"
    case phoneNumber = "Phone Number"
    case backupEmail = "Backup Email"
    case unimplemented = "Unimplemented"
}

struct SettingPage<Manager: AuthManagerProtocol>: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: Manager
    let title: String
    let settingType: SettingType
    let onDismiss: (() -> Void)?
    
    // Default initializer for modal presentation
    init(title: String, settingType: SettingType) {
        self.title = title
        self.settingType = settingType
        self.onDismiss = nil
    }
    
    // Initializer for cinematic presentation
    init(title: String, settingType: SettingType, onDismiss: @escaping () -> Void) {
        self.title = title
        self.settingType = settingType
        self.onDismiss = onDismiss
    }

    // State for input fields
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var backupEmail: String = ""
    @State private var birthday: Date = Date()
    @State private var sex: String = "M"
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var weight: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.theme) private var theme: any Theme
    
    private var customHeader: some View {
        HStack {
            Button(action: dismissPage) {
                ZStack {
                    // Liquid glass style background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.05))
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }
            }
            .padding(.leading)
            
            Spacer()
            Text(title).font(.system(size: 17)).fontWeight(.bold)
            Spacer()
            
            // Invisible button for symmetry
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(.clear)
            }
            .disabled(true)
            .padding(.trailing)
        }
        .padding(.vertical).frame(maxWidth: .infinity)
    }

    var body: some View {
        VStack(spacing: 0) {
            customHeader
            Form {
                Section(footer: Text(errorMessage ?? successMessage ?? "")) {
                    editorView
                }
            }
            
            Button(action: {
                Task {
                    await saveChanges()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Changes")
                    }
                }
                .font(.system(size: 17)).fontWeight(.bold).foregroundColor(theme.background)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(theme.primaryText).clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding()
            .disabled(isLoading)
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: initializeState)
    }
    
    // Helper function to handle dismissal consistently
    private func dismissPage() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    @ViewBuilder
    private var editorView: some View {
        switch settingType {
        case .name:
            TextField("First Name", text: $firstName)
            TextField("Last Name", text: $lastName)
        case .backupEmail:
            TextField("Backup Email", text: $backupEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
        case .birthday:
            DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
        case .sex:
            Picker("Sex", selection: $sex) {
                Text("Male").tag("M")
                Text("Female").tag("F")
                Text("Other").tag("O")
            }
        case .height:
            HStack {
                Picker("Feet", selection: $heightFeet) {
                    ForEach(3...7, id: \.self) { feet in
                        Text("\(feet) ft").tag(feet)
                    }
                }
                Picker("Inches", selection: $heightInches) {
                    ForEach(0...11, id: \.self) { inches in
                        Text("\(inches) in").tag(inches)
                    }
                }
            }
        case .weight:
            HStack {
                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                Text("lbs")
            }
        default:
            Text("Editing for this setting is not yet implemented.")
        }
    }

    private func initializeState() {
        guard let user = authManager.currentUser else { return }
        
        firstName = user.firstName
        lastName = user.lastName
        backupEmail = user.backupEmail ?? ""
        
        if let info = user.info {
            sex = info.sex ?? "M"
            
            let feet = Int((info.height ?? 0) / 12)
            let inches = Int((info.height ?? 0).truncatingRemainder(dividingBy: 12))
            heightFeet = feet
            heightInches = inches
            
            weight = String(format: "%.0f", info.weight ?? 0)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let bdayString = info.birthday, let date = dateFormatter.date(from: bdayString) {
                birthday = date
            }
        }
    }
    
    private func saveChanges() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        var infoPayload: AppUserInfoUpdatePayload?
        var userPayload: AppUserUpdatePayload?
        
        let birthdayFormatter = DateFormatter()
        birthdayFormatter.dateFormat = "yyyy-MM-dd"

        switch settingType {
        case .name:
            userPayload = AppUserUpdatePayload(firstName: firstName, lastName: lastName)
        case .backupEmail:
            userPayload = AppUserUpdatePayload(backupEmail: backupEmail)
        case .birthday:
            infoPayload = AppUserInfoUpdatePayload(birthday: birthdayFormatter.string(from: birthday))
        case .sex:
            infoPayload = AppUserInfoUpdatePayload(sex: sex)
        case .height:
            let totalInches = Double(heightFeet * 12 + heightInches)
            infoPayload = AppUserInfoUpdatePayload(height: totalInches)
        case .weight:
            if let weightDouble = Double(weight) {
                infoPayload = AppUserInfoUpdatePayload(weight: weightDouble)
            } else {
                errorMessage = "Please enter a valid weight."
                isLoading = false
                return
            }
        default:
            break
        }
        
        let finalPayload: AppUserUpdatePayload
        if var payload = userPayload {
             if let info = infoPayload {
                 payload.info = info
             }
             finalPayload = payload
        } else if let info = infoPayload {
            finalPayload = AppUserUpdatePayload(info: info)
        } else {
            successMessage = "No changes to save."
            isLoading = false
            return
        }

        do {
            try await authManager.updateUserDetails(payload: finalPayload)
            successMessage = "Your information has been updated."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismissPage()
            }
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// 1. Define a protocol for the Authentication Manager's capabilities needed by SettingsView
@MainActor
protocol AuthManagerProtocol: ObservableObject {
    var currentUser: AppUser? { get }
    func logout()
    func updateUserDetails(payload: AppUserUpdatePayload) async throws
}

// 2. Make the actual AuthenticationManager (defined elsewhere) conform to this protocol.
// This extension should ideally be in AuthenticationManager.swift, but placing it here
// works if AuthenticationManager is accessible from this file.
// Ensure AuthenticationManager.swift is part of the same target.
extension AuthenticationManager: AuthManagerProtocol {}

struct SettingItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String?
    let destination: AnyView?
    let action: (() -> Void)?

    init(name: String, value: String? = nil, destination: AnyView? = nil, action: (() -> Void)? = nil) {
        self.name = name
        self.value = value
        self.destination = destination
        self.action = action
    }
}

// 1. Make SettingsView generic
struct SettingsView<Manager: AuthManagerProtocol>: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    // 2. Use the generic type for authManager
    @EnvironmentObject var authManager: Manager
    
    // Add onDismiss callback for cinematic presentation
    let onDismiss: (() -> Void)?
    
    // Default initializer for modal presentation (backward compatibility)
    init() {
        self.onDismiss = nil
    }
    
    // Initializer for cinematic presentation
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    @State private var showNotImplementedAlert = false
    @State private var showApexNotAvailableAlert = false
    @Environment(\.theme) private var theme: any Theme

    // Wrapper struct to make URL Identifiable safely
    struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var selectedURL: IdentifiableURL?

    private var legalLinks: [IdentifiableURL] = [
        IdentifiableURL(url: URL(string: "https://www.evolveai.com/terms-of-service")!),
        IdentifiableURL(url: URL(string: "https://www.evolveai.com/privacy-policy")!)
    ]
    
    private var appSettings: [SettingItem] {
        [
            SettingItem(name: "Notifications", destination: AnyView(SettingPage<Manager>(title: "Notifications", settingType: .unimplemented))),
            SettingItem(name: "Max AI", destination: AnyView(SettingPage<Manager>(title: "Max AI", settingType: .unimplemented))),
            SettingItem(name: "Units", destination: AnyView(SettingPage<Manager>(title: "Units", settingType: .unimplemented))),
            SettingItem(name: "Apple Health", destination: AnyView(SettingPage<Manager>(title: "Apple Health", settingType: .unimplemented))),
        ]
    }

    private var aboutEvolveSettings: [SettingItem] {
        [
            SettingItem(name: "How Evolve Works", destination: AnyView(SettingPage<Manager>(title: "How Evolve Works", settingType: .unimplemented))),
            SettingItem(name: "Privacy Policy", action: { selectedURL = IdentifiableURL(url: URL(string: "https://waitlist.joinevolve.app/privacy")!) }),
            SettingItem(name: "Terms of Use", action: { selectedURL = IdentifiableURL(url: URL(string: "https://waitlist.joinevolve.app/terms")!) }),
            SettingItem(name: "Restore Subscription", destination: AnyView(SettingPage<Manager>(title: "Restore Subscription", settingType: .unimplemented)))
        ]
    }

    // Helper to get current year for copyright
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        return "v.\(version) (\(build))"
    }

    // Computed property for dynamic account settings
    private var dynamicAccountSettings: [SettingItem] {
        guard let user = authManager.currentUser else { return [] }
        var settings: [SettingItem] = []

        settings.append(SettingItem(name: "Name", value: "\(user.firstName) \(user.lastName)", destination: AnyView(SettingPage<Manager>(title: "Name", settingType: .name))))

        if let birthdayString = user.info?.birthday {
            settings.append(SettingItem(name: "Birthday", value: formatBirthday(birthdayString), destination: AnyView(SettingPage<Manager>(title: "Birthday", settingType: .birthday))))
        } else {
            settings.append(SettingItem(name: "Birthday", value: "Not set", destination: AnyView(SettingPage<Manager>(title: "Birthday", settingType: .birthday))))
        }

        if let sex = user.info?.sex {
            settings.append(SettingItem(name: "Sex", value: formatSex(sex), destination: AnyView(SettingPage<Manager>(title: "Sex", settingType: .sex))))
        } else {
            settings.append(SettingItem(name: "Sex", value: "Not set", destination: AnyView(SettingPage<Manager>(title: "Sex", settingType: .sex))))
        }

        if let height = user.info?.height {
            settings.append(SettingItem(name: "Height", value: formatHeight(height), destination: AnyView(SettingPage<Manager>(title: "Height", settingType: .height))))
        } else {
            settings.append(SettingItem(name: "Height", value: "Not set", destination: AnyView(SettingPage<Manager>(title: "Height", settingType: .height))))
        }

        if let weight = user.info?.weight {
            settings.append(SettingItem(name: "Weight", value: formatWeight(weight), destination: AnyView(SettingPage<Manager>(title: "Weight", settingType: .weight))))
        } else {
            settings.append(SettingItem(name: "Weight", value: "Not set", destination: AnyView(SettingPage<Manager>(title: "Weight", settingType: .weight))))
        }

        settings.append(SettingItem(name: "Phone Number", value: formatPhoneNumber(user.phone), destination: AnyView(SettingPage<Manager>(title: "Phone Number", settingType: .phoneNumber))))

        if let backupEmail = user.backupEmail, !backupEmail.isEmpty {
            settings.append(SettingItem(name: "Backup Email", value: backupEmail.lowercased(), destination: AnyView(SettingPage<Manager>(title: "Backup Email", settingType: .backupEmail))))
        } else {
            settings.append(SettingItem(name: "Backup Email", value: "Not set", destination: AnyView(SettingPage<Manager>(title: "Backup Email", settingType: .backupEmail))))
        }
        
        return settings
    }

    // MARK: - Formatting Helpers
    private func formatBirthday(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMMM d, yyyy"
        return outputFormatter.string(from: date)
    }

    private func formatSex(_ sexCode: String) -> String {
        switch sexCode.uppercased() {
        case "M": return "Male"
        case "F": return "Female"
        case "O": return "Other"
        default: return "Not specified"
        }
    }

    private func formatHeight(_ heightInches: Double) -> String {
        let feet = Int(heightInches / 12)
        let inches = Int(heightInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    private func formatWeight(_ weightLbs: Double) -> String {
        return String(format: "%.0f lbs", weightLbs)
    }

    private func formatPhoneNumber(_ phone: String) -> String {
        let digits = phone.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        
        var nationalNumber = digits
        if nationalNumber.hasPrefix("1") && nationalNumber.count == 11 {
            nationalNumber = String(nationalNumber.dropFirst())
        }
        
        guard nationalNumber.count == 10 else {
            return phone // Return original if it's not a 10-digit number
        }
        
        return "(\(nationalNumber.prefix(3))) \(nationalNumber.dropFirst(3).prefix(3))-\(nationalNumber.dropFirst(6))"
    }

    // MARK: - Subviews for Body Sections
    private var customHeader: some View {
        HStack {
            Button(action: dismissSettings) {
                Image(systemName: "xmark").font(.system(size: 22)).foregroundColor(theme.primaryText)
            }.padding(.leading)
            Spacer()
            Text("Settings").font(.system(size: 17)).fontWeight(.bold)
            Spacer()
            Button(action: {}) { Image(systemName: "xmark").font(.system(size: 22)).foregroundColor(.clear) }
                .padding(.trailing).disabled(true)
        }
        .padding(.vertical).frame(maxWidth: .infinity)
    }
    
    // Helper function to handle dismissal consistently
    private func dismissSettings() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var joinPremiumBanner: some View {
        Button(action: { showApexNotAvailableAlert = true }) {
            HStack {
                Image("IconTrans").resizable().scaledToFit().frame(width: 30, height: 30).foregroundColor(.white)
                VStack(alignment: .leading) {
                    Text("Join Apex for $14.99").font(.system(size: 17)).foregroundColor(.white).multilineTextAlignment(.leading)
                    Text("Take your wellness to the next level with advanced AI features, data analysis, and no ads.").font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding().frame(maxWidth: .infinity).background(Color.black).cornerRadius(10)
        }.padding(.horizontal)
    }

    private func settingsSectionView(title: String, items: [SettingItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 15)).foregroundColor(theme.secondaryText).padding(.leading).padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    
                    let rowContent = HStack {
                        Text(item.name).foregroundColor(theme.primaryText).font(.system(size: 17))
                        Spacer()
                        if let value = item.value {
                            Text(value).foregroundColor(theme.secondaryText).font(.system(size: 17))
                        }
                        Image(systemName: "chevron.right").foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .padding(.vertical, 12).padding(.horizontal)

                    if let destination = item.destination {
                        NavigationLink(destination: destination) {
                            rowContent
                        }
                    } else if let action = item.action {
                        Button(action: action) {
                            rowContent
                        }
                    }

                    if index < items.count - 1 { Divider().padding(.leading) }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .themedFill(theme.cardStyle)
            )
        }.padding(.horizontal)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 15) { // Add some spacing between action buttons
            Button(action: { authManager.logout(); dismissSettings() }) {
                Text("Sign Out").fontWeight(.medium).foregroundColor(theme.background).padding(10)
                    .frame(maxWidth: .infinity).background(theme.primaryText).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.primaryText, lineWidth: 1))
                    .font(.system(size: 17))
            }.padding(.horizontal)
            
            Button(action: { showNotImplementedAlert = true }) {
                Text("Delete Account Permanently").fontWeight(.medium).foregroundColor(.red).padding(10)
                    .frame(maxWidth: .infinity).background(Color.red.opacity(0.1)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    .font(.system(size: 17))
            }.padding(.horizontal)
        }
    }

    private var footerInfo: some View {
        VStack(spacing: 5) {
            Image("IconTrans").resizable().scaledToFit().frame(width: 35, height: 35).padding(.bottom, 5)
            
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let iosString = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
            let themeCode = osVersion.majorVersion >= 26 ? "T1" : "T0"
            
            Text("\(appVersion) • iOS \(iosString) [\(themeCode)]").font(.system(size: 10)).foregroundColor(theme.secondaryText)
            Text("© \(currentYear) Evolve Wellness Inc.").font(.system(size: 10)).foregroundColor(theme.secondaryText)
            Text("User ID: \(authManager.currentUser?.id.description ?? "N/A")").font(.system(size: 10)).foregroundColor(theme.secondaryText).padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .center).padding(.top, 30)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                customHeader
                ScrollView {
                    VStack(spacing: 20) {
//                        joinPremiumBanner
                        
                        // Section 1: Main Settings
                        settingsSectionView(title: "MY ACCOUNT", items: dynamicAccountSettings)
                        settingsSectionView(title: "APP SETTINGS", items: appSettings)
                        settingsSectionView(title: "ABOUT EVOLVE", items: aboutEvolveSettings)
                        actionButtons
                        footerInfo
                    }
                    .padding(.top)
                }
            }
            .background(theme.background.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .alert("Not Implemented", isPresented: $showNotImplementedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We're still working on adding the ability to delete your account.")
            }
            .alert("Apex Not Available", isPresented: $showApexNotAvailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Apex is not yet available for purchase. Please check back later!")
            }
            .sheet(item: $selectedURL) { identifiableURL in
                SafariView(url: identifiableURL.url)
            }
        }
    }
}

// MARK: - Safari View
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// 4. New Preview Authentication Manager (does not inherit from AuthenticationManager)
@MainActor
class PreviewAuthManagerForSettingsView: ObservableObject, AuthManagerProtocol {
    @Published var currentUser: AppUser?

    init() {
        // Setup a sample user directly, no super.init() to problematic AuthenticationManager
        let sampleInfo = AppUser.Info(height: 70, birthday: "1990-01-01", weight: 160, sex: "M")
        let sampleGoals = AppUser.GoalsData(goalsRaw: ["Lose weight", "Run a 5k"], goalsProcessed: nil)
        self.currentUser = AppUser(
            id: "12345",
            phone: "(555) 123-4567",
            backupEmail: "preview@example.com",
            firstName: "Preview",
            lastName: "User",
            isPhoneVerified: true,
            dateJoined: "2023-01-01T10:00:00Z",
            lifetimePoints: 1000,
            availablePoints: 500,
            lifetimeSavings: 50,
            isOnboarded: true,
            currentStreak: 5,
            longestStreak: 12,
            streakPoints: 100,
            info: sampleInfo,
            equipment: nil,
            exerciseMaxes: nil,
            muscleFatigue: nil,
            goals: sampleGoals,
            scheduledActivities: [],
            completionLogs: [],
            calorieLogs: [],
            feedback: nil,
            assignedPromotions: [],
            promotionRedemptions: []
        )
    }

    func logout() {
        print("PreviewAuthManagerForSettingsView: Logout called.")
        // In a preview, typically we might set currentUser to nil or just print
        self.currentUser = nil
    }
    
    func updateUserDetails(payload: AppUserUpdatePayload) async throws {
        print("PreviewAuthManager: updateUserDetails called with payload: \(payload)")
        
        if let newFirstName = payload.firstName {
            currentUser?.firstName = newFirstName
        }
        if let newLastName = payload.lastName {
            currentUser?.lastName = newLastName
        }
        if let newEmail = payload.backupEmail {
            currentUser?.backupEmail = newEmail
        }
        
        if let infoPayload = payload.info {
            if currentUser?.info == nil {
                currentUser?.info = AppUser.Info(height: 0, birthday: "", weight: 0, sex: "")
            }
            if let newHeight = infoPayload.height { currentUser?.info?.height = newHeight }
            if let newBirthday = infoPayload.birthday {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                currentUser?.info?.birthday = newBirthday
            }
            if let newWeight = infoPayload.weight { currentUser?.info?.weight = newWeight }
            if let newSex = infoPayload.sex { currentUser?.info?.sex = newSex }
        }
        
        // Manually notify observers of the change since this is a preview environment
        objectWillChange.send()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // 3. Instantiate SettingsView with the concrete preview manager type
        SettingsView<PreviewAuthManagerForSettingsView>()
            .environmentObject(PreviewAuthManagerForSettingsView())
    }
}
