import SwiftUI
import MapKit

struct RecommendationDetailView: View {
    let recommendation: RecommendationItem
    @ObservedObject var viewModel: RecommendationsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingShareSheet = false
    @State private var showingMapView = false
    @State private var showingBookingView = false
    @State private var showingSimilarRecommendations = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero section
                        heroSection(geometry: geometry)
                        
                        // Content sections
                        VStack(spacing: 24) {
                            // Main info section
                            mainInfoSection
                            
                            // Personality match section (if available)
                            personalitySection
                            
                            // Description section
                            descriptionSection
                            
                            // Location section
                            locationSection
                            
                            // Additional details
                            detailsSection
                            
                            // Actions section
                            actionsSection
                            
                            // Similar recommendations
                            similarRecommendationsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for floating buttons
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
                .overlay(
                    floatingActionButtons,
                    alignment: .bottom
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        Button(action: { showingShareSheet.toggle() }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                        
                        // More options
                        Menu {
                            moreOptionsMenu
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareContent)
        }
        .sheet(isPresented: $showingMapView) {
            RecommendationMapView(recommendation: recommendation)
        }
        .sheet(isPresented: $showingBookingView) {
            BookingView(recommendation: recommendation)
        }
        .sheet(isPresented: $showingSimilarRecommendations) {
            SimilarRecommendationsView(
                basedOn: recommendation,
                viewModel: viewModel
            )
        }
    }
    
    // MARK: - Content Sections
    
    private func heroSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image or gradient
            Group {
                if let imageUrl = getImageUrl() {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        gradientPlaceholder
                    }
                } else {
                    gradientPlaceholder
                }
            }
            .frame(height: geometry.size.height * 0.4)
            .clipped()
            
