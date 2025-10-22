import SwiftUI

struct RecommendationsView: View {
    @StateObject private var viewModel = RecommendationsViewModel()
    @State private var showingFilters = false
    @State private var showingStats = false
    @State private var selectedRecommendation: RecommendationItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with category selector
                    headerSection
                    
                    // Main content
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Personalized AI Recommendations Section
                            aiPoweredSection
                            
                            // Location-Based Recommendations Section
                            locationBasedSection
                            
                            // Quick Ideas Section
                            quickIdeasSection
                            
                            // Insights Section
                            if viewModel.recommendationStats.totalRecommendations > 0 {
                                insightsSection
                            }
                        }
                        .padding()
                        .padding(.bottom, 100) // Extra space for tab bar
                    }
                    .refreshable {
                        await viewModel.regenerateRecommendations()
                    }
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Filter button
                        Button(action: { showingFilters.toggle() }) {
                            ZStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.primary)
                                
                                // Filter indicator
                                if hasActiveFilters {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        // Refresh button
                        Button(action: {
                            Task {
                                await viewModel.regenerateRecommendations()
                            }
                        }) {
                            Image(systemName: viewModel.isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                                .foregroundColor(.primary)
                                .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                                .animation(
                                    viewModel.isRefreshing ? 
                                        .linear(duration: 1).repeatForever(autoreverses: false) : 
                                        .default,
                                    value: viewModel.isRefreshing
                                )
                        }
                        .disabled(viewModel.isRefreshing)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                RecommendationFiltersView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingStats) {
                RecommendationStatsView(viewModel: viewModel)
            }
            .sheet(item: $selectedRecommendation) { recommendation in
                RecommendationDetailView(
                    recommendation: recommendation,
                    viewModel: viewModel
                )
            }
        }
        .task {
            await viewModel.loadAllRecommendations()
        }
    }
    
    private var hasActiveFilters: Bool {
        let filters = viewModel.filterOptions
        return filters.priceRange != .all ||
               filters.timeOfDay != .any ||
               filters.groupSize != .any ||
               filters.maxDistance != 25.0
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Category selector
            CategorySelectorView(
                categories: viewModel.availableCategories,
                selectedCategory: $viewModel.selectedCategory
            )
            .onChange(of: viewModel.selectedCategory) { _, newCategory in
                viewModel.changeCategory(newCategory)
            }
            
            // Location status bar
            if !viewModel.hasLocationPermission {
                locationStatusBar
            }
        }
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private var locationStatusBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash")
                .foregroundColor(.orange)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Location Disabled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Enable for personalized nearby recommendations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Enable") {
                viewModel.requestLocationPermission()
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
    }
    
    private var aiPoweredSection: some View {
        RecommendationsSectionView(
            title: "Perfect for You",
            subtitle: "AI-curated based on your personality",
            icon: "sparkles",
            accentColor: .purple,
            state: viewModel.aiPoweredRecs,
            onRetry: {
                Task {
                    await viewModel.loadAIPoweredRecommendations(
                        category: viewModel.selectedCategory,
                        location: viewModel.userLocation
                    )
                }
            }
        ) { response in
            LazyVStack(spacing: 12) {
                ForEach(response.recommendations.activities.filter { !$0.isDismissed }, id: \.id) { activity in
                    AIPoweredActivityCard(
                        activity: activity,
                        onTap: {
                            selectedRecommendation = .aiPowered(activity)
                            trackInteraction(.view, for: String(activity.id), category: viewModel.selectedCategory)
                        },
                        onFavorite: {
                            viewModel.toggleFavorite(for: String(activity.id))
                            trackInteraction(.favorite, for: String(activity.id), category: viewModel.selectedCategory)
                        },
                        onDismiss: {
                            viewModel.dismissRecommendation(id: String(activity.id))
                            trackInteraction(.dismiss, for: String(activity.id), category: viewModel.selectedCategory)
                        }
                    )
                }
                
                // Note: AIPoweredRecommendationsResponse doesn't have canGenerateMore property
                Button("Show More Recommendations") {
                    Task {
                        await viewModel.loadAIPoweredRecommendations(
                            category: viewModel.selectedCategory,
                            location: viewModel.userLocation
                        )
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 8)
            }
        }
    }
    
    private var locationBasedSection: some View {
        Group {
            if viewModel.canShowLocationBasedRecs {
                RecommendationsSectionView(
                    title: "Near You",
                    subtitle: "Local spots matching your style",
                    icon: "location.fill",
                    accentColor: .green,
                    state: viewModel.grokRecs,
                    onRetry: {
                        guard let location = viewModel.userLocation else { return }
                        Task {
                            await viewModel.loadGrokRecommendations(
                                location: location,
                                category: viewModel.selectedCategory
                            )
                        }
                    }
                ) { response in
                    LazyVStack(spacing: 12) {
                        ForEach(response.recommendations, id: \.id) { activity in
                            // TODO: Create a card component that accepts Activity instead of GrokActivityRecommendation
                            // For now, use AIPoweredActivityCard as it can handle Activity-like objects
                            AIPoweredActivityCard(
                                activity: AIPoweredActivity(
                                    id: activity.id,
                                    name: activity.name,
                                    description: activity.description,
                                    category: activity.category,
                                    rating: activity.rating,
                                    personalityMatch: activity.personalityMatch,
                                    distance: activity.distance,
                                    imageUrl: activity.imageUrl,
                                    location: activity.location
                                ),
                                onTap: {
                                    // TODO: Create RecommendationItem case for Activity
                                    trackInteraction(.view, for: String(activity.id), category: viewModel.selectedCategory)
                                },
                                onFavorite: {
                                    viewModel.toggleFavorite(for: String(activity.id))
                                    trackInteraction(.favorite, for: String(activity.id), category: viewModel.selectedCategory)
                                },
                                onDismiss: {
                                    viewModel.dismissRecommendation(id: String(activity.id))
                                    trackInteraction(.dismiss, for: String(activity.id), category: viewModel.selectedCategory)
                                }
                            )
                        }
                        
                        if response.canGenerateMore {
                            Button("Find More Nearby") {
                                guard let location = viewModel.userLocation else { return }
                                Task {
                                    await viewModel.loadGrokRecommendations(
                                        location: location,
                                        category: viewModel.selectedCategory
                                    )
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .padding(.top, 8)
                        }
                    }
                }
            } else {
                LocationPromptCard {
                    viewModel.requestLocationPermission()
                }
            }
        }
    }
    
    private var quickIdeasSection: some View {
        RecommendationsSectionView(
            title: "Quick Ideas",
            subtitle: "General recommendations to explore",
            icon: "lightbulb.fill",
            accentColor: .orange,
            state: viewModel.simpleRecs,
            onRetry: {
                Task {
                    await viewModel.loadSimpleRecommendations()
                }
            }
        ) { recommendations in
            LazyVStack(spacing: 12) {
                ForEach(recommendations, id: \.title) { rec in
                    SimpleRecommendationCard(
                        recommendation: rec,
                        onTap: {
                            selectedRecommendation = .simple(rec)
                            trackInteraction(.view, for: rec.id ?? rec.title, category: viewModel.selectedCategory)
                        },
                        onFavorite: {
                            viewModel.toggleFavorite(for: rec.id ?? rec.title)
                            trackInteraction(.favorite, for: rec.id ?? rec.title, category: viewModel.selectedCategory)
                        },
                        onDismiss: {
                            viewModel.dismissRecommendation(id: rec.id ?? rec.title)
                            trackInteraction(.dismiss, for: rec.id ?? rec.title, category: viewModel.selectedCategory)
                        }
                    )
                }
            }
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Your Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            let stats = viewModel.recommendationStats
            HStack(spacing: 20) {
                StatCard(
                    icon: "star.fill",
                    title: "Total",
                    value: "\(stats.totalRecommendations)",
                    color: .blue
                )
                
                StatCard(
                    icon: "heart.fill",
                    title: "Favorites",
                    value: "\(stats.favoriteCount)",
                    color: .red
                )
                
                StatCard(
                    icon: "eye.slash.fill",
                    title: "Hidden",
                    value: "\(stats.dismissedCount)",
                    color: .gray
                )
            }
            
            Text("Last updated: \(stats.lastUpdated, style: .relative) ago")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func trackInteraction(_ type: RecommendationInteraction.InteractionType, for id: String, category: String) {
        let interaction = RecommendationInteraction(
            recommendationId: id,
            type: type,
            category: category,
            timestamp: Date()
        )
        viewModel.trackRecommendationInteraction(interaction)
    }
}

// MARK: - Supporting Views


// MARK: - Recommendation Item Enum

enum RecommendationItem: Identifiable {
    case aiPowered(AIPoweredActivity)
    case grok(GrokActivityRecommendation)
    case simple(SimpleRecommendation)
    
    var id: String {
        switch self {
        case .aiPowered(let activity):
            return "ai_\(activity.id)"
        case .grok(let rec):
            return "grok_\(rec.name.hash)" // GrokActivityRecommendation doesn't have id, use name hash
        case .simple(let rec):
            return "simple_\(rec.id ?? rec.title)"
        }
    }
}

#Preview {
    RecommendationsView()
}