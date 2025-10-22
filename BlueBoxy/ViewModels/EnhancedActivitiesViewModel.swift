//
//  EnhancedActivitiesViewModel.swift
//  BlueBoxy
//
//  Enhanced Activities view model with OpenAI integration and preference-based recommendations
//

import Foundation
import SwiftUI
import Combine
import CoreLocation


@MainActor
class EnhancedActivitiesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activities: Loadable<[Activity]> = .idle
    @Published var personalizedRecommendations: Loadable<[Activity]> = .idle
    @Published var filteredActivities: [Activity] = []
    @Published var bookmarkedActivities: Set<Int> = Set()
    
    // MARK: - Search & Filter State
    
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    
    @Published var selectedCategory: ActivityCategory = .recommended {
        didSet { applyFilters() }
    }
    
    @Published var selectedDrinkCategory: DrinkCategory = .coffee {
        didSet { applyFilters() }
    }
    
    @Published var searchRadius: Double = 25.0 {
        didSet { applyFilters() }
    }
    
    @Published var sortOption: SortOption = .recommended {
        didSet { applyFilters() }
    }
    
    @Published var priceRange: ActivityPriceRange = .all {
        didSet { applyFilters() }
    }
    
    @Published var locationFilter: LocationFilter = .all {
        didSet { applyFilters() }
    }
    
    @Published var ratingFilter: Double = 0.0 {
        didSet { applyFilters() }
    }
    
    
    // MARK: - AI State
    
    @Published var aiInsights: String?
    @Published var personalityInsights: String?
    @Published var relationshipTips: [String] = []
    @Published var isLoadingAIRecommendations: Bool = false
    @Published var lastAIUpdate: Date?
    
    // MARK: - Location State
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var userLocation: UserLocation?
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let openAIService: OpenAIActivityService
    private let sessionStore: SessionStore
    private let locationManager: CLLocationManager
    private let cacheManager = CacheManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    /// Fallback mode - set to true to disable backend API calls until your backend is ready
    private let useFallbackMode = false // OpenAI service is now implemented
    
    enum SortOption: String, CaseIterable {
        case recommended = "recommended"
        case rating = "rating"
        case distance = "distance"
        case name = "name"
        case newest = "newest"
        case price = "price"
        
        var displayName: String {
            switch self {
            case .recommended: return "Recommended"
            case .rating: return "Highest Rated"
            case .distance: return "Nearest"
            case .name: return "A-Z"
            case .newest: return "Latest"
            case .price: return "Price"
            }
        }
        
        var icon: String {
            switch self {
            case .recommended: return "heart.fill"
            case .rating: return "star.fill"
            case .distance: return "location.fill"
            case .name: return "textformat.abc"
            case .newest: return "clock.fill"
            case .price: return "dollarsign.circle.fill"
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
        
        var radiusMiles: Double? {
            switch self {
            case .all: return nil
            case .nearby: return 5.0
            case .city: return 15.0
            case .region: return 50.0
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedCategory != .recommended { count += 1 }
        if !searchText.isEmpty { count += 1 }
        if sortOption != .recommended { count += 1 }
        if priceRange != .all { count += 1 }
        if locationFilter != .all { count += 1 }
        if ratingFilter > 0.0 { count += 1 }
        return count
    }
    
    var currentUser: DomainUser? {
        return sessionStore.currentUser as? DomainUser
    }
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = APIClient.shared,
         openAIService: OpenAIActivityService = OpenAIActivityService.shared,
         sessionStore: SessionStore = SessionStore.shared) {
        
        self.apiClient = apiClient
        self.openAIService = openAIService
        self.sessionStore = sessionStore
        self.locationManager = CLLocationManager()
        
        loadBookmarks()
        setupSearchDebouncing()
        setupLocationMonitoring()
        
        // Note: Activities are now loaded manually via generateActivities() button
    }
    
    // MARK: - Public Methods
    
    /// Generate new activities using OpenAI with geolocation (called by Generate Activities button)
    func generateActivities() async {
        print("🤖 Generating activities with OpenAI using geolocation...")
        activities = .loading()
        await loadActivitiesFromOpenAI()
    }
    
    /// Load basic activities list (fallback/cached data)
    func loadActivities(forceRefresh: Bool = false) async {
        if !forceRefresh, case .loaded = activities {
            return // Already loaded
        }
        
        activities = .loading()
        
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
    
    /// Load personalized recommendations using OpenAI
    func loadPersonalizedRecommendations(forceRefresh: Bool = false) async {
        guard sessionStore.isAuthenticated, let user = currentUser else {
            print("⚠️ Cannot load personalized recommendations: user not authenticated")
            return
        }
        
        if !forceRefresh, case .loaded = personalizedRecommendations {
            return
        }
        
        personalizedRecommendations = .loading()
        isLoadingAIRecommendations = true
        
        // Try backend API first
        do {
            let response: PersonalizedActivityResponse = try await apiClient.request(
                .activitiesPersonalized(location: currentLocation, preferences: user.personalityInsight?.idealActivities)
            )
            
            personalizedRecommendations = .loaded(response.recommendations)
            personalityInsights = response.personalityInsights
            relationshipTips = response.relationshipTips
            
            // Cache the recommendations
            await cacheManager.save(
                response.recommendations,
                for: "personalized_activities_\(user.id)",
                strategy: .hybrid(expiration: 3600) // 1 hour
            )
            
        } catch {
            // Fallback to direct OpenAI integration
            print("📡 API recommendations failed, trying OpenAI directly: \(error)")
            await loadOpenAIRecommendationsDirectly(user: user)
        }
        
        isLoadingAIRecommendations = false
        lastAIUpdate = Date()
    }
    
    /// Search activities with enhanced criteria
    func searchActivities(query: String? = nil, category: String? = nil, useAI: Bool = true) async {
        // In fallback mode, just filter current activities
        if useFallbackMode {
            await loadActivities() // Load mock data if needed
            return
        }
        
        let searchRequest = ActivitySearchRequest(
            query: query,
            category: category,
            location: currentLocation,
            radius: locationFilter.radiusMiles,
            priceRange: priceRange,
            personalityType: currentUser?.personalityType,
            relationshipDuration: currentUser?.relationshipDuration,
            userPreferences: currentUser?.personalityInsight?.idealActivities,
            timeOfDay: getCurrentTimeOfDay(),
            season: getCurrentSeason(),
            useAI: useAI && sessionStore.isAuthenticated
        )
        
        activities = .loading()
        
        do {
            let response: ActivitySearchResponse = try await apiClient.request(.activitiesSearch(searchRequest))
            activities = .loaded(response.activities)
            aiInsights = response.aiInsights
            applyFilters()
            
        } catch {
            print("❌ Search failed: \(error)")
            // Fallback to basic list if search fails
            await loadActivities(forceRefresh: false)
            activities = .failed(ErrorMapper.map(error))
        }
    }
    
    /// Refine recommendations based on user feedback
    func refineRecommendations(feedback: String, excludeCategories: [String] = []) async {
        guard !useFallbackMode, let user = currentUser, case .loaded(let current) = personalizedRecommendations else { return }
        
        let refinementRequest = ActivityRefinementRequest(
            originalCriteria: ActivitySearchCriteria(
                location: currentLocation.map { ActivityCoordinates(latitude: $0.latitude, longitude: $0.longitude) },
                cityName: userLocation?.city,
                radius: locationFilter.radiusMiles ?? 25.0,
                personalityType: user.personalityType,
                relationshipDuration: user.relationshipDuration,
                idealActivities: user.personalityInsight?.idealActivities ?? [],
                priceRange: priceRange.rawValue,
                category: selectedCategory != .recommended ? selectedCategory.rawValue : nil,
                timeOfDay: getCurrentTimeOfDay(),
                season: getCurrentSeason()
            ),
            userFeedback: feedback,
            previousRecommendations: current.map { $0.id },
            preferredCategories: nil,
            excludeCategories: excludeCategories.isEmpty ? nil : excludeCategories
        )
        
        do {
            let response: PersonalizedActivityResponse = try await apiClient.request(.activitiesRefine(refinementRequest))
            personalizedRecommendations = .loaded(response.recommendations)
            personalityInsights = response.personalityInsights
            relationshipTips = response.relationshipTips
        } catch {
            print("❌ Refinement failed: \(error)")
        }
    }
    
    /// Toggle bookmark status for an activity
    func toggleBookmark(for activityId: Int) {
        if bookmarkedActivities.contains(activityId) {
            bookmarkedActivities.remove(activityId)
            // Only call API if not in fallback mode
            if !useFallbackMode {
                Task {
                    do {
                        try await apiClient.requestEmpty(.activitiesUnsave(id: activityId))
                    } catch {
                        // Revert on error
                        bookmarkedActivities.insert(activityId)
                        print("❌ Failed to remove bookmark: \(error)")
                    }
                }
            }
        } else {
            bookmarkedActivities.insert(activityId)
            // Only call API if not in fallback mode
            if !useFallbackMode {
                Task {
                    do {
                        try await apiClient.requestEmpty(.activitiesSave(id: activityId))
                    } catch {
                        // Revert on error
                        bookmarkedActivities.remove(activityId)
                        print("❌ Failed to save bookmark: \(error)")
                    }
                }
            }
        }
        saveBookmarks()
        applyFilters()
    }
    /// Clear all filters
    func clearAllFilters() {
        selectedCategory = .recommended
        searchText = ""
        sortOption = .recommended
        priceRange = .all
        locationFilter = .all
        ratingFilter = 0.0
        applyFilters()
    }
    
    // MARK: - Private Methods
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func loadActivitiesFromNetwork() async {
        // Try OpenAI first, then fallback to mock data or API
        await loadActivitiesFromOpenAI()
        
        do {
            let activitiesResponse: ActivitiesResponse = try await apiClient.request(.activitiesList())
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
                // Show error state if no cached data
                let error = NetworkError.server(message: "Unable to generate date recommendations at this time")
                activities = .failed(error)
            }
        }
    }
    
    private func loadActivitiesFromOpenAI() async {
        print("🤖 Loading activities from OpenAI with geolocation...")
        print("🔧 Debug: Starting OpenAI request with location...")
        
        do {
            // Create search criteria for general activity discovery with geolocation
            let criteria = GeolocationActivityCriteria(
                location: currentLocation,
                cityName: userLocation?.city ?? "your area",
                radius: 25.0,
                personalityType: currentUser?.personalityType,
                relationshipDuration: currentUser?.relationshipDuration,
                idealActivities: currentUser?.personalityInsight?.idealActivities ?? [],
                priceRange: nil, // Get variety of prices
                category: selectedCategory != .recommended ? selectedCategory.rawValue : nil,
                timeOfDay: getCurrentTimeOfDay(),
                season: getCurrentSeason()
            )
            
            // Call OpenAI service
            print("🔧 Debug: Calling openAIService.findActivities...")
            print("🔧 Debug: Criteria - location: \(criteria.cityName ?? "none"), coordinates: \(currentLocation?.latitude ?? 0), \(currentLocation?.longitude ?? 0)")
            
            // Add timeout to prevent hanging (fast fallback to mock data)
            let openAIResponse = try await withTimeout(seconds: 75) { [weak self] in
                guard let self = self else { throw URLError(.cancelled) }
                return try await self.openAIService.findActivities(
                    criteria: criteria,
                    userPersonality: self.currentUser?.personalityInsight
                )
            }
            print("🔧 Debug: OpenAI response received with \(openAIResponse.recommendations.count) recommendations")
            
            // Convert OpenAI recommendations to Activity objects
            let activities = openAIResponse.recommendations.enumerated().map { index, aiRec in
                Activity(
                    id: 2000000 + index, // High ID to avoid conflicts with backend data
                    name: aiRec.name,
                    description: aiRec.description,
                    category: aiRec.category,
                    location: aiRec.location,
                    rating: nil, // OpenAI doesn't provide ratings
                    distance: nil, // Could calculate if location coordinates available
                    personalityMatch: aiRec.personality_match,
                    personalityMatchScore: 0.9, // High score for AI recommendations
                    imageUrl: nil,
                    estimatedCost: aiRec.estimated_cost,
                    duration: aiRec.duration,
                    bestTimeOfDay: aiRec.best_time_of_day,
                    whyRecommended: aiRec.why_recommended,
                    tips: aiRec.tips,
                    alternatives: aiRec.alternatives,
                    coordinates: self.currentLocation.map { ActivityCoordinates(latitude: $0.latitude, longitude: $0.longitude) },
                    tags: [aiRec.category.lowercased()], // Basic tags from category
                    ageAppropriate: nil,
                    accessibility: nil,
                    seasonality: nil,
                    groupSize: nil,
                    aiInsights: nil,
                    lastUpdated: Date(),
                    isAIGenerated: true // Mark as AI-generated
                )
            }
            
            // Store insights from OpenAI
            aiInsights = openAIResponse.search_context
            personalityInsights = openAIResponse.personality_insights
            
            // Update state
            self.activities = .loaded(activities)
            
            // Cache the results
            await cacheManager.save(
                activities,
                for: CacheKey.activitiesList,
                strategy: .hybrid(expiration: 1800) // 30 minutes for AI data
            )
            
            applyFilters()
            
            print("✅ Loaded \(activities.count) activities from OpenAI with geolocation")
            
        } catch {
            let errorMessage = error.localizedDescription
            if let urlError = error as? URLError, urlError.code == .timedOut || urlError.code == .cancelled {
                print("⏳ OpenAI request timed out before receiving a response")
            }
            print("❌ OpenAI failed: \(errorMessage)")
            print("🔧 Debug: Full error: \(error)")
            
            // Set error state to show message to user
            let error = NetworkError.server(message: "Unable to generate date recommendations at this time")
            self.activities = .failed(error)
        }
    }
    
    private func loadOpenAIRecommendationsDirectly(user: DomainUser) async {
        do {
            let recommendations = try await openAIService.getPersonalizedRecommendations(
                for: user,
                location: currentLocation,
                preferences: user.personalityInsight?.idealActivities ?? []
            )
            
            // Convert OpenAI recommendations to Activity objects
            let activities = recommendations.enumerated().map { index, aiRec in
                Activity(
                    id: 1000000 + index, // High ID to avoid conflicts
                    name: aiRec.name,
                    description: aiRec.description,
                    category: aiRec.category,
                    location: aiRec.location,
                    rating: nil,
                    distance: nil,
                    personalityMatch: aiRec.personality_match,
                    personalityMatchScore: 0.85, // High score for AI recommendations
                    imageUrl: nil,
                    estimatedCost: aiRec.estimated_cost,
                    duration: aiRec.duration,
                    bestTimeOfDay: aiRec.best_time_of_day,
                    whyRecommended: aiRec.why_recommended,
                    tips: aiRec.tips,
                    alternatives: aiRec.alternatives,
                    coordinates: currentLocation.map { ActivityCoordinates(latitude: $0.latitude, longitude: $0.longitude) },
                    tags: nil,
                    ageAppropriate: nil,
                    accessibility: nil,
                    seasonality: nil,
                    groupSize: nil,
                    aiInsights: nil,
                    lastUpdated: Date(),
                    isAIGenerated: true
                )
            }
            
            personalizedRecommendations = .loaded(activities)
            
        } catch {
            print("❌ OpenAI recommendations failed: \(error)")
            personalizedRecommendations = .failed(ErrorMapper.map(error))
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
    
    private func setupLocationMonitoring() {
        locationManager.requestWhenInUseAuthorization()
        
        // Monitor location changes
        NotificationCenter.default.publisher(for: NSNotification.Name("LocationUpdated"))
            .compactMap { $0.object as? CLLocationCoordinate2D }
            .assign(to: \.currentLocation, on: self)
            .store(in: &cancellables)
    }
    
    private func applyFilters() {
        let allActivities: [Activity]
        
        // Use personalized recommendations if available and we're in recommended mode
        if case .loaded(let personalized) = personalizedRecommendations,
           sortOption == .recommended && sessionStore.isAuthenticated {
            allActivities = personalized
        } else if case .loaded(let standard) = activities {
            allActivities = standard
        } else {
            filteredActivities = []
            return
        }
        
        var filtered = allActivities
        
        // Apply filters
        filtered = applyBasicFilters(to: filtered)
        filtered = applyLocationFilters(to: filtered)
        filtered = applyPriceFilters(to: filtered)
        filtered = applyRatingFilter(to: filtered)
        
        // Apply sorting
        filtered = sortActivities(filtered)
        
        filteredActivities = filtered
    }
    
    private func applyBasicFilters(to activities: [Activity]) -> [Activity] {
        var filtered = activities
        
        // Category filter
        if selectedCategory != .recommended {
            filtered = filtered.filter { $0.category.lowercased() == selectedCategory.rawValue.lowercased() }
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
        
        return filtered
    }
    
    private func applyLocationFilters(to activities: [Activity]) -> [Activity] {
        guard locationFilter != .all else { return activities }
        
        return activities.filter { activity in
            guard let distance = parseDistance(activity.distance) else { return true }
            
            switch locationFilter {
            case .all: return true
            case .nearby: return distance <= 5.0
            case .city: return distance <= 15.0
            case .region: return distance <= 50.0
            }
        }
    }
    
    private func applyPriceFilters(to activities: [Activity]) -> [Activity] {
        guard priceRange != .all else { return activities }
        
        return activities.filter { activity in
            guard let priceString = activity.estimatedCost,
                  let price = parsePrice(priceString) else {
                return priceRange == .free
            }
            
            switch priceRange {
            case .all: return true
            case .free: return price == 0
            case .budget: return price > 0 && price <= 25
            case .moderate: return price > 25 && price <= 75
            case .premium: return price > 75
            }
        }
    }
    
    private func applyRatingFilter(to activities: [Activity]) -> [Activity] {
        guard ratingFilter > 0.0 else { return activities }
        
        return activities.filter { activity in
            (activity.rating ?? 0.0) >= ratingFilter
        }
    }
    
    private func sortActivities(_ activities: [Activity]) -> [Activity] {
        switch sortOption {
        case .recommended:
            return activities.sorted { (a: Activity, b: Activity) in
                // Prioritize AI-generated activities
                if a.isAIGenerated && !b.isAIGenerated { return true }
                if !a.isAIGenerated && b.isAIGenerated { return false }
                
                // Then sort by personality match score
                let scoreA = a.personalityMatchScore ?? 0.0
                let scoreB = b.personalityMatchScore ?? 0.0
                return scoreA > scoreB
            }
        case .rating:
            return activities.sorted { ($0.rating ?? 0.0) > ($1.rating ?? 0.0) }
        case .distance:
            return activities.sorted { parseDistance($0.distance) ?? 1000 < parseDistance($1.distance) ?? 1000 }
        case .name:
            return activities.sorted { $0.name < $1.name }
        case .newest:
            return activities.sorted { ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast) }
        case .price:
            return activities.sorted {
                let priceA = parsePrice($0.estimatedCost) ?? 0
                let priceB = parsePrice($1.estimatedCost) ?? 0
                return priceA < priceB
            }
        }
    }
    
    private func parseDistance(_ distanceString: String?) -> Double? {
        guard let distanceString = distanceString else { return nil }
        
        // Parse distance string like "2.3 mi" or "1.5 miles"
        let components = distanceString.components(separatedBy: .whitespaces)
        guard let distanceValue = components.first,
              let distance = Double(distanceValue) else { return nil }
        
        return distance
    }
    
    private func parsePrice(_ priceString: String?) -> Double? {
        guard let priceString = priceString else { return nil }
        
        // Remove currency symbols and extract number
        let cleanString = priceString.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .components(separatedBy: .whitespaces).first ?? ""
        
        // Handle ranges like "15-25"
        if cleanString.contains("-") {
            let parts = cleanString.split(separator: "-")
            if let firstPart = parts.first, let price = Double(firstPart) {
                return price
            }
        }
        
        return Double(cleanString)
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "spring"
        case 6...8: return "summer"
        case 9...11: return "fall"
        default: return "winter"
        }
    }
    
    private func enrichActivitiesWithPersonalityMatch(_ activities: [Activity]) async -> [Activity] {
        guard let user = currentUser, let personality = user.personalityInsight else {
            return activities
        }
        
        return activities.map { activity in
            let (score, explanation) = calculatePersonalityMatch(
                activity: activity,
                personality: personality
            )
            
            var enriched = activity
            enriched.personalityMatchScore = score
            enriched.personalityMatch = explanation
            return enriched
        }
    }
    
    private func calculatePersonalityMatch(activity: Activity, personality: PersonalityInsight) -> (Double, String) {
        var score = 0.5 // Base score
        var reasons: [String] = []
        
        // Match against ideal activities
        for idealActivity in personality.idealActivities {
            if activity.name.localizedCaseInsensitiveContains(idealActivity) ||
               activity.description.localizedCaseInsensitiveContains(idealActivity) {
                score += 0.1
                reasons.append("Matches your preferences")
                break
            }
        }
        
        // Communication style matching
        if personality.communicationStyle.lowercased().contains("intimate") && 
           (activity.category.lowercased().contains("romantic") || activity.groupSize == "intimate") {
            score += 0.15
            reasons.append("Suits your communication style")
        }
        
        // Love language matching
        switch personality.loveLanguage.lowercased() {
        case let lang where lang.contains("quality"):
            if activity.category.lowercased().contains("romantic") || 
               activity.category.lowercased().contains("intimate") {
                score += 0.1
                reasons.append("Perfect for quality time")
            }
        case let lang where lang.contains("adventure"):
            if activity.category.lowercased().contains("active") ||
               activity.category.lowercased().contains("outdoor") {
                score += 0.1
                reasons.append("Great for adventure seekers")
            }
        default:
            break
        }
        
        // Ensure score is within bounds
        score = min(max(score, 0.0), 1.0)
        
        let explanation = reasons.isEmpty ? 
            "This activity suits your personality style" : 
            reasons.joined(separator: ". ") + "."
        
        return (score, explanation)
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
}

// MARK: - Cache Extensions

extension CacheKey {
    static let activitiesList = "activities_list"
    static func personalizedActivities(userId: Int) -> String {
        return "personalized_activities_\(userId)"
    }
}