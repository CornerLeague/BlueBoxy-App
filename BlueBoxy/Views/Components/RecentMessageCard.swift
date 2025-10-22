//
//  RecentMessageCard.swift
//  BlueBoxy
//
//  UI component for displaying individual recent messages in a card format.
//

import SwiftUI

struct RecentMessageCard: View {
    let message: RecentMessage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with category and time
                HStack {
                    // Category chip
                    HStack(spacing: 4) {
                        if let categoryType = message.categoryColor {
                            Image(systemName: categoryType.systemImageName)
                                .font(.caption2)
                                .foregroundStyle(categoryType.displayColor)
                        }
                        
                        Text(message.categoryName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (message.categoryColor?.displayColor ?? Color.gray).opacity(0.1)
                    )
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Time ago
                    Text(message.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                // Message content
                Text(message.previewText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Footer with metadata
                HStack {
                    // Word count
                    HStack(spacing: 4) {
                        Image(systemName: "textformat")
                            .font(.caption2)
                        Text("\(message.metadata.wordCount) words")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Favorite indicator
                    if message.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(RecentMessageButtonStyle())
    }
}

// MARK: - Button Style

struct RecentMessageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct RecentMessageCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            RecentMessageCard(
                message: RecentMessage(
                    id: "1",
                    content: "Good morning beautiful! I hope your day is filled with amazing opportunities and wonderful moments. Can't wait to hear about everything when you get home.",
                    category: "good_morning",
                    categoryName: "Good Morning",
                    generatedAt: Date().addingTimeInterval(-3600), // 1 hour ago
                    savedAt: Date().addingTimeInterval(-3600),
                    isFavorite: true,
                    metadata: RecentMessage.MessageMetadata(
                        wordCount: 23,
                        tone: "warm",
                        personalityMatch: "Thoughtful Harmonizer",
                        estimatedImpact: "medium"
                    )
                )
            ) {
                print("Tapped message 1")
            }
            
            RecentMessageCard(
                message: RecentMessage(
                    id: "2",
                    content: "Just wanted to check in and see how your presentation went today. You were so well prepared - I'm sure it went amazingly!",
                    category: "daily_checkins",
                    categoryName: "Daily Check-ins",
                    generatedAt: Date().addingTimeInterval(-7200), // 2 hours ago
                    savedAt: Date().addingTimeInterval(-7200),
                    isFavorite: false,
                    metadata: RecentMessage.MessageMetadata(
                        wordCount: 20,
                        tone: "supportive",
                        personalityMatch: "Thoughtful Harmonizer",
                        estimatedImpact: "high"
                    )
                )
            ) {
                print("Tapped message 2")
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif