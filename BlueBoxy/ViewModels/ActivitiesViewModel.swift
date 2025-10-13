import Foundation
import SwiftUI
import Combine

@MainActor
final class ActivitiesViewModel: ObservableObject {
    @Published var activities: Loadable<[Activity]> = .idle
    @Published var filteredActivities: [Activity] = []
    @Published var selectedCategory: String = "all"
    @Published var searchText: String = ""
    @Published var bookmarkedActivities: Set<Int> = []
    @Published var sortOption: SortOption = .recommended
    @Published var priceRange: PriceRange = .all
    @Published var locationFilter: LocationFilter = .all
    @Published var ratingFilter: Double = 0.0
    @Published var showingFilters = false
    
    private let apiClient: APIClient
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Filter and sort options
    enum SortOption: String, CaseIterable {
        case recommended = "recommended"
        case rating = "rating"
        case distance = "distance"
        case name = "name"
        case newest = "newest"
        
        var displayName: String {
            switch self {
            case .recommended: return "Recommended"
            case .rating: return "Highest Rated"
            case .distance: return "Distance"
            case .name: return "Name A-Z"
            case .newest: return "Newest"
            }
        }
        
        var icon: String {
            switch self {
            case .recommended: return "heart.fill"
            case .rating: return "star.fill"
            case .distance: return "location.fill"
            case .name: return "textformat"
            case .newest: return "clock.fill"
            }
        }
    }
    
    enum PriceRange: String, CaseIterable {
        case all = "all"
        case free = "free"
        case budget = "budget" // $0-25
        case moderate = "moderate" // $25-75
        case premium = "premium" // $75+
        
        var displayName: String {
            switch self {
            case .all: return "All Prices"
            case .free: return "Free"
            case .budget: return "Budget ($0-25)"
            case .moderate: return "Moderate ($25-75)"
            case .premium: return "Premium ($75+)"
            }
        }
    }
    
    enum LocationFilter: String, CaseIterable {
        case all = "all"
        case nearby = "nearby" // < 5 miles
        case city = "city" // < 15 miles
        case region = "region" // < 50 miles
        
        var displayName: String {
            switch self {
            case .all: return "All Locations"
            case .nearby: return "Nearby (< 5 mi)"
            case .city: return "In City (< 15 mi)"
            case .region: return "Region (< 50 mi)"
            }
        }
    }
    
