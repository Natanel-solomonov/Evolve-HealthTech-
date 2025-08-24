import SwiftUI

@MainActor
class ReadingContentViewModel: ObservableObject {
    @Published var readingContents: [ReadingContentModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let readingContentAPI: ReadingContentAPI
    private let authManager: AuthenticationManager // To access httpClient or authToken if needed directly by API

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        self.readingContentAPI = ReadingContentAPI(httpClient: authManager.httpClient)
    }
    
    func fetchReadingContents() {
        isLoading = true
        // Temporarily disabled network fetch
        /*
        readingContentAPI.fetchReadingContents { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let contents):
                    self?.readingContents = contents
                case .failure(let error):
                    print("Error fetching reading contents: \(error)")
                }
            }
        }
        */
        
        // Set loading to false since we're not making network calls
        isLoading = false
    }
}

struct ReadingContentListView: View {
    @StateObject private var viewModel: ReadingContentViewModel
    @State private var selectedContent: ReadingContentModel? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme

    init(authManager: AuthenticationManager) {
        _viewModel = StateObject(wrappedValue: ReadingContentViewModel(authManager: authManager))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text("Error loading content")
                            .font(.system(size: 17))
                        Text(errorMessage)
                            .font(.system(size: 15))
                            .foregroundColor(theme.secondaryText)
                        Button("Try Again") {
                            // viewModel.fetchReadingContents() // Temporarily disabled
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top)
                    }
                    .padding()
                } else if viewModel.readingContents.isEmpty {
                    Text("No reading content available")
                        .font(.system(size: 17))
                        .foregroundColor(theme.secondaryText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.readingContents) { content in
                                ReadingContentCard(content: content)
                                    .onTapGesture {
                                        selectedContent = content
                                    }
                            }
                        }
                        .padding()
                    }
                    .fullScreenCover(item: $selectedContent) { content in
                        ContentCardView(readingContent: content)
                    }
                }
            }
            .navigationTitle("Reading Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(theme.primaryText)
                            .font(.system(size: 22))
                    }
                }
            }
            .onAppear {
                // viewModel.fetchReadingContents() // Temporarily disabled
            }
        }
    }
    
    private func getCategoryColor(for category: String) -> Color {
        // Map categories to colors - can be expanded as needed
        switch category.lowercased() {
        case "fitness":
            return Color("Fitness")
        case "nutrition":
            return Color("Nutrition")
        case "mindfulness":
            return Color("Mindfulness")
        default:
            return Color.blue
        }
    }
}

struct ReadingContentCard: View {
    let content: ReadingContentModel
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coverImage = content.coverImage, let url = URL(string: coverImage) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .cornerRadius(12)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .cornerRadius(12)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(theme.secondaryText)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .cornerRadius(12)
                    }
                }
                .frame(height: 160)
            } else {
                // Placeholder when no image is available
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fill)
                    .cornerRadius(12)
                    .frame(height: 160)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(theme.secondaryText)
                            .font(.largeTitle)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.system(size: 17))
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                HStack {
                    Text(content.duration)
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                    
                    Spacer()
                    
                    ForEach(content.category.prefix(2), id: \.self) { category in
                        Text(category)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getCategoryColor(for: category).opacity(0.2))
                            .foregroundColor(getCategoryColor(for: category))
                            .cornerRadius(8)
                    }
                }
                
                if let description = content.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .themedFill(theme.cardStyle)
        )
        .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
    }
    
    private func getCategoryColor(for category: String) -> Color {
        // Map categories to colors - can be expanded as needed
        switch category.lowercased() {
        case "fitness":
            return Color("Fitness")
        case "nutrition":
            return Color("Nutrition")
        case "mindfulness":
            return Color("Mindfulness")
        default:
            return Color.blue
        }
    }
}

struct ReadingContentListView_Previews: PreviewProvider {
    static var previews: some View {
        ReadingContentListView(authManager: AuthenticationManager())
    }
} 
