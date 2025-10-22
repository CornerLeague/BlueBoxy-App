import SwiftUI

struct ActivitiesView: View {
    @StateObject private var viewModel = EnhancedActivitiesViewModel()
    @StateObject private var locationService = LocationService()
    @State private var showingBookmarkedActivities = false
    @State private var selectedActivity: Activity?
    @State private var showingFilters = false
    @State private var showingPreferences = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Location header
                    LocationHeaderView(
                        locationService: locationService,
                        showingPreferences: $showingPreferences
                    )
                    .padding(.top, 8)
                    
                    // Header with search and filters
                    headerSection
                    
                    // Generate Button
                    generateButton
                    
                    // Content
                    contentSection
                }
            }
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Bookmarks button
                        Button(action: { showingBookmarkedActivities.toggle() }) {
                            Image(systemName: viewModel.bookmarkedActivities.isEmpty ? "bookmark" : "bookmark.fill")
                                .foregroundColor(.primary)
                                .font(.title3)
                        }
                        .disabled(viewModel.bookmarkedActivities.isEmpty)
                        
                        // Filter button with badge
                        ZStack {
                            Button(action: { showingFilters.toggle() }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                            }
                            
                            if viewModel.activeFiltersCount > 0 {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Text("\(viewModel.activeFiltersCount)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingBookmarkedActivities) {
                BookmarkedActivitiesView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(viewModel: viewModel)
            }
            .sheet(item: $selectedActivity) { activity in
                ActivityDetailView(activity: activity, viewModel: viewModel)
            }
            .task {
                // Update viewModel with initial location
                if let location = locationService.currentLocation {
                    viewModel.currentLocation = location
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Search activities, categories, or tags...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) {
                        viewModel.searchText = searchText
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Categories scroll view
            CategoryTabBar(selectedCategory: $viewModel.selectedCategory)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private var generateButton: some View {
        VStack(spacing: 12) {
            if case .idle = viewModel.activities {
                // Initial state - show generate button
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Generate AI Activities")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Get personalized activity recommendations powered by AI based on your personality and preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: {
                        Task {
                            await viewModel.generateActivities()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.title3)
                            Text("Generate Activities")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(1.0)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
            } else if case .loaded = viewModel.activities {
                // Show regenerate button when activities are loaded
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.generateActivities()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                            Text("Regenerate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .disabled({
                        if case .loading = viewModel.activities { return true }
                        return false
                    }())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Results header
            if case .loaded = viewModel.activities {
                resultsHeaderSection
            }
            
            // Main content
            switch viewModel.activities {
            case .idle:
                EmptyView()
                
            case .loading:
                LoadingView(message: "Finding amazing activities...")
                
            case .loaded:
                if viewModel.filteredActivities.isEmpty {
                    EmptyStateView(
                        title: "No Activities Found",
                        subtitle: searchText.isEmpty ? 
                            "Try adjusting your filters to see more activities." :
                            "No activities match your search '\(searchText)'.",
                        systemImage: "magnifyingglass",
                        actionTitle: "Clear Filters",
                        action: viewModel.clearAllFilters
                    )
                } else {
                    ActivitiesListView(
                        activities: viewModel.filteredActivities,
                        bookmarkedActivities: viewModel.bookmarkedActivities,
                        onBookmarkToggle: viewModel.toggleBookmark,
                        onActivitySelect: { selectedActivity = $0 }
                    )
                }
                
            case .failed(let error):
                ErrorView(
                    error: error,
                    onRetry: {
                        Task {
                            await viewModel.loadActivities(forceRefresh: true)
                        }
                    }
                )
            }
        }
    }
    
    private var resultsHeaderSection: some View {
        HStack {
            // Results count
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.filteredActivities.count) Activities")
                    .font(.headline)
                    .fontWeight(.medium)
                
                if viewModel.activeFiltersCount > 0 {
                    Text("Filtered results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Sort menu
            Menu {
                ForEach(EnhancedActivitiesViewModel.SortOption.allCases, id: \.rawValue) { option in
                    Button(action: {
                        viewModel.sortOption = option
                    }) {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortOption.icon)
                        .font(.caption)
                    Text("Sort")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
    
}

// MARK: - Activities List View

struct ActivitiesListView: View {
    let activities: [Activity]
    let bookmarkedActivities: Set<Int>
    let onBookmarkToggle: (Int) -> Void
    let onActivitySelect: (Activity) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(activities, id: \.id) { activity in
                    ActivityListCard(
                        activity: activity,
                        isBookmarked: bookmarkedActivities.contains(activity.id),
                        onBookmarkToggle: { onBookmarkToggle(activity.id) },
                        onTap: { onActivitySelect(activity) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Activity List Card

struct ActivityListCard: View {
    let activity: Activity
    let isBookmarked: Bool
    let onBookmarkToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with bookmark button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(activity.category.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Button(action: onBookmarkToggle) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked ? .blue : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Description
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Footer with rating and distance
                HStack {
                    if let rating = activity.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let distance = activity.distance {
                        HStack(spacing: 2) {
                            Image(systemName: "location")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text(distance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Personality match indicator
                    if let matchScore = activity.personalityMatchScore, matchScore > 0.7 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Great Match")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bookmarked Activities View

struct BookmarkedActivitiesView: View {
    @ObservedObject var viewModel: EnhancedActivitiesViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedActivity: Activity?
    
    private var bookmarkedActivitiesList: [Activity] {
        guard case .loaded(let allActivities) = viewModel.activities else { return [] }
        return allActivities.filter { viewModel.bookmarkedActivities.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                if bookmarkedActivitiesList.isEmpty {
                    EmptyStateView(
                        title: "No Bookmarked Activities",
                        subtitle: "Activities you bookmark will appear here for quick access.",
                        systemImage: "bookmark",
                        actionTitle: "Explore Activities",
                        action: {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(bookmarkedActivitiesList.count) Bookmarked Activities")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Your saved activities for easy access")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Activities list
                            LazyVStack(spacing: 16) {
                                ForEach(bookmarkedActivitiesList, id: \.id) { activity in
                                    ActivityListCard(
                                        activity: activity,
                                        isBookmarked: true,
                                        onBookmarkToggle: {
                                            viewModel.toggleBookmark(for: activity.id)
                                        },
                                        onTap: {
                                            selectedActivity = activity
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                if !bookmarkedActivitiesList.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Clear All Bookmarks", role: .destructive) {
                                // Clear all bookmarks
                                for activity in bookmarkedActivitiesList {
                                    viewModel.toggleBookmark(for: activity.id)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedActivity) { activity in
                ActivityDetailView(activity: activity, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var viewModel: EnhancedActivitiesViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    sortSection
                    priceRangeSection
                    locationFilterSection
                    ratingFilterSection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearAllFilters()
                    }
                    .foregroundColor(.red)
                    .disabled(viewModel.activeFiltersCount == 0)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var sortSection: some View {
        FilterSection(title: "Sort By", icon: "arrow.up.arrow.down") {
            VStack(spacing: 8) {
                ForEach(EnhancedActivitiesViewModel.SortOption.allCases, id: \.rawValue) { option in
                    FilterOptionRow(
                        title: option.displayName,
                        icon: option.icon,
                        isSelected: viewModel.sortOption == option
                    ) {
                        viewModel.sortOption = option
                    }
                }
            }
        }
    }
    
    private var priceRangeSection: some View {
        FilterSection(title: "Price Range", icon: "dollarsign.circle") {
            VStack(spacing: 8) {
                ForEach(ActivityPriceRange.allCases, id: \.rawValue) { range in
                    FilterOptionRow(
                        title: range.displayName,
                        isSelected: viewModel.priceRange == range
                    ) {
                        viewModel.priceRange = range
                    }
                }
            }
        }
    }
    
    private var locationFilterSection: some View {
        FilterSection(title: "Distance", icon: "location.circle") {
            VStack(spacing: 8) {
                ForEach(EnhancedActivitiesViewModel.LocationFilter.allCases, id: \.rawValue) { location in
                    FilterOptionRow(
                        title: location.displayName,
                        isSelected: viewModel.locationFilter == location
                    ) {
                        viewModel.locationFilter = location
                    }
                }
            }
        }
    }
    
    private var ratingFilterSection: some View {
        FilterSection(title: "Minimum Rating", icon: "star.circle") {
            VStack(spacing: 12) {
                HStack {
                    Text("Rating: \(viewModel.ratingFilter, specifier: "%.1f")+")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if viewModel.ratingFilter > 0 {
                        Button("Clear") {
                            viewModel.ratingFilter = 0.0
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Slider(
                    value: $viewModel.ratingFilter,
                    in: 0...5,
                    step: 0.5
                ) {
                    Text("Rating")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Filter Components

struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct FilterOptionRow: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .frame(width: 20)
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                isSelected ? Color.blue.opacity(0.1) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    ActivitiesView()
}