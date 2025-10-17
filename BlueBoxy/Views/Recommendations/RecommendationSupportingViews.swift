import SwiftUI

// MARK: - Category Selector View

struct CategorySelectorView: View {
    let categories: [(String, String, String, String)] // id, name, emoji, icon
    @Binding var selectedCategory: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.0) { category in
                    CategoryChip(
                        id: category.0,
                        name: category.1,
                        emoji: category.2,
                        icon: category.3,
                        isSelected: selectedCategory == category.0
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category.0
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
}

struct CategoryChip: View {
    let id: String
    let name: String
    let emoji: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text(emoji)
                        .font(.subheadline)
                }
                
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ?
                    Color.blue :
                    Color.gray.opacity(0.1)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(
                color: isSelected ? .blue.opacity(0.3) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Recommendations Section View

struct RecommendationsSectionView<Content: View, T>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let state: Loadable<T>
    let onRetry: () -> Void
    @ViewBuilder let content: (T) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            sectionHeader
            
            // Content based on state
            switch state {
            case .idle:
                EmptyView()
                
            case .loading:
                loadingContent
                
            case .loaded(let data):
                content(data)
                
            case .failed(let error):
                errorContent(error)
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
            }
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var loadingContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RecommendationLoadingCard()
            }
        }
    }
    
    private func errorContent(_ error: NetworkError) -> some View {
        RecommendationEmptyCard(
            title: "Something went wrong",
            subtitle: error.userFriendlyMessage,
            icon: "exclamationmark.triangle",
            action: onRetry
        )
    }
}

// MARK: - Location Prompt Card

struct LocationPromptCard: View {
    let onRequestLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and animation
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.green.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: Date().timeIntervalSince1970
                    )
                
                Image(systemName: "location")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            // Content
            VStack(spacing: 12) {
                Text("Discover Places Near You")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Enable location access to get personalized recommendations for amazing places in your area")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Action button
            Button("Enable Location") {
                onRequestLocation()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .padding(24)
        .background(Material.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Recommendation Filters View

struct RecommendationFiltersView: View {
    @ObservedObject var viewModel: RecommendationsViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var localFilters: RecommendationsViewModel.RecommendationFilters
    
    init(viewModel: RecommendationsViewModel) {
        self.viewModel = viewModel
        self._localFilters = State(initialValue: viewModel.filterOptions)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    distanceFilterSection
                    priceRangeFilterSection
                    timeOfDayFilterSection
                    groupSizeFilterSection
                    additionalOptionsSection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        localFilters = RecommendationsViewModel.RecommendationFilters()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        viewModel.applyFilters(localFilters)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var distanceFilterSection: some View {
        filterSection("Distance", icon: "location.circle") {
            VStack(spacing: 16) {
                HStack {
                    Text("Maximum Distance")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(localFilters.maxDistance)) miles")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Slider(
                    value: $localFilters.maxDistance,
                    in: 1...50,
                    step: 1
                ) {
                    Text("Distance")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.blue)
            }
        }
    }
    
    private var priceRangeFilterSection: some View {
        filterSection("Price Range", icon: "dollarsign.circle") {
            VStack(spacing: 8) {
                ForEach(RecommendationsViewModel.RecommendationFilters.PriceRange.allCases, id: \.rawValue) { range in
                    FilterOptionRow(
                        title: range.displayName,
                        isSelected: localFilters.priceRange == range
                    ) {
                        localFilters.priceRange = range
                    }
                }
            }
        }
    }
    
    private var timeOfDayFilterSection: some View {
        filterSection("Time of Day", icon: "clock") {
            VStack(spacing: 8) {
                ForEach(RecommendationsViewModel.RecommendationFilters.FilterTimeOfDay.allCases, id: \.rawValue) { time in
                    FilterOptionRow(
                        title: time.displayName,
                        isSelected: localFilters.timeOfDay == time
                    ) {
                        localFilters.timeOfDay = time
                    }
                }
            }
        }
    }
    
    private var groupSizeFilterSection: some View {
        filterSection("Group Size", icon: "person.2") {
            VStack(spacing: 8) {
                ForEach(RecommendationsViewModel.RecommendationFilters.GroupSize.allCases, id: \.rawValue) { size in
                    FilterOptionRow(
                        title: size.displayName,
                        isSelected: localFilters.groupSize == size
                    ) {
                        localFilters.groupSize = size
                    }
                }
            }
        }
    }
    
    private var additionalOptionsSection: some View {
        filterSection("Options", icon: "gear") {
            Toggle("Include Bookmarked Activities", isOn: $localFilters.includeBookmarked)
                .font(.subheadline)
        }
    }
    
    private func filterSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Material.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


// MARK: - Recommendation Stats View

struct RecommendationStatsView: View {
    @ObservedObject var viewModel: RecommendationsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Cards
                    overviewSection
                    
                    // Category Breakdown
                    categoryBreakdownSection
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Your Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var overviewSection: some View {
        let stats = viewModel.recommendationStats
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(
                    icon: "eye.fill",
                    title: "Total Seen",
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
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Category")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.availableCategories, id: \.0) { category in
                    CategoryStatsCard(
                        name: category.1,
                        emoji: category.2,
                        count: getCategoryCount(category.0),
                        isSelected: viewModel.selectedCategory == category.0
                    )
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ActivityRow(
                    icon: "heart.fill",
                    color: .red,
                    title: "Favorited recommendation",
                    subtitle: "2 hours ago"
                )
                
                ActivityRow(
                    icon: "eye.slash.fill",
                    color: .gray,
                    title: "Dismissed recommendation",
                    subtitle: "5 hours ago"
                )
                
                ActivityRow(
                    icon: "arrow.clockwise",
                    color: .blue,
                    title: "Refreshed recommendations",
                    subtitle: "1 day ago"
                )
            }
        }
    }
    
    private func getCategoryCount(_ categoryId: String) -> Int {
        // This would calculate actual counts based on loaded data
        return Int.random(in: 1...10) // Placeholder
    }
}

struct CategoryStatsCard: View {
    let name: String
    let emoji: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.title2)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding()
        .background(
            isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct ActivityRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}



#Preview("Category Selector") {
    CategorySelectorView(
        categories: [
            ("recommended", "Recommended", "⭐", "sparkles"),
            ("dining", "Dining", "🍽️", "fork.knife"),
            ("outdoor", "Outdoor", "🌳", "leaf.fill"),
            ("cultural", "Cultural", "🎭", "building.columns")
        ],
        selectedCategory: .constant("recommended")
    )
}

#Preview("Location Prompt") {
    LocationPromptCard {
        print("Location requested")
    }
    .padding()
}