import SwiftUI

// MARK: - AI-Powered Activity Card

struct AIPoweredActivityCard: View {
    let activity: AIPoweredActivity
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header with image and basic info
                headerSection
                
                // Content section
                contentSection
                
                // Personality match section (if available)
                if let match = activity.personalityMatch {
                    personalityMatchSection(match)
                }
                
                // Action bar
                actionBarSection
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Activity image
            AsyncImage(url: URL(string: activity.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Activity info
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let location = activity.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Rating and category
                HStack(spacing: 12) {
                    if let rating = activity.rating {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { star in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(star < Int(rating) ? .yellow : .gray.opacity(0.3))
                            }
                            Text("(\(rating, specifier: "%.1f"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(activity.category.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activity.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Additional details
            HStack(spacing: 16) {
                if let duration = activity.estimatedDuration {
                    DetailChip(icon: "clock", text: duration, color: .blue)
                }
                
                if let price = activity.estimatedPrice {
                    let priceText = price == 0 ? "Free" : "$\(Int(price))"
                    DetailChip(icon: "dollarsign.circle", text: priceText, color: .green)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func personalityMatchSection(_ match: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundColor(.purple)
            
            Text("✨ \(match)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            
            Spacer()
            
            if let score = activity.personalityMatchScore {
                let percentage = Int(score * 100)
                Text("\(percentage)% match")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.purple.opacity(0.05))
    }
    
    private var actionBarSection: some View {
        HStack(spacing: 16) {
            // Favorite button
            Button(action: onFavorite) {
                HStack(spacing: 4) {
                    Image(systemName: activity.isFavoriteValue ? "heart.fill" : "heart")
                        .font(.subheadline)
                    Text(activity.isFavoriteValue ? "Favorited" : "Favorite")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(activity.isFavoriteValue ? .red : .secondary)
            }
            
            Spacer()
            
            // Action indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle")
                    .font(.subheadline)
                Text("View Details")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(action: onFavorite) {
                Label(activity.isFavoriteValue ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: activity.isFavoriteValue ? "heart.slash" : "heart")
            }
            
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onDismiss) {
                Label("Not Interested", systemImage: "eye.slash")
            }
            
            Button(action: {}) {
                Label("Save for Later", systemImage: "bookmark")
            }
        }
    }
}

// MARK: - Grok Recommendation Card

struct GrokRecommendationCard: View {
    let recommendation: GrokActivityRecommendation
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header section
                headerSection
                
                // Content section
                contentSection
                
                // Specialties section
                if let specialties = recommendation.specialties, !specialties.isEmpty {
                    specialtiesSection(specialties)
                }
                
                // Action bar
                actionBarSection
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let address = recommendation.address {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Distance indicator
                if let distance = recommendation.distance {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.1f", distance)) mi")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Image(systemName: "location.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Rating and price row
            HStack(spacing: 16) {
                if let rating = recommendation.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { star in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(star < Int(rating) ? .yellow : .gray.opacity(0.3))
                        }
                        Text("(\(rating, specifier: "%.1f"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let price = recommendation.price {
                    Text(price)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var contentSection: some View {
        Text(recommendation.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    
    private func specialtiesSection(_ specialties: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(specialties.prefix(4), id: \.self) { specialty in
                    Text(specialty)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
                
                if specialties.count > 4 {
                    Text("+\(specialties.count - 4) more")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
    
    private var actionBarSection: some View {
        HStack(spacing: 16) {
            // Favorite button
            Button(action: onFavorite) {
                HStack(spacing: 4) {
                    Image(systemName: recommendation.isFavoriteValue ? "heart.fill" : "heart")
                        .font(.subheadline)
                    Text(recommendation.isFavoriteValue ? "Favorited" : "Favorite")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(recommendation.isFavoriteValue ? .red : .secondary)
            }
            
            Spacer()
            
            // Directions button
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                    Text("Directions")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(action: onFavorite) {
                Label(recommendation.isFavoriteValue ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: recommendation.isFavoriteValue ? "heart.slash" : "heart")
            }
            
            Button(action: {}) {
                Label("Get Directions", systemImage: "location.fill")
            }
            
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onDismiss) {
                Label("Not Interested", systemImage: "eye.slash")
            }
        }
    }
}

// MARK: - Simple Recommendation Card

struct SimpleRecommendationCard: View {
    let recommendation: SimpleRecommendation
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: categoryIcon)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(categoryColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(recommendation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Text(recommendation.category.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .foregroundColor(categoryColor)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Favorite indicator
                        if recommendation.isFavoriteValue {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Action indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var categoryIcon: String {
        switch recommendation.category.lowercased() {
        case "romantic": return "heart.fill"
        case "adventure": return "mountain.2.fill"
        case "creative": return "paintbrush.fill"
        case "relaxed": return "leaf.fill"
        case "cultural": return "building.columns.fill"
        case "active": return "figure.run"
        case "dining": return "fork.knife"
        default: return "star.fill"
        }
    }
    
    private var categoryColor: Color {
        switch recommendation.category.lowercased() {
        case "romantic": return .red
        case "adventure": return .blue
        case "creative": return .purple
        case "relaxed": return .green
        case "cultural": return .orange
        case "active": return .mint
        case "dining": return .brown
        default: return .gray
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(action: onFavorite) {
                Label(recommendation.isFavoriteValue ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: recommendation.isFavoriteValue ? "heart.slash" : "heart")
            }
            
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onDismiss) {
                Label("Not Interested", systemImage: "eye.slash")
            }
            
            Button(action: {}) {
                Label("Similar Recommendations", systemImage: "sparkles")
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Loading Card

struct RecommendationLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                        .frame(height: 12)
                        .frame(maxWidth: .infinity * 0.7)
                    
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 60, height: 16)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 40, height: 16)
                    }
                }
                
                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.3))
                .frame(height: 12)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.3))
                .frame(height: 12)
                .frame(maxWidth: .infinity * 0.8)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .redacted(reason: .placeholder)
    }
}

// MARK: - Empty State Card

struct RecommendationEmptyCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action {
                Button("Refresh") {
                    action()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Model Extensions

extension AIPoweredActivity {
    var estimatedDuration: String? {
        // Would be part of actual model
        return "2-3 hours"
    }
    
    var estimatedPrice: Double? {
        // Would be part of actual model
        return 45.0
    }
    
    // category property is already defined in the main struct
    
    var personalityMatchScore: Double? {
        // Would be part of actual model
        return 0.85
    }
    
    var isFavoriteValue: Bool {
        // Would be part of actual model - temporary mock
        return false
    }
}

extension GrokActivityRecommendation {
    var isFavoriteValue: Bool {
        // Would be part of actual model - temporary mock
        return false
    }
}

extension SimpleRecommendation {
    var isFavoriteValue: Bool {
        // Would be part of actual model - temporary mock
        return false
    }
}

#Preview("AI-Powered Card") {
    AIPoweredActivityCard(
        activity: AIPoweredActivity(
            id: 1,
            name: "Romantic Sunset Dinner",
            description: "Experience an intimate dining experience with breathtaking city views and carefully curated menu.",
            category: "dining",
            rating: 4.8,
            personalityMatch: "Perfect for quality time together",
            distance: "2.3 mi",
            imageUrl: nil,
            location: "Downtown, 123 Main St"
        ),
        onTap: {},
        onFavorite: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Simple Card") {
    SimpleRecommendationCard(
        recommendation: SimpleRecommendation(
            title: "Art Gallery Walk",
            description: "Explore local art galleries and discover new artists together.",
            category: "cultural"
        ),
        onTap: {},
        onFavorite: {},
        onDismiss: {}
    )
    .padding()
}