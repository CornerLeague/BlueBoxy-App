import SwiftUI
import Combine
import CoreLocation

@MainActor
final class RecommendationsViewModel: ObservableObject {
    @Published var simpleRecs: Loadable<[SimpleRecommendation]> = .idle
    @Published var aiPoweredRecs: Loadable<AIPoweredRecommendationsResponse> = .idle
    @Published var grokRecs: Loadable<GrokLocationPostResponse> = .idle
    @Published var selectedCategory = "recommended"
    @Published var userLocation: GeoLocationPayload?
    @Published var isRefreshing = false
    @Published var favoriteRecommendations: Set<String> = []
    @Published var dismissedRecommendations: Set<String> = []
    @Published var filterOptions: RecommendationFilters = RecommendationFilters()
    
    private let apiClient: APIClient
    private let cacheManager = CacheManager.shared
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    struct RecommendationFilters {
        var maxDistance: Double = 25.0 // miles
        var priceRange: PriceRange = .all
        var timeOfDay: FilterTimeOfDay = .any
        var groupSize: GroupSize = .any
        var includeBookmarked: Bool = true
        
        enum PriceRange: String, CaseIterable {
            case all = "all"
            case free = "free"
            case budget = "budget"
            case moderate = "moderate"
            case premium = "premium"
            
            var displayName: String {
                switch self {
                case .all: return "All Prices"
                case .free: return "Free"
                case .budget: return "$0-25"
                case .moderate: return "$25-75"
                case .premium: return "$75+"
                }
            }
        }
        
        enum FilterTimeOfDay: String, CaseIterable {
            case any = "any"
            case morning = "morning"
            case afternoon = "afternoon"
            case evening = "evening"
            case night = "night"
            
            var displayName: String {
                switch self {
                case .any: return "Any Time"
                case .morning: return "Morning"
                case .afternoon: return "Afternoon"
                case .evening: return "Evening"
                case .night: return "Night"
                }
            }
        }
        
        enum GroupSize: String, CaseIterable {
            case any = "any"
            case solo = "solo"
            case couple = "couple"
            case small = "small"
            case large = "large"
            
            var displayName: String {
                switch self {
                case .any: return "Any Size"
                case .solo: return "Solo"
                case .couple: return "Couple"
                case .small: return "Small Group"
                case .large: return "Large Group"
                }
            }
        }
    }
    
    private let categories = [
        ("recommended", "Recommended", "⭐", "sparkles"),
        ("dining", "Dining", "🍽️", "fork.knife"),
        ("outdoor", "Outdoor", "🌳", "leaf.fill"),
        ("cultural", "Cultural", "🎭", "building.columns"),
        ("active", "Active", "⚡", "figure.run"),
        ("shopping", "Shopping", "🛍️", "bag.fill"),
        ("entertainment", "Entertainment", "🎬", "tv.fill"),
        ("nightlife", "Nightlife", "🌙", "moon.stars.fill")
    ]
    
    var availableCategories: [(String, String, String, String)] {
        return categories
    }
    
