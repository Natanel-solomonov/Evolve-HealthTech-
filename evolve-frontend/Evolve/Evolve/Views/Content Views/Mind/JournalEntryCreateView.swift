import SwiftUI

struct JournalEntryCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    
    // Focus states for better UX
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient similar to other Mind views
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
                            Image(systemName: "book.pages")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                                .padding(.top, 20)
                            
                            Text("New Journal Entry")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Capture your thoughts and feelings")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.8))
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
                        
                        // Submit button
                        Button(action: submitJournalEntry) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                }
                                
                                Text(isSubmitting ? "Saving..." : "Save Entry")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(canSubmit ? .white.opacity(0.2) : .white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(canSubmit ? 0.4 : 0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(!canSubmit || isSubmitting)
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
            Text("Your journal entry has been saved successfully!")
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }
    
    // MARK: - Methods
    
    private func submitJournalEntry() {
        guard canSubmit else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSubmitting = true
        
        Task {
            do {
                let journalAPI = JournalEntryAPI(httpClient: authManager.httpClient)
                let _ = try await journalAPI.createJournalEntry(
                    title: trimmedTitle,
                    content: trimmedContent
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                    
                    // Clear the form
                    title = ""
                    content = ""
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

struct JournalEntryCreateView_Previews: PreviewProvider {
    static var previews: some View {
        JournalEntryCreateView()
            .environmentObject(AuthenticationManager())
            .environment(\.theme, LiquidGlassTheme())
    }
} 