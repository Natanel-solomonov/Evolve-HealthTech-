import SwiftUI

struct JournalEntryListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var journalEntries: [JournalEntry] = []
    @State private var isLoading: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showCreateView: Bool = false
    @State private var selectedEntry: JournalEntry?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color("Mind"), Color("Sleep")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        Text("Journal Entries")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if !journalEntries.isEmpty {
                            Text("\(journalEntries.count) entries")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Spacer()
                    } else if journalEntries.isEmpty {
                        emptyStateView
                    } else {
                        journalEntriesList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            fetchJournalEntries()
        }
        .sheet(isPresented: $showCreateView) {
            JournalEntryCreateView()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryDetailView(journalEntry: entry)
                .environmentObject(authManager)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
            Button("Try Again") {
                fetchJournalEntries()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Journal Entries Yet")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Start writing to capture your thoughts and feelings")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showCreateView = true }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create First Entry")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private var journalEntriesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(journalEntries) { entry in
                    JournalEntryCard(entry: entry) {
                        selectedEntry = entry
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for floating action button
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating action button
            Button(action: { showCreateView = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.25))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Methods
    
    private func fetchJournalEntries() {
        isLoading = true
        
        Task {
            do {
                let journalAPI = JournalEntryAPI(httpClient: authManager.httpClient)
                let entries = try await journalAPI.fetchJournalEntries()
                
                await MainActor.run {
                    self.journalEntries = entries
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Journal Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with date
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedDate)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(formattedTime)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Title
                Text(entry.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Content preview
                Text(entry.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: entry.dateCreated) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return entry.dateCreated
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        if let time = formatter.date(from: entry.timeCreated) {
            formatter.timeStyle = .short
            return formatter.string(from: time)
        }
        return entry.timeCreated
    }
}

// MARK: - Preview

struct JournalEntryListView_Previews: PreviewProvider {
    static var previews: some View {
        JournalEntryListView()
            .environmentObject(AuthenticationManager())
            .environment(\.theme, LiquidGlassTheme())
    }
} 