    var categories: [String] {
        guard case .loaded(let activities) = activities else { return ["all"] }
        let unique = Set(activities.map(\.category))
        return ["all"] + Array(unique).sorted()
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedCategory != "all" { count += 1 }
        if !searchText.isEmpty { count += 1 }
        if sortOption != .recommended { count += 1 }
        if priceRange != .all { count += 1 }
        if locationFilter != .all { count += 1 }
        if ratingFilter > 0.0 { count += 1 }
        return count
    }
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
        loadBookmarks()
        setupSearchDebouncing()
    }
    
    func loadActivities(forceRefresh: Bool = false) async {
        if !forceRefresh, case .loaded = activities {
            return // Already loaded
        }
        
        activities = .loading
        
        // Try cache first if not forcing refresh
        if !forceRefresh {
            if let cachedActivities = await cacheManager.load(
                for: CacheKey.activitiesList,
                type: [Activity].self
            ) {
                activities = .loaded(cachedActivities)
                applyFilters()
                
                // Load fresh data in background
                Task {
                    await loadActivitiesFromNetwork()
                }
                return
            }
        }
        
        await loadActivitiesFromNetwork()
    }
    
    private func loadActivitiesFromNetwork() async {
        do {
            let activitiesResponse: ActivitiesResponse = try await apiClient.request(Endpoint.activitiesList())
            let enrichedActivities = await enrichActivitiesWithPersonalityMatch(activitiesResponse.activities)
            
            activities = .loaded(enrichedActivities)
            
            // Cache the results
            await cacheManager.save(
                enrichedActivities,
                for: CacheKey.activitiesList,
                strategy: .hybrid(expiration: 3600) // 1 hour
            )
            
            applyFilters()
            
        } catch {
            // Try cache as fallback
            if let cachedActivities = await cacheManager.load(
                for: CacheKey.activitiesList,
                type: [Activity].self
            ) {
                activities = .loaded(cachedActivities)
                applyFilters()
            } else {
                activities = .failed(ErrorMapper.map(error))
            }
        }
    }
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    func applyFilters() {
        guard case .loaded(let allActivities) = activities else { return }
        
        var filtered = allActivities
        
        // Category filter
        if selectedCategory != "all" {
            filtered = filtered.filter { $0.category.lowercased() == selectedCategory.lowercased() }
        }
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { activity in
                activity.name.localizedCaseInsensitiveContains(searchText) ||
                activity.description.localizedCaseInsensitiveContains(searchText) ||
                activity.category.localizedCaseInsensitiveContains(searchText) ||
                (activity.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
            }
        }
        
        // Price filter
        if priceRange != .all {
            filtered = filtered.filter { activity in
                guard let price = activity.estimatedPrice else { return priceRange == .free }
                
                switch priceRange {
                case .all: return true
                case .free: return price == 0
                case .budget: return price > 0 && price <= 25
                case .moderate: return price > 25 && price <= 75
                case .premium: return price > 75
                }
            }
        }
        
        // Location/Distance filter
        if locationFilter != .all {
            filtered = filtered.filter { activity in
                guard let distance = parseDistance(activity.distance) else { return true }
                
                switch locationFilter {
                case .all: return true
                case .nearby: return distance <= 5.0
                case .city: return distance <= 15.0
                case .region: return distance <= 50.0
                }
            }
        }
        
        // Rating filter
        if ratingFilter > 0.0 {
            filtered = filtered.filter { activity in
                (activity.rating ?? 0.0) >= ratingFilter
            }
        }
        
        // Apply sorting
        filtered = sortActivities(filtered)
        
        filteredActivities = filtered
    }
    
    private func parseDistance(_ distanceString: String?) -> Double? {
        guard let distanceString = distanceString else { return nil }
        
        // Parse distance string like "2.3 mi" or "1.5 miles"
        let components = distanceString.components(separatedBy: .whitespaces)
        guard let distanceValue = components.first,
              let distance = Double(distanceValue) else { return nil }
        
        return distance
    }
    
    private func sortActivities(_ activities: [Activity]) -> [Activity] {
        switch sortOption {
        case .recommended:
            return activities.sorted { (a, b) in
                // Sort by personality match score, then rating
                let aMatch = a.personalityMatchScore ?? 0
                let bMatch = b.personalityMatchScore ?? 0
                if aMatch != bMatch {
                    return aMatch > bMatch
                }
                return (a.rating ?? 0) > (b.rating ?? 0)
            }
        case .rating:
            return activities.sorted { (a, b) in
                (a.rating ?? 0) > (b.rating ?? 0)
            }
        case .distance:
            return activities.sorted { (a, b) in
                let aDistance = parseDistance(a.distance) ?? Double.infinity
                let bDistance = parseDistance(b.distance) ?? Double.infinity
                return aDistance < bDistance
            }
        case .name:
            return activities.sorted { $0.name < $1.name }
        case .newest:
            return activities.sorted { (a, b) in
                (a.createdAt ?? Date.distantPast) > (b.createdAt ?? Date.distantPast)
            }
        }
    }
    
    private func enrichActivitiesWithPersonalityMatch(_ activities: [Activity]) async -> [Activity] {
        // Load user's personality insight for matching
        guard let personalityInsight = await cacheManager.load(
            for: CacheKey.personalityInsight,
            type: PersonalityInsight.self
        ) else {
            return activities
        }
        
        return activities.map { activity in
            var enrichedActivity = activity
            let matchInfo = calculatePersonalityMatch(activity: activity, insight: personalityInsight)
            enrichedActivity.personalityMatch = matchInfo.explanation
            enrichedActivity.personalityMatchScore = matchInfo.score
            return enrichedActivity
        }
    }
    
    private func calculatePersonalityMatch(activity: Activity, insight: PersonalityInsight) -> (score: Double, explanation: String) {
        var score: Double = 0.5 // Base score
        var reasons: [String] = []
        
        // Match against love language
        let loveLanguage = insight.loveLanguage.lowercased()
        if loveLanguage.contains("quality time") && (activity.category == "dining" || activity.category == "cultural") {
            score += 0.2
            reasons.append("Great for quality time together")
        } else if loveLanguage.contains("acts of service") && activity.category == "practical" {
            score += 0.2
            reasons.append("Shows care through helpful activities")
        } else if loveLanguage.contains("physical touch") && (activity.category == "active" || activity.category == "outdoor") {
            score += 0.15
            reasons.append("Opportunities for physical closeness")
        }
        
        // Match against communication style
        let commStyle = insight.communicationStyle.lowercased()
        if commStyle.contains("thoughtful") && (activity.category == "cultural" || activity.category == "relaxed") {
            score += 0.15
            reasons.append("Perfect for meaningful conversations")
        } else if commStyle.contains("direct") && activity.category == "active" {
            score += 0.15
            reasons.append("Straightforward and engaging")
        }
        
        // Match against ideal activities
        for idealActivity in insight.idealActivities {
            if activity.name.localizedCaseInsensitiveContains(idealActivity) ||
               activity.description.localizedCaseInsensitiveContains(idealActivity) {
                score += 0.1
                reasons.append("Matches your preferences")
                break
            }
        }
        
        // Ensure score is within bounds
        score = min(max(score, 0.0), 1.0)
        
        let explanation = reasons.isEmpty ? 
            "This activity suits your personality style" : 
            reasons.joined(separator: ". ") + "."
        
        return (score, explanation)
    }
    
    func toggleBookmark(for activityId: Int) {
        if bookmarkedActivities.contains(activityId) {
            bookmarkedActivities.remove(activityId)
        } else {
            bookmarkedActivities.insert(activityId)
        }
        saveBookmarks()
    }
    
    func clearAllFilters() {
        selectedCategory = "all"
        searchText = ""
        sortOption = .recommended
        priceRange = .all
        locationFilter = .all
        ratingFilter = 0.0
        applyFilters()
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: "bookmarked_activities"),
           let bookmarks = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            bookmarkedActivities = bookmarks
        }
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarkedActivities) {
            UserDefaults.standard.set(data, forKey: "bookmarked_activities")
        }
    }
    
    // Quick filter presets
    func applyQuickFilter(_ filter: QuickFilter) {
        clearAllFilters()
        
        switch filter {
        case .nearbyAndFree:
            locationFilter = .nearby
            priceRange = .free
        case .highRated:
            ratingFilter = 4.0
            sortOption = .rating
        case .romantic:
            selectedCategory = "romantic"
            sortOption = .recommended
        case .active:
            selectedCategory = "active"
            sortOption = .distance
        case .cultural:
            selectedCategory = "cultural"
            sortOption = .rating
        case .budget:
            priceRange = .budget
            sortOption = .rating
        }
        
        applyFilters()
    }
}

