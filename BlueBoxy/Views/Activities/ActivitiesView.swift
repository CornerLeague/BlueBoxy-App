import SwiftUI

struct ActivitiesView: View {
    @StateObject private var viewModel = ActivitiesViewModel()
    @State private var showingBookmarkedActivities = false
    @State private var selectedActivity: Activity?
    @State private var showingFilters = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with search and filters
                    headerSection
                    
                    // Quick filters
                    quickFiltersSection
                    
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
                await viewModel.loadActivities()
            }
            .refreshable {
                await viewModel.loadActivities(forceRefresh: true)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            SearchBar(
                text: $searchText,
                placeholder: "Search activities, categories, or tags..."
            )
            .onChange(of: searchText) { newValue in
                viewModel.searchText = newValue
            }
            
            // Categories scroll view
            if !viewModel.categories.isEmpty {
                CategoryScrollView(
                    categories: viewModel.categories,
                    selectedCategory: $viewModel.selectedCategory
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private var quickFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(QuickFilter.allCases, id: \.rawValue) { filter in
                    QuickFilterButton(
                        filter: filter,
                        isSelected: isQuickFilterSelected(filter)
                    ) {
                        viewModel.applyQuickFilter(filter)
                    }
                }
                
                // Clear filters button
                if viewModel.activeFiltersCount > 0 {
                    Button(action: viewModel.clearAllFilters) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.white)
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
                        icon: "magnifyingglass",
                        title: "No Activities Found",
                        subtitle: searchText.isEmpty ? 
                            "Try adjusting your filters to see more activities." :
                            "No activities match your search '\(searchText)'.",
                        primaryButton: EmptyStateView.Button(
                            title: "Clear Filters",
                            action: viewModel.clearAllFilters
                        )
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
                    retryAction: {
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
                ForEach(ActivitiesViewModel.SortOption.allCases, id: \.rawValue) { option in
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
    
    private func isQuickFilterSelected(_ filter: QuickFilter) -> Bool {
        switch filter {
        case .nearbyAndFree:
            return viewModel.locationFilter == .nearby && viewModel.priceRange == .free
        case .highRated:
            return viewModel.ratingFilter >= 4.0 && viewModel.sortOption == .rating
        case .romantic:
            return viewModel.selectedCategory == "romantic"
        case .active:
            return viewModel.selectedCategory == "active"
        case .cultural:
            return viewModel.selectedCategory == "cultural"
        case .budget:
            return viewModel.priceRange == .budget
        }
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let filter: QuickFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? filter.color.opacity(0.2) : Color.gray.opacity(0.1)
            )
            .foregroundColor(
                isSelected ? filter.color : .primary
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? filter.color : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Category Scroll View

struct CategoryScrollView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}


// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var viewModel: ActivitiesViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Sort Section
                    FilterSection(title: "Sort By", icon: "arrow.up.arrow.down") {
                        VStack(spacing: 8) {
                            ForEach(ActivitiesViewModel.SortOption.allCases, id: \.rawValue) { option in
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
                    
                    // Price Range Section
                    FilterSection(title: "Price Range", icon: "dollarsign.circle") {
                        VStack(spacing: 8) {
                            ForEach(ActivitiesViewModel.PriceRange.allCases, id: \.rawValue) { range in
                                FilterOptionRow(
                                    title: range.displayName,
                                    isSelected: viewModel.priceRange == range
                                ) {
                                    viewModel.priceRange = range
                                }
                            }
                        }
                    }
                    
                    // Location Filter Section
                    FilterSection(title: "Distance", icon: "location.circle") {
                        VStack(spacing: 8) {
                            ForEach(ActivitiesViewModel.LocationFilter.allCases, id: \.rawValue) { location in
                                FilterOptionRow(
                                    title: location.displayName,
                                    isSelected: viewModel.locationFilter == location
                                ) {
                                    viewModel.locationFilter = location
                                }
                            }
                        }
                    }
                    
                    // Rating Filter Section
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