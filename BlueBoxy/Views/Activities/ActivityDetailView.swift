import SwiftUI
import MapKit

struct ActivityDetailView: View {
    let activity: Activity
    @ObservedObject var viewModel: EnhancedActivitiesViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var showingMap = false
    @State private var region = MKCoordinateRegion()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Image
                        heroImageSection(geometry: geometry)
                        
                        // Content
                        VStack(spacing: 24) {
                            // Header section
                            headerSection
                            
                            // Quick stats
                            quickStatsSection
                            
                            // Personality match (if available)
                            if activity.personalityMatch != nil {
                                personalityMatchSection
                            }
                            
                            // Description
                            descriptionSection
                            
                            // Location section
                            locationSection
                            
                            // Additional details
                            additionalDetailsSection
                            
                            // Action buttons
                            actionButtonsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Extra padding for action buttons
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
                .overlay(
                    // Floating action buttons
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
                        
                        // Bookmark button
                        Button(action: { viewModel.toggleBookmark(for: activity.id) }) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundColor(isBookmarked ? .blue : .primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareContent)
            }
            .sheet(isPresented: $showingMap) {
                MapView(activity: activity)
            }
        }
    }
    
    private var isBookmarked: Bool {
        viewModel.bookmarkedActivities.contains(activity.id)
    }
    
    private var shareContent: [Any] {
        var items: [Any] = []
        items.append("Check out this activity: \(activity.name)")
        items.append(activity.description)
        // Could add URL or deep link here
        return items
    }
    
    private func heroImageSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            AsyncImage(url: URL(string: activity.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            .frame(height: geometry.size.height * 0.4)
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geometry.size.height * 0.4)
            
            // Title overlay
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(activity.category.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .background(.ultraThinMaterial)
                    
                    Spacer()
                }
                
                Text(activity.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rating and distance
            HStack {
                if let rating = activity.rating {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                        }
                        Text("(\(rating, specifier: "%.1f"))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let distance = activity.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(distance)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Duration
            if let duration = activity.duration {
                StatCard(
                    icon: "clock",
                    title: "Duration",
                    value: duration,
                    color: .blue
                )
            }
            
            // Price
            if let cost = activity.estimatedCost {
                StatCard(
                    icon: "dollarsign.circle",
                    title: "Price",
                    value: cost,
                    color: .green
                )
            }
            
            // Difficulty (placeholder)
            StatCard(
                icon: "gauge",
                title: "Difficulty",
                value: "Easy", // TODO: Add difficulty property to Activity model
                color: .orange
            )
        }
    }
    
    private var personalityMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                Text("Perfect for You")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                if let score = activity.personalityMatchScore {
                    let percentage = Int(score * 100)
                    Text("\(percentage)% match")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }
            }
            
            if let match = activity.personalityMatch {
                Text(match)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(activity.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
            
            // Tags (if available)
            if let tags = activity.tags, !tags.isEmpty {
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
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let location = activity.location {
                Button(action: { showingMap.toggle() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if let distance = activity.distance {
                                Text(distance)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var additionalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Best time
                if let bestTime = activity.bestTimeOfDay {
                    DetailRow(
                        icon: "calendar",
                        title: "Best Time",
                        value: bestTime
                    )
                }
                
                // Group size
                if let groupSize = activity.groupSize {
                    DetailRow(
                        icon: "person.2.fill",
                        title: "Group Size",
                        value: groupSize
                    )
                }
                
                // Requirements (placeholder)
                // TODO: Add requirements property to Activity model
                DetailRow(
                    icon: "checkmark.circle",
                    title: "Requirements",
                    value: "No special requirements"
                )
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary action button (Book/Plan)
            Button(action: {
                // Handle booking/planning action
            }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline)
                    Text("Plan This Activity")
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
                // Directions button
                if activity.location != nil {
                    Button(action: {
                        // Open in maps
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                            Text("Directions")
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
                
                // Contact/Website button
                Button(action: {
                    // Open website or contact
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.subheadline)
                        Text("Website")
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
    
    private var floatingActionButtons: some View {
        HStack(spacing: 16) {
            // Bookmark button
            Button(action: { viewModel.toggleBookmark(for: activity.id) }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundColor(isBookmarked ? .white : .primary)
                    .frame(width: 50, height: 50)
                    .background(isBookmarked ? Color.blue : Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
            
            // Plan activity button
            Button(action: {
                // Handle planning action
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline)
                    Text("Plan Activity")
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
}

// MARK: - Supporting Views

// StatCard and DetailRow are defined in Views/Components/UIComponents.swift

struct MapView: View {
    let activity: Activity
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Placeholder for map - would use MapKit in real implementation
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
                            
                            if let location = activity.location {
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
}

// ShareSheet is defined in Views/Components/UIComponents.swift

// MARK: - Activity Model Extensions

extension Activity {
    var estimatedDuration: String? {
        // Would be part of the actual model
        return "2-3 hours" // Placeholder
    }
    
    var difficulty: String? {
        // Would be part of the actual model
        return "Easy" // Placeholder
    }
    
    var bestTimeToVisit: String? {
        // Would be part of the actual model
        return "Afternoon" // Placeholder
    }
    
    var idealGroupSize: String? {
        // Would be part of the actual model
        return "2-4 people" // Placeholder
    }
    
    var requirements: String? {
        // Would be part of the actual model
        return "No special requirements" // Placeholder
    }
}

#Preview {
    ActivityDetailView(
        activity: Activity(
            id: 1,
            name: "Romantic Dinner at Sunset Bistro",
            description: "Experience an intimate dining experience with breathtaking city views. Our carefully curated menu features locally sourced ingredients and pairs perfectly with our extensive wine selection.",
            category: "dining",
            location: "Downtown, 123 Main St",
            rating: 4.8,
            distance: "2.3 mi",
            personalityMatch: "Perfect for quality time together and meaningful conversations",
            imageUrl: nil
        ),
        viewModel: EnhancedActivitiesViewModel()
    )
}