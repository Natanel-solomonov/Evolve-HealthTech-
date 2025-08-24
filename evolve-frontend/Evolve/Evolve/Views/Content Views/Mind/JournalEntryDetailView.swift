import SwiftUI

struct JournalEntryDetailView: View {
    let journalEntry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var showDeleteAlert: Bool = false
    @State private var showEditView: Bool = false
    @State private var isDeleting: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header section
                        VStack(alignment: .leading, spacing: 16) {
                            // Date and time
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formattedDate)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(formattedTime)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                // Action buttons
                                HStack(spacing: 12) {
                                    Button(action: { showEditView = true }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(.white.opacity(0.2))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    
                                    Button(action: { showDeleteAlert = true }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(.red.opacity(0.2))
                                                    .overlay(
                                                        Circle()
                                                            .stroke(.red.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                }
                            }
                            
                            // Title
                            Text(journalEntry.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Content section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Entry")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(journalEntry.content)
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(4)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showEditView) {
            JournalEntryEditView(journalEntry: journalEntry)
                .environmentObject(authManager)
        }
        .alert("Delete Entry", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: journalEntry.dateCreated) {
            formatter.dateStyle = .full
            return formatter.string(from: date)
        }
        return journalEntry.dateCreated
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        if let time = formatter.date(from: journalEntry.timeCreated) {
            formatter.timeStyle = .short
            return formatter.string(from: time)
        }
        return journalEntry.timeCreated
    }
    
    // MARK: - Methods
    
    private func deleteEntry() {
        isDeleting = true
        
        Task {
            do {
                let journalAPI = JournalEntryAPI(httpClient: authManager.httpClient)
                try await journalAPI.deleteJournalEntry(id: journalEntry.id)
                
                await MainActor.run {
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Dismiss the view
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Journal Entry Edit View

struct JournalEntryEditView: View {
    let journalEntry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var title: String
    @State private var content: String
    @State private var isUpdating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    
    // Focus states
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    init(journalEntry: JournalEntry) {
        self.journalEntry = journalEntry
        _title = State(initialValue: journalEntry.title)
        _content = State(initialValue: journalEntry.content)
    }
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section
                        VStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                                .padding(.top, 20)
                            
                            Text("Edit Entry")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 20)
                        
                        // Form section
                        VStack(spacing: 20) {
                            // Title input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextField("Enter a title for your entry...", text: $title)
                                    .font(.system(size: 17))
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.white.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.white)
                                    .focused($isTitleFocused)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        isContentFocused = true
                                    }
                            }
                            
                            // Content input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Content")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ZStack(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text("What's on your mind? Share your thoughts, experiences, or reflections...")
                                            .font(.system(size: 17))
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 16)
                                    }
                                    
                                    TextEditor(text: $content)
                                        .font(.system(size: 17))
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                        .focused($isContentFocused)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                .frame(minHeight: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                        
                        // Update button
                        Button(action: updateEntry) {
                            HStack {
                                if isUpdating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                }
                                
                                Text(isUpdating ? "Updating..." : "Update Entry")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(canUpdate ? .white.opacity(0.2) : .white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(canUpdate ? 0.4 : 0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(!canUpdate || isUpdating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your journal entry has been updated successfully!")
        }
    }
    
    // MARK: - Computed Properties
    
    private var canUpdate: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedTitle.isEmpty &&
               !trimmedContent.isEmpty &&
               !isUpdating &&
               (trimmedTitle != journalEntry.title || trimmedContent != journalEntry.content)
    }
    
    // MARK: - Methods
    
    private func updateEntry() {
        guard canUpdate else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isUpdating = true
        
        Task {
            do {
                let journalAPI = JournalEntryAPI(httpClient: authManager.httpClient)
                let request = UpdateJournalEntryRequest(
                    title: trimmedTitle,
                    content: trimmedContent,
                    dateCreated: nil,
                    timeCreated: nil
                )
                
                let _ = try await journalAPI.updateJournalEntry(id: journalEntry.id, request: request)
                
                await MainActor.run {
                    isUpdating = false
                    showSuccessAlert = true
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

struct JournalEntryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = JournalEntry(
            id: UUID(),
            user: "+1234567890",
            title: "My Daily Reflection",
            content: "Today was a great day for personal growth. I learned a lot about myself and feel more confident about the future. The challenges I faced today helped me realize my inner strength and resilience.",
            dateCreated: "2024-01-15",
            timeCreated: "18:30:00",
            createdAt: "2024-01-15T18:30:00Z",
            updatedAt: "2024-01-15T18:30:00Z"
        )
        
        JournalEntryDetailView(journalEntry: sampleEntry)
            .environmentObject(AuthenticationManager())
            .environment(\.theme, LiquidGlassTheme())
    }
} 