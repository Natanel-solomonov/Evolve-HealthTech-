import SwiftUI

struct JournalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var showCreateView: Bool = false
    @State private var showListView: Bool = false
    
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
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Header section with logo/icon
                    VStack(spacing: 16) {
                        // Journal icon with glow effect
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                            
                            Circle()
                                .fill(.white.opacity(0.05))
                                .frame(width: 100, height: 100)
                                .blur(radius: 10)
                            
                            // Main icon
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.15))
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Text("Journal")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Capture your thoughts, feelings, and daily reflections")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Create new entry button
                        Button(action: { showCreateView = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Create New Entry")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // View all entries button
                        Button(action: { showListView = true }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                Text("View All Entries")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
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
        .fullScreenCover(isPresented: $showCreateView) {
            JournalEntryCreateView()
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showListView) {
            JournalEntryListView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - Preview

struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
            .environmentObject(AuthenticationManager())
            .environment(\.theme, LiquidGlassTheme())
    }
} 