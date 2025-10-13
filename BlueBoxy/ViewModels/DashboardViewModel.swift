//
//  DashboardViewModel.swift
//  BlueBoxy
//
//  Dashboard data aggregation and overview state management
//  Handles loading activities, stats, events, and dashboard overview
//

import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var activities: Loadable<ActivitiesResponse> = .idle
    @Published var stats: Loadable<UserStatsResponse> = .idle
    @Published var recentEvents: Loadable<[Event]> = .idle
    @Published var recommendations: Loadable<RecommendationsResponse> = .idle
    @Published var overallLoadingState: Loadable<Void> = .idle
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let cache = FileResponseCache()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private let maxRecentEvents = 5
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        setupRefreshTimer()
        observeAuthenticationChanges()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Dashboard Loading
    
    /// Load all dashboard data concurrently
    func loadDashboard(forceRefresh: Bool = false) async {
        overallLoadingState = .loading()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadActivities(forceRefresh: forceRefresh) }
            group.addTask { await self.loadStats() }
            group.addTask { await self.loadRecentEvents() }
            group.addTask { await self.loadRecommendations() }
        }
        
        // Check if any critical data failed to load
        let hasFailures = activities.isFailed || stats.isFailed || recentEvents.isFailed
        if hasFailures {
            // Find the first error to surface
            let error = activities.error ?? stats.error ?? recentEvents.error ?? NetworkError.unknown(status: nil)
            overallLoadingState = .failed(error)
        } else {
            overallLoadingState = .loaded(())
        }
    }
    
    /// Refresh dashboard data (user-initiated)
    func refreshDashboard() async {
        await loadDashboard(forceRefresh: true)
    }
    
    // MARK: - Individual Data Loading
    
    /// Load activities with caching support
    private func loadActivities(forceRefresh: Bool = false) async {
        activities = .loading()
        
        do {
            let response: ActivitiesResponse = try await apiClient.request(
                Endpoint(path: "/api/activities", method: .GET)
            )
            activities = .loaded(response)
        } catch {
            let networkError = error as? NetworkError ?? NetworkError.unknown(status: nil)
            activities = .failed(networkError)
        }
        return
    }
    
    /// Load user statistics
    private func loadStats() async {
        stats = .loading()
        
        let result: Result<UserStatsResponse, NetworkError> = await apiClient.requestWithRetryResult(
            Endpoint(path: "/api/user/stats", method: .GET),
            policy: .default
        )
        
        switch result {
        case .success(let response):
            stats = .loaded(response)
        case .failure(let error):
            stats = .failed(error)
        }
    }
    
    /// Load recent events
    private func loadRecentEvents() async {
        recentEvents = .loading()
        
        // Get events for the next 30 days
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let result: Result<EventsResponse, NetworkError> = await apiClient.requestWithRetryResult(
            Endpoint(path: "/api/events?start=\(formatter.string(from: startDate))&end=\(formatter.string(from: endDate))", method: .GET),
            policy: .default
        )
        
        switch result {
        case .success(let response):
            // Sort by date and take most recent
            let sortedEvents = response.events
                .sorted { $0.startTime < $1.startTime }
                .prefix(maxRecentEvents)
            recentEvents = .loaded(Array(sortedEvents))
        case .failure(let error):
            recentEvents = .failed(error)
        }
    }
    
    /// Load recommendations for dashboard preview
    private func loadRecommendations() async {
        recommendations = .loading()
        
        do {
            let response: RecommendationsResponse = try await apiClient.request(
                Endpoint(path: "/api/recommendations", method: .GET)
            )
            recommendations = .loaded(response)
        } catch {
            let networkError = error as? NetworkError ?? NetworkError.unknown(status: nil)
            recommendations = .failed(networkError)
        }
        return
    }
    
    // MARK: - Computed Properties
    
    /// Whether the dashboard is currently loading
    var isLoading: Bool {
        return overallLoadingState.isLoading ||
               activities.isLoading ||
               stats.isLoading ||
               recentEvents.isLoading ||
               recommendations.isLoading
    }
    
    /// Whether all critical data has loaded successfully
    var hasLoadedSuccessfully: Bool {
        return activities.isLoaded && stats.isLoaded && recentEvents.isLoaded
    }
    
    /// Get dashboard summary for quick overview
    var dashboardSummary: DashboardSummary? {
        guard let activitiesData = activities.value,
              let statsData = stats.value,
              let eventsData = recentEvents.value else {
            return nil
        }
        
        return DashboardSummary(
            totalActivities: activitiesData.activities.count,
            eventsCreated: statsData.eventsCreated,
            messagesGenerated: 0, // TODO: Add to UserStatsResponse
            upcomingEvents: eventsData.count,
            streakDays: 0, // TODO: Add to UserStatsResponse
            lastActive: nil // TODO: Add to UserStatsResponse
        )
    }
    
    /// Get error summary for dashboard
    var dashboardError: NetworkError? {
        // Return the most critical error first
        return activities.error ?? stats.error ?? recentEvents.error ?? recommendations.error
    }
    
    // MARK: - Background Refresh
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                // Only refresh if we're not currently loading and user is authenticated
                if !self.isLoading {
                    await self.loadDashboard()
                }
            }
        }
    }
    
    private func observeAuthenticationChanges() {
        // Refresh dashboard when user logs in
        NotificationCenter.default
            .publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadDashboard()
                }
            }
            .store(in: &cancellables)
        
        // Clear dashboard when user logs out
        NotificationCenter.default
            .publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearDashboard()
            }
            .store(in: &cancellables)
    }
    
    private func clearDashboard() {
        activities = .idle
        stats = .idle
        recentEvents = .idle
        recommendations = .idle
        overallLoadingState = .idle
    }
    
    // MARK: - Quick Actions
    
    /// Create a new event directly from dashboard
    func quickCreateEvent(title: String, startTime: Date, endTime: Date) async -> Bool {
        let request = CreateEventRequest(
            title: title,
            startTime: startTime,
            endTime: endTime,
            eventType: "quick"
        )
        
        do {
            let _: Event = try await apiClient.request(.eventsCreate(request))
            // Refresh recent events after creating
            await loadRecentEvents()
            return true
        } catch {
            print("⚠️ Failed to create quick event: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get activity recommendation by category
    func getRecommendationsByCategory(_ category: String) -> [Activity] {
        guard let recommendationsData = recommendations.value else { return [] }
        
        return recommendationsData.recommendations
            .filter { activity in
                activity.category.lowercased() == category.lowercased()
            }
            .map { aiActivity in
                // Convert AIPoweredActivity to Activity
                Activity(
                    id: aiActivity.id,
                    name: aiActivity.name,
                    description: aiActivity.description,
                    category: aiActivity.category,
                    location: aiActivity.location,
                    rating: aiActivity.rating,
                    distance: aiActivity.distance,
                    personalityMatch: aiActivity.personalityMatch,
                    imageUrl: aiActivity.imageUrl
                )
            }
    }
}

// MARK: - Dashboard Summary

struct DashboardSummary {
    let totalActivities: Int
    let eventsCreated: Int
    let messagesGenerated: Int
    let upcomingEvents: Int
    let streakDays: Int
    let lastActive: Date?
    
    /// Formatted streak display
    var streakDescription: String {
        if streakDays == 0 {
            return "Start your streak today!"
        } else if streakDays == 1 {
            return "1 day streak 🔥"
        } else {
            return "\(streakDays) day streak 🔥"
        }
    }
    
    /// Activity level based on recent usage
    var activityLevel: ActivityLevel {
        guard let lastActive = lastActive else { return .inactive }
        
        let daysSinceActive = Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
        
        switch daysSinceActive {
        case 0:
            return .veryActive
        case 1...2:
            return .active
        case 3...7:
            return .moderate
        default:
            return .inactive
        }
    }
}

enum ActivityLevel: String, CaseIterable {
    case veryActive = "Very Active"
    case active = "Active"
    case moderate = "Moderate"
    case inactive = "Inactive"
    
    var color: String {
        switch self {
        case .veryActive: return "green"
        case .active: return "blue"
        case .moderate: return "orange"
        case .inactive: return "gray"
        }
    }
    
    var description: String {
        switch self {
        case .veryActive: return "You're crushing it! 🚀"
        case .active: return "Keep up the great work! 💪"
        case .moderate: return "Nice progress! 👍"
        case .inactive: return "Let's get back into it! 🌟"
        }
    }
}

// MARK: - Cache Configuration Extensions

private extension CacheConfiguration {
    func with(strategy: NetworkCacheStrategy) -> CacheConfiguration {
        return CacheConfiguration(
            strategy: strategy,
            cache: self.cache,
            cacheKey: self.cacheKey,
            policy: self.policy
        )
    }
    
    func with(cacheKey: String) -> CacheConfiguration {
        return CacheConfiguration(
            strategy: self.strategy,
            cache: self.cache,
            cacheKey: cacheKey,
            policy: self.policy
        )
    }
}