    var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse || 
        locationManager.authorizationStatus == .authorizedAlways
    }
    
    var canShowLocationBasedRecs: Bool {
        hasLocationPermission && userLocation != nil
    }
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        loadFavorites()
        setupLocationObserver()
    }
    
    // MARK: - Location Management
    
    private func setupLocationObserver() {
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.userLocation = GeoLocationPayload(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            .store(in: &cancellables)
    }
    
    func requestLocationPermission() {
        locationManager.requestPermission()
    }
    
    // MARK: - Data Loading
    
    func loadAllRecommendations() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSimpleRecommendations() }
            group.addTask { 
                await self.loadAIPoweredRecommendations(
                    category: self.selectedCategory,
                    location: self.userLocation
                )
            }
            if let location = userLocation {
                group.addTask {
                    await self.loadGrokRecommendations(
                        location: location,
                        category: self.selectedCategory
                    )
                }
            }
        }
    }
    
    func loadSimpleRecommendations() async {
        // Try cache first
        if let cachedRecs = await cacheManager.load(
            for: CacheKey.simpleRecommendations,
            type: [SimpleRecommendation].self
        ) {
            simpleRecs = .loaded(cachedRecs)
        } else {
            simpleRecs = .loading()
        }
        
        do {
            let recs: [SimpleRecommendation] = try await apiClient.request(.recommendationsActivities())
            let enhancedRecs = await enrichSimpleRecommendations(recs)
            simpleRecs = .loaded(enhancedRecs)
            
            // Cache results
            await cacheManager.save(
                enhancedRecs,
                for: CacheKey.simpleRecommendations,
                strategy: .hybrid(expiration: 1800) // 30 minutes
            )
        } catch {
            // If we have cached data, keep showing it
            if case .loaded = simpleRecs {
                return
            }
            simpleRecs = .failed(ErrorMapper.map(error))
        }
    }
    
    func loadAIPoweredRecommendations(category: String, location: GeoLocationPayload?) async {
        let cacheKey = "ai_recs_\(category)_\(location?.latitude ?? 0)_\(location?.longitude ?? 0)"
        
        // Try cache first
        if let cachedRecs = await cacheManager.load(
            for: cacheKey,
            type: AIPoweredRecommendationsResponse.self
        ) {
            aiPoweredRecs = .loaded(cachedRecs)
        } else {
            aiPoweredRecs = .loading()
        }
        
        do {
            let request = AIPoweredRecommendationsRequest(
                category: category,
                location: location,
                personalityContext: await getPersonalityContext(),
                filters: createAPIFilters()
            )
            let response: AIPoweredRecommendationsResponse = try await apiClient.request(.recommendationsActivities()) // TODO: Replace with correct AI-powered endpoint
            let enhancedResponse = await enrichAIPoweredRecommendations(response)
            aiPoweredRecs = .loaded(enhancedResponse)
            
            // Cache results
            await cacheManager.save(
                enhancedResponse,
                for: cacheKey,
                strategy: .hybrid(expiration: 900) // 15 minutes
            )
        } catch {
            if case .loaded = aiPoweredRecs {
                return
            }
            aiPoweredRecs = .failed(ErrorMapper.map(error))
        }
    }
    
    func loadGrokRecommendations(location: GeoLocationPayload, category: String) async {
        let cacheKey = "grok_recs_\(category)_\(location.latitude)_\(location.longitude)"
        
        // Try cache first
        if let cachedRecs = await cacheManager.load(
            for: cacheKey,
            type: GrokLocationPostResponse.self,
            strategy: .diskOnly()
        ) {
            grokRecs = .loaded(cachedRecs)
        } else {
            grokRecs = .loading()
        }
        
        do {
            let request = LocationBasedPostRequest(
                location: location,
                radius: filterOptions.maxDistance,
                category: category,
                filters: createGrokFilters()
            )
            let response: GrokLocationPostResponse = try await apiClient.request(.recommendationsLocationPOST(request))
            let enhancedResponse = await enrichGrokRecommendations(response)
            grokRecs = .loaded(enhancedResponse)
            
            // Cache results
            await cacheManager.save(
                enhancedResponse,
                for: cacheKey,
                strategy: .memoryOnly(expiration: 300) // 5 minutes for location-based
            )
        } catch {
            if case .loaded = grokRecs {
                return
            }
            grokRecs = .failed(ErrorMapper.map(error))
        }
    }
    
    // MARK: - Data Enhancement
    
    private func enrichSimpleRecommendations(_ recs: [SimpleRecommendation]) async -> [SimpleRecommendation] {
        // TODO: Add isFavorite and isDismissed properties to SimpleRecommendation model
        // For now, just return the recommendations as-is
        return recs
    }
    
    private func enrichAIPoweredRecommendations(_ response: AIPoweredRecommendationsResponse) async -> AIPoweredRecommendationsResponse {
        // TODO: Add isFavorite and isDismissed properties to AIPoweredActivity model
        // For now, just return the recommendations as-is
        return response
    }
    
    private func enrichGrokRecommendations(_ response: GrokLocationPostResponse) async -> GrokLocationPostResponse {
        // TODO: Add isFavorite and isDismissed properties to Activity model
        // For now, just return the recommendations as-is
        // Note: The favorites are tracked by ID as String, but Activity.id is Int
        return response
    }
    
    private func getPersonalityContext() async -> PersonalityContext? {
        // First try to get user data which contains personalityType
        guard let user = await cacheManager.load(
            for: "currentUser",
            type: DomainUser.self
        ), let personalityType = user.personalityType else { return nil }
        
        // Try to get insight details if available
        if let insight = await cacheManager.load(
            for: CacheKey.personalityInsight,
            type: PersonalityInsight.self
        ) {
            return PersonalityContext(
                personalityType: personalityType,
                loveLanguage: insight.loveLanguage,
                communicationStyle: insight.communicationStyle,
                idealActivities: insight.idealActivities
            )
        }
        
        // Fallback with just personality type
        return PersonalityContext(
            personalityType: personalityType,
            loveLanguage: "Unknown",
            communicationStyle: "Unknown",
            idealActivities: []
        )
    }
    
    private func createAPIFilters() -> APIRecommendationFilters {
        return APIRecommendationFilters(
            priceRange: filterOptions.priceRange.rawValue,
            timeOfDay: filterOptions.timeOfDay.rawValue,
            groupSize: filterOptions.groupSize.rawValue,
            maxDistance: filterOptions.maxDistance
        )
    }
    
    private func createGrokFilters() -> GrokFilters {
        return GrokFilters(
            priceRange: filterOptions.priceRange.rawValue,
            timeOfDay: filterOptions.timeOfDay.rawValue,
            includeBookmarked: filterOptions.includeBookmarked
        )
    }
    
    // MARK: - User Actions
    
    func regenerateRecommendations() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Clear caches for fresh data
        await clearRecommendationCaches()
        
        await loadAllRecommendations()
    }
    
    func toggleFavorite(for id: String) {
        if favoriteRecommendations.contains(id) {
            favoriteRecommendations.remove(id)
        } else {
            favoriteRecommendations.insert(id)
        }
        saveFavorites()
        
        // Update current data
        updateRecommendationStates()
    }
    
    func dismissRecommendation(id: String) {
        dismissedRecommendations.insert(id)
        saveDismissed()
        updateRecommendationStates()
    }
    
    func undoDismissRecommendation(id: String) {
        dismissedRecommendations.remove(id)
        saveDismissed()
        updateRecommendationStates()
    }
    
    func changeCategory(_ category: String) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        
        Task {
            await loadAIPoweredRecommendations(
                category: category,
                location: userLocation
            )
            if let location = userLocation {
                await loadGrokRecommendations(
                    location: location,
                    category: category
                )
            }
        }
    }
    
    func applyFilters(_ filters: RecommendationFilters) {
        filterOptions = filters
        
        Task {
            await regenerateRecommendations()
        }
    }
    
    // MARK: - Persistence
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorite_recommendations"),
           let favorites = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteRecommendations = favorites
        }
        
        if let data = UserDefaults.standard.data(forKey: "dismissed_recommendations"),
           let dismissed = try? JSONDecoder().decode(Set<String>.self, from: data) {
            dismissedRecommendations = dismissed
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteRecommendations) {
            UserDefaults.standard.set(data, forKey: "favorite_recommendations")
        }
    }
    
    private func saveDismissed() {
        if let data = try? JSONEncoder().encode(dismissedRecommendations) {
            UserDefaults.standard.set(data, forKey: "dismissed_recommendations")
        }
    }
    
    private func updateRecommendationStates() {
        // Update simple recommendations
        if case .loaded(let recs) = simpleRecs {
            Task {
                let updated = await enrichSimpleRecommendations(recs)
                await MainActor.run {
                    simpleRecs = .loaded(updated)
                }
            }
        }
        
        // Update AI-powered recommendations
        if case .loaded(let response) = aiPoweredRecs {
            Task {
                let updated = await enrichAIPoweredRecommendations(response)
                await MainActor.run {
                    aiPoweredRecs = .loaded(updated)
                }
            }
        }
        
        // Update Grok recommendations
        if case .loaded(let response) = grokRecs {
            Task {
                let updated = await enrichGrokRecommendations(response)
                await MainActor.run {
                    grokRecs = .loaded(updated)
                }
            }
        }
    }
    
    private func clearRecommendationCaches() async {
        await cacheManager.remove(for: CacheKey.simpleRecommendations)
        
        // Clear all AI-powered recommendation caches
        for category in categories {
            let cacheKey = "ai_recs_\(category.0)_\(userLocation?.latitude ?? 0)_\(userLocation?.longitude ?? 0)"
            await cacheManager.remove(for: cacheKey)
        }
        
        // Clear Grok caches
        if let location = userLocation {
            for category in categories {
                let cacheKey = "grok_recs_\(category.0)_\(location.latitude)_\(location.longitude)"
                await cacheManager.remove(for: cacheKey)
            }
        }
    }
    
    // MARK: - Analytics & Insights
    
    func trackRecommendationInteraction(_ interaction: RecommendationInteraction) {
        // Track user interactions for improving recommendations
        Task {
            do {
                // For now, silently track interaction locally
                // TODO: Implement trackInteraction endpoint
                // try await apiClient.request(.trackInteraction(interaction))
            } catch {
                // Silently fail analytics
            }
        }
    }
    
    var recommendationStats: RecommendationStats {
        var totalCount = 0
        var favoriteCount = favoriteRecommendations.count
        var dismissedCount = dismissedRecommendations.count
        
        if case .loaded(let recs) = simpleRecs {
            totalCount += recs.count
        }
        
        if case .loaded(let response) = aiPoweredRecs {
            totalCount += response.recommendations.activities.count
        }
        
        if case .loaded(let response) = grokRecs {
            totalCount += response.recommendations.count
        }
        
        return RecommendationStats(
            totalRecommendations: totalCount,
            favoriteCount: favoriteCount,
            dismissedCount: dismissedCount,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

struct PersonalityContext: Codable {
    let personalityType: String
    let loveLanguage: String
    let communicationStyle: String
    let idealActivities: [String]
}

struct APIRecommendationFilters: Codable {
    let priceRange: String
    let timeOfDay: String
    let groupSize: String
    let maxDistance: Double
}

struct GrokFilters: Codable {
    let priceRange: String
    let timeOfDay: String
    let includeBookmarked: Bool
}

struct RecommendationInteraction: Codable {
    let recommendationId: String
    let type: InteractionType
    let category: String
    let timestamp: Date
    
    enum InteractionType: String, Codable {
        case view, favorite, dismiss, share, book
    }
}

struct RecommendationStats {
    let totalRecommendations: Int
    let favoriteCount: Int
    let dismissedCount: Int
    let lastUpdated: Date
}

// MARK: - Extensions

extension AIPoweredRecommendationsRequest {
    init(category: String, location: GeoLocationPayload?, personalityContext: PersonalityContext? = nil, filters: APIRecommendationFilters? = nil) {
        self.init(
            category: category,
            location: location
        )
        // Extended initialization would include personality context and filters
    }
}

extension LocationBasedPostRequest {
    init(location: GeoLocationPayload, radius: Double, category: String, filters: GrokFilters? = nil) {
        self.init(
            location: location,
            radius: radius,
            category: category
        )
        // Extended initialization would include filters
    }
}

// MARK: - Model Extensions

extension SimpleRecommendation {
    var isFavorite: Bool {
        get { return false } // Would be stored in actual model
        set { } // Would be stored in actual model
    }
    
    var isDismissed: Bool {
        get { return false } // Would be stored in actual model
        set { } // Would be stored in actual model
    }
    
    var id: String? {
        return nil // Would be part of actual model
    }
}

extension AIPoweredActivity {
    var isFavorite: Bool {
        get { return false }
        set { }
    }
    
    var isDismissed: Bool {
        get { return false }
        set { }
    }
}

extension GrokActivityRecommendation {
    var isFavorite: Bool {
        get { return false }
        set { }
    }
    
    var isDismissed: Bool {
        get { return false }
        set { }
    }
}

// MARK: - Cache Extensions

extension CacheKey {
    static let simpleRecommendations = "simple_recommendations"
}

// MARK: - API Extensions

extension Endpoint {
    static func trackInteraction(_ interaction: RecommendationInteraction) -> Endpoint {
        Endpoint(path: "/api/recommendations/interactions", method: .POST)
    }
}

// MARK: - Location Manager

final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            location = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}