            // Dark overlay for text readability
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geometry.size.height * 0.4)
            
            // Hero content
            VStack(alignment: .leading, spacing: 12) {
                // Category badge
                HStack {
                    categoryBadge
                    Spacer()
                }
                
                // Title
                Text(getTitle())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .lineLimit(2)
                
                // Subtitle info
                heroSubtitleInfo
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    private var gradientPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: getGradientColors(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Image(systemName: getCategoryIcon())
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
    
    private var categoryBadge: some View {
        Text(getCategory().capitalized)
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .foregroundColor(.white)
    }
    
    private var heroSubtitleInfo: some View {
        HStack(spacing: 16) {
            // Rating
            if let rating = getRating() {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(rating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                    }
                    Text(String(format: "(%.1f)", rating))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            // Distance/Location
            if let location = getLocationInfo() {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.subheadline)
                    Text(location)
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
    }
    
    private var mainInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick stats grid
            quickStatsGrid
            
            // Price and duration info
            priceAndDurationInfo
        }
        .padding(.top, 24)
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            if let rating = getRating() {
                QuickStatCard(
                    icon: "star.fill",
                    title: "Rating",
                    value: String(format: "%.1f", rating),
                    color: .yellow
                )
            }
            
            if let distance = getDistance() {
                QuickStatCard(
                    icon: "location.fill",
                    title: "Distance",
                    value: distance,
                    color: .blue
                )
            }
            
            QuickStatCard(
                icon: "clock.fill",
                title: "Duration",
                value: getDuration(),
                color: .green
            )
        }
    }
    
    private var priceAndDurationInfo: some View {
        HStack(spacing: 20) {
            if let price = getPrice() {
                DetailInfoChip(
                    icon: "dollarsign.circle.fill",
                    title: "Price",
                    value: price,
                    color: .green
                )
            }
            
            if let difficulty = getDifficulty() {
                DetailInfoChip(
                    icon: "gauge",
                    title: "Difficulty",
                    value: difficulty,
                    color: .orange
                )
            }
            
            Spacer()
        }
    }
    
    private var personalitySection: some View {
        Group {
            if let personalityMatch = getPersonalityMatch() {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.title3)
                        Text("Perfect Match")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        
                        if let score = getPersonalityScore() {
                            let percentage = Int(score * 100)
                            Text("\(percentage)% match")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(personalityMatch)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                .padding(16)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(getDescription())
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
            
            // Tags or specialties
            if let tags = getTags(), !tags.isEmpty {
                tagsView(tags)
            }
        }
    }
    
    private func tagsView(_ tags: [String]) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80))
        ], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }
    
    private var locationSection: some View {
        Group {
            if let location = getLocationInfo() {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button(action: { showingMapView.toggle() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if let distance = getDistance() {
                                    Text("\(distance) away")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(16)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let bestTime = getBestTime() {
                    DetailRow(
                        icon: "calendar",
                        title: "Best Time",
                        value: bestTime
                    )
                }
                
                if let groupSize = getIdealGroupSize() {
                    DetailRow(
                        icon: "person.2.fill",
                        title: "Group Size",
                        value: groupSize
                    )
                }
                
                if let requirements = getRequirements() {
                    DetailRow(
                        icon: "checkmark.circle",
                        title: "Requirements",
                        value: requirements
                    )
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Primary action
            Button(action: { showingBookingView.toggle() }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline)
                    Text("Plan This Experience")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Secondary actions
            HStack(spacing: 16) {
                if getLocationInfo() != nil {
                    Button(action: { showingMapView.toggle() }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                            Text("Map")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Button(action: { showingShareSheet.toggle() }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                        Text("Share")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private var similarRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Similar Experiences")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("See All") {
                    showingSimilarRecommendations.toggle()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            Text("You might also enjoy these recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Floating Actions
    
    private var floatingActionButtons: some View {
        HStack(spacing: 16) {
            // Favorite button
            Button(action: { toggleFavorite() }) {
                Image(systemName: isFavorite() ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(isFavorite() ? .white : .primary)
                    .frame(width: 50, height: 50)
                    .background(isFavorite() ? Color.red : Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
            
            // Main action button
            Button(action: { showingBookingView.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline)
                    Text("Plan Experience")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34) // Safe area padding
    }
    
    // MARK: - Menu and Actions
    
    private var moreOptionsMenu: some View {
        Group {
            Button(action: { toggleFavorite() }) {
                Label(isFavorite() ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: isFavorite() ? "heart.slash" : "heart")
            }
            
            Button(action: { showingSimilarRecommendations.toggle() }) {
                Label("Similar Recommendations", systemImage: "sparkles")
            }
            
            Button(action: { dismissRecommendation() }) {
                Label("Not Interested", systemImage: "eye.slash")
            }
        }
    }
    
    private var shareContent: [Any] {
        var items: [Any] = []
        items.append("Check out this recommendation: \(getTitle())")
        items.append(getDescription())
        return items
    }
    
    // MARK: - Data Accessors
    
    private func getTitle() -> String {
        switch recommendation {
        case .aiPowered(let activity): return activity.name
        case .grok(let rec): return rec.name
        case .simple(let rec): return rec.title
        }
    }
    
    private func getDescription() -> String {
        switch recommendation {
        case .aiPowered(let activity): return activity.description
        case .grok(let rec): return rec.description
        case .simple(let rec): return rec.description
        }
    }
    
    private func getCategory() -> String {
        switch recommendation {
        case .aiPowered(let activity): return activity.category ?? "experience"
        case .grok(let rec): return "local"
        case .simple(let rec): return rec.category
        }
    }
    
    private func getImageUrl() -> String? {
        switch recommendation {
        case .aiPowered(let activity): return activity.imageUrl
        case .grok: return nil
        case .simple: return nil
        }
    }
    
    private func getRating() -> Double? {
        switch recommendation {
        case .aiPowered(let activity): return activity.rating
        case .grok: return nil // GrokActivityRecommendation doesn't have rating
        case .simple: return nil
        }
    }
    
    private func getLocationInfo() -> String? {
        switch recommendation {
        case .aiPowered(let activity): return activity.location
        case .grok(let rec): return rec.location
        case .simple: return nil
        }
    }
    
    private func getDistance() -> String? {
        switch recommendation {
        case .aiPowered: return nil
        case .grok: return nil // GrokActivityRecommendation doesn't have distance
        case .simple: return nil
        }
    }
    
    private func getPrice() -> String? {
        switch recommendation {
        case .aiPowered(let activity):
            if let price = activity.estimatedPrice {
                return price == 0 ? "Free" : "$\(Int(price))"
            }
            return nil
        case .grok(let rec): return rec.estimatedCost
        case .simple: return nil
        }
    }
    
    private func getDuration() -> String {
        switch recommendation {
        case .aiPowered(let activity): return activity.estimatedDuration ?? "2-3 hours"
        case .grok(let rec): return rec.duration ?? "2-3 hours"
        case .simple: return "1-2 hours"
        }
    }
    
    private func getDifficulty() -> String? {
        return "Easy" // Placeholder
    }
    
    private func getPersonalityMatch() -> String? {
        switch recommendation {
        case .aiPowered(let activity): return activity.personalityMatch
        case .grok: return nil
        case .simple: return nil
        }
    }
    
    private func getPersonalityScore() -> Double? {
        switch recommendation {
        case .aiPowered(let activity): return activity.personalityMatchScore
        case .grok: return nil
        case .simple: return nil
        }
    }
    
    private func getTags() -> [String]? {
        switch recommendation {
        case .aiPowered: return nil
        case .grok(let rec): return rec.tips
        case .simple: return nil
        }
    }
    
    private func getBestTime() -> String? {
        return "Afternoon" // Placeholder
    }
    
    private func getIdealGroupSize() -> String? {
        return "2-4 people" // Placeholder
    }
    
    private func getRequirements() -> String? {
        return "No special requirements" // Placeholder
    }
    
    private func getCategoryIcon() -> String {
        switch getCategory().lowercased() {
        case "dining": return "fork.knife"
        case "outdoor": return "leaf.fill"
        case "cultural": return "building.columns"
        case "active": return "figure.run"
        case "local": return "location.fill"
        default: return "star.fill"
        }
    }
    
    private func getGradientColors() -> [Color] {
        switch getCategory().lowercased() {
        case "dining": return [Color.orange.opacity(0.6), Color.red.opacity(0.6)]
        case "outdoor": return [Color.green.opacity(0.6), Color.mint.opacity(0.6)]
        case "cultural": return [Color.purple.opacity(0.6), Color.blue.opacity(0.6)]
        case "active": return [Color.blue.opacity(0.6), Color.cyan.opacity(0.6)]
        default: return [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]
        }
    }
    
    private func isFavorite() -> Bool {
        let id = getId()
        return viewModel.favoriteRecommendations.contains(id)
    }
    
    private func getId() -> String {
        switch recommendation {
        case .aiPowered(let activity): return String(activity.id)
        case .grok(let rec): return rec.name // GrokActivityRecommendation doesn't have id, use name
        case .simple(let rec): return rec.id ?? rec.title
        }
    }
    
    private func toggleFavorite() {
        viewModel.toggleFavorite(for: getId())
        trackInteraction(.favorite)
    }
    
    private func dismissRecommendation() {
        viewModel.dismissRecommendation(id: getId())
        trackInteraction(.dismiss)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func trackInteraction(_ type: RecommendationInteraction.InteractionType) {
        let interaction = RecommendationInteraction(
            recommendationId: getId(),
            type: type,
            category: getCategory(),
            timestamp: Date()
        )
        viewModel.trackRecommendationInteraction(interaction)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailInfoChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// Using DetailRow from UIComponents.swift

// MARK: - Modal Views

struct RecommendationMapView: View {
    let recommendation: RecommendationItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Placeholder map view
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Map View")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if let location = getLocationText() {
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    )
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func getLocationText() -> String? {
        switch recommendation {
        case .aiPowered(let activity): return activity.location
        case .grok(let rec): return rec.location
        case .simple: return nil
        }
    }
}

struct BookingView: View {
    let recommendation: RecommendationItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Plan Your Experience")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Feature coming soon! You'll be able to plan and book this experience directly from the app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("Got It") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .navigationTitle("Plan Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SimilarRecommendationsView: View {
    let basedOn: RecommendationItem
    @ObservedObject var viewModel: RecommendationsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                VStack(spacing: 12) {
                    Text("Similar Recommendations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("We're finding more experiences like this one based on your preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .navigationTitle("Similar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}


#Preview {
    RecommendationDetailView(
        recommendation: .aiPowered(AIPoweredActivity(
            id: 1,
            name: "Romantic Sunset Dinner",
            description: "Experience an intimate dining experience with breathtaking city views and carefully curated menu featuring locally sourced ingredients.",
            category: "dining",
            rating: 4.8,
            personalityMatch: "Perfect for quality time together and meaningful conversations",
            distance: "2.3 mi",
            imageUrl: nil,
            location: "Downtown, 123 Main St"
        )),
        viewModel: RecommendationsViewModel()
    )
}