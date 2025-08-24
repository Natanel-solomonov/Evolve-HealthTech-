import SwiftUI

struct ContentCard: View {
  let text: String
  let bolded_words: [String]
  let highlightColor: Color
  @Environment(\.theme) private var theme: any Theme

  private var attributedText: AttributedString {
    var attributedString = AttributedString(text)

    // Define base and bold fonts
    let baseFont = Font.system(size: 45) // Regular weight by default
    let boldFont = Font.system(size: 45)
    let baseColor = theme.primaryText.opacity(0.7)

    // Apply base styling to the whole string
    attributedString.font = baseFont
    attributedString.foregroundColor = baseColor

    for word in bolded_words {
        var searchRange = attributedString.startIndex..<attributedString.endIndex
        while let range = attributedString[searchRange].range(of: word, options: .caseInsensitive) {
            // Apply highlight color and bold font to the found range
            attributedString[range].foregroundColor = highlightColor
            attributedString[range].font = boldFont
            // Update the search range
            searchRange = range.upperBound..<searchRange.upperBound
        }
    }
    return attributedString 
  }

  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 30)
        .themedFill(theme.cardStyle)
        .shadow(
          color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y
        )

      Text(attributedText)
        .padding(30)
        .padding(.top, 30)
    }
    .frame(width: 400, height: 750);
  }
} 

struct ContentCard_Previews: PreviewProvider {
  static var previews: some View {
    ContentCard(
        text: "Soluble fiber, found in foods like oats, apples, and beans, dissolves in water and helps lower cholesterol and manage blood sugar.",
        bolded_words: ["Soluble fiber", "oats", "apples", "beans"],
        highlightColor: Color("Fitness")
    )
  }
}

// --- New Code Starts Here ---

// Data structure for a card
struct CardData: Identifiable {
    let id = UUID()
    let text: String
    let boldedWords: [String]
    let highlightColor: Color
}

// Sample data for the view
let sampleCards = [
    CardData(text: "Soluble fiber, found in foods like oats, apples, and beans, dissolves in water and helps lower cholesterol and manage blood sugar.", boldedWords: ["Soluble fiber", "oats", "apples", "beans"], highlightColor: Color("Fitness")),
    CardData(text: "Insoluble fiber, found in whole grains and vegetables, does not dissolve in water and helps move material through your digestive system.", boldedWords: ["Insoluble fiber", "whole grains", "vegetables"], highlightColor: Color("Fitness")),
    CardData(text: "Dietary fiber is important for maintaining bowel health, controlling blood sugar levels, and achieving a healthy weight.", boldedWords: ["Dietary fiber", "bowel health", "blood sugar", "healthy weight"], highlightColor: Color("Fitness")),
    CardData(text: "Soluble fiber, found in foods like oats, apples, and beans, dissolves in water and helps lower cholesterol and manage blood sugar.", boldedWords: ["Soluble fiber", "oats", "apples", "beans"], highlightColor: Color("Fitness")),
    CardData(text: "Insoluble fiber, found in whole grains and vegetables, does not dissolve in water and helps move material through your digestive system.", boldedWords: ["Insoluble fiber", "whole grains", "vegetables"], highlightColor: Color("Fitness")),
    CardData(text: "Dietary fiber is important for maintaining bowel health, controlling blood sugar levels, and achieving a healthy weight.", boldedWords: ["Dietary fiber", "bowel health", "blood sugar", "healthy weight"], highlightColor: Color("Fitness"))
]

// The view containing the swipeable cards and progress bar
struct ContentCardView: View {
    let cards: [CardData]
    let title: String
    @State private var currentIndex = 0
    @Environment(\.dismiss) var dismiss
    let onComplete: (() -> Void)?
    @Environment(\.theme) private var theme: any Theme

    // Default initializer
    init(cards: [CardData], title: String = "", onComplete: (() -> Void)? = nil) {
        self.cards = cards
        self.title = title
        self.onComplete = onComplete
    }
    
    // Convenience initializer from a ReadingContentModel
    init(readingContent: ReadingContentModel, onComplete: (() -> Void)? = nil) {
        self.title = readingContent.title
        self.onComplete = onComplete
        
        // Convert ContentCardModel to CardData, handling optional contentCards
        self.cards = (readingContent.contentCards ?? []).map { cardModel in // Safely unwrap or use empty array
            let categoryColor = readingContent.category.first.flatMap { category -> Color in
                switch category.lowercased() {
                case "fitness":
                    return Color("Fitness")
                case "nutrition":
                    return Color("Nutrition")
                case "mind": 
                    return Color("Mind")
                case "sleep": 
                    return Color("Sleep")
                case "productivity": 
                    return Color("Productivity")
                default:
                    return Color.blue // Default color
                }
            } ?? Color.blue // Default if no category or category not recognized
            
            return CardData(
                text: cardModel.text, // cardModel is now guaranteed to be a non-optional ContentCardModel
                boldedWords: cardModel.boldedWords ?? [], // boldedWords is optional on ContentCardModel
                highlightColor: categoryColor
            )
        }
    }

    var body: some View {
        VStack { // Outer VStack to hold Header and the rest
//            ChatHeaderView(showBackButton: true, showEllipsisButton: true, onDismiss: {
//                self.onComplete?()
//                dismiss()
//            })
            
           

            TabView(selection: $currentIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, cardData in
                    ContentCard(text: cardData.text, bolded_words: cardData.boldedWords, highlightColor: cardData.highlightColor)
                        .tag(index) // Tag for TabView selection tracking
                        .padding(.horizontal) // Revert to default padding for cards
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Use page style, hide default dots
            .zIndex(10) // Ensure cards render above the progress bar/button

            // Conditionally display Progress Bar or Complete Button
            if currentIndex == cards.count - 1 {
                // Show Complete button on the last card
                Button("Complete") {
                    // Add action for the complete button later
                    print("Content Completed!")
                    self.onComplete?()
                    dismiss()
                }
                .font(.system(size: 17))
                .frame(maxWidth: .infinity)
                .frame(height: 50) // Give button a decent height
                .background(theme.accent)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 50) // Match progress bar padding
                .padding(.top, 15) // Match progress bar padding
                .frame(height: 21) // Match the space the progress bar + padding took (6 + 15)

            } else {
                // Show Progress Bar on other cards
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.secondaryText.opacity(0.3)) // Background track
                            .frame(height: 6)

                        if cards.count > 1 {
                            Capsule()
                                .fill(theme.primaryText) // Progress fill
                                .frame(width: geometry.size.width * CGFloat(currentIndex) / CGFloat(cards.count - 1), height: 6)
                        } else {
                            // Handle single card case (optional: show full bar or nothing)
                             Capsule()
                                .fill(theme.primaryText)
                                .frame(height: 6)
                        }
                    }
                }
                .frame(height: 6) // Set the height for the GeometryReader container
                .padding(.horizontal, 50) // Apply larger padding to the progress bar
                .padding(.top, 15) // Add some space above the progress bar
            }
        }
    }
}

// Preview for the new ContentCardView
struct ContentCardView_Previews: PreviewProvider {
    static var previews: some View {
        ContentCardView(cards: sampleCards, title: "All About Fiber", onComplete: {
            print("Preview: ContentCardView dismissed or completed.")
        })
    }
}