enum QuickFilter: String, CaseIterable {
    case nearbyAndFree = "nearby_free"
    case highRated = "high_rated"
    case romantic = "romantic"
    case active = "active"
    case cultural = "cultural"
    case budget = "budget"
    
    var displayName: String {
        switch self {
        case .nearbyAndFree: return "Nearby & Free"
        case .highRated: return "Top Rated"
        case .romantic: return "Romantic"
        case .active: return "Active"
        case .cultural: return "Cultural"
        case .budget: return "Budget-Friendly"
        }
    }
    
    var icon: String {
        switch self {
        case .nearbyAndFree: return "location.circle.fill"
        case .highRated: return "star.circle.fill"
        case .romantic: return "heart.circle.fill"
        case .active: return "figure.run.circle.fill"
        case .cultural: return "building.columns.circle.fill"
        case .budget: return "dollarsign.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .nearbyAndFree: return .green
        case .highRated: return .yellow
        case .romantic: return .red
        case .active: return .blue
        case .cultural: return .purple
        case .budget: return .orange
        }
    }
}

// MARK: - Enhanced Activity Model

extension Activity {
    var personalityMatchScore: Double? {
        get { return nil } // Would be stored in the actual model
        set { } // Would be stored in the actual model
    }
    
    var estimatedPrice: Double? {
        // Parse price from description or use a dedicated field
        return nil // Would be implemented based on actual data structure
    }
    
    var createdAt: Date? {
        return nil // Would be part of the actual model
    }
    
    var tags: [String]? {
        return nil // Would be part of the actual model
    }
}

// MARK: - API Extensions
// Note: activitiesList() is defined in Endpoints.swift

struct ActivitiesResponse: Codable {
    let activities: [Activity]
    let totalCount: Int
    let page: Int?
    let hasMore: Bool?
}

// MARK: - Cache Extensions

extension CacheKey {
    static let activitiesList = "activities_list"
}