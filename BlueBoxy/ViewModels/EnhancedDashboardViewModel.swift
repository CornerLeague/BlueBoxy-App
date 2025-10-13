import Foundation
import SwiftUI
import Combine

@MainActor
class EnhancedDashboardViewModel: ObservableObject {
    @Published var stats: Loadable<UserStatsResponse> = .idle
    @Published var activities: Loadable<[Activity]> = .idle
    @Published var recentEvents: Loadable<[CalendarEventDB]> = .idle
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var isOffline = false
    
    private let apiClient: APIClient
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Network monitoring
    private let networkMonitor = NetworkMonitor()
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func loadDashboard() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        // Load from cache first for instant display
        await loadFromCache()
        
        // Then load from network if available
        if networkMonitor.isConnected {
            await loadFromNetwork()
        } else {
            isOffline = true
        }
        
        isRefreshing = false
        lastUpdated = Date()
    }
    
    func refreshDashboard() async {
        // Force refresh from network, ignoring cache
        await loadFromNetworkForced()
    }
    
    func preloadCache() async {
        // Pre-load essential data for offline use
        await loadFromCache()
        
        // Background fetch if network available
        if networkMonitor.isConnected {
            Task.detached(priority: .background) {
                await self.loadFromNetwork()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                
                // Automatically refresh when network becomes available
                if isConnected, let lastUpdated = self?.lastUpdated {
                    let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdated)
                    if timeSinceLastUpdate > 300 { // 5 minutes
                        Task {
                            await self?.loadFromNetwork()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadFromCache() async {
        await withTaskGroup(of: Void.self) { group in
            // Load activities from cache
            group.addTask {
                if let cachedActivities = await self.cacheManager.load(
                    for: CacheKey.dashboardActivities,
                    type: [Activity].self
                ) {
                    await MainActor.run {
                        self.activities = .loaded(cachedActivities)
                    }
                }
            }
            
            // Load stats from cache
            group.addTask {
                if let cachedStats = await self.cacheManager.load(
                    for: CacheKey.dashboardStats,
                    type: UserStatsResponse.self
                ) {
                    await MainActor.run {
                        self.stats = .loaded(cachedStats)
                    }
                }
            }
            
            // Load events from cache
            group.addTask {
                if let cachedEvents = await self.cacheManager.load(
                    for: CacheKey.dashboardEvents,
                    type: [CalendarEventDB].self
                ) {
                    await MainActor.run {
                        self.recentEvents = .loaded(cachedEvents)
                    }
                }
            }
        }
    }
    
    private func loadFromNetwork() async {
        await withTaskGroup(of: Void.self) { group in
            // Load activities
            group.addTask {
                await self.loadActivitiesFromNetwork()
            }
            
            // Load stats
            group.addTask {
                await self.loadStatsFromNetwork()
            }
            
            // Load events
            group.addTask {
                await self.loadEventsFromNetwork()
            }
        }
    }
    
    private func loadFromNetworkForced() async {
        isRefreshing = true
        
        // Set loading states
        activities = .loading()
        stats = .loading()
        recentEvents = .loading()
        
        await loadFromNetwork()
        
        isRefreshing = false
        lastUpdated = Date()
    }
    
    private func loadActivitiesFromNetwork() async {
        do {
            let items: [Activity] = try await apiClient.request(.activitiesList())
            
            await MainActor.run {
                self.activities = .loaded(items)
            }
            
            // Cache the results
            await cacheManager.save(
                items,
                for: CacheKey.dashboardActivities,
                strategy: .hybrid(expiration: 1800) // 30 minutes
            )
            
        } catch {
            await handleNetworkError(for: \.activities, error: error, cacheKey: CacheKey.dashboardActivities, type: [Activity].self)
        }
    }
    
    private func loadStatsFromNetwork() async {
        do {
            let statsResponse: UserStatsResponse = try await apiClient.request(.userStats())
            
            await MainActor.run {
                self.stats = .loaded(statsResponse)
            }
            
            // Cache the results
            await cacheManager.save(
                statsResponse,
                for: CacheKey.dashboardStats,
                strategy: .hybrid(expiration: 3600) // 1 hour
            )
            
        } catch {
            await handleNetworkError(for: \.stats, error: error, cacheKey: CacheKey.dashboardStats, type: UserStatsResponse.self)
        }
    }
    
    private func loadEventsFromNetwork() async {
        do {
            let events: [CalendarEventDB] = try await apiClient.request(.recentEvents())
            
            await MainActor.run {
                self.recentEvents = .loaded(events)
            }
            
            // Cache the results
            await cacheManager.save(
                events,
                for: CacheKey.dashboardEvents,
                strategy: .hybrid(expiration: 900) // 15 minutes
            )
            
        } catch {
            await handleNetworkError(for: \.recentEvents, error: error, cacheKey: CacheKey.dashboardEvents, type: [CalendarEventDB].self)
        }
    }
    
    private func handleNetworkError<T: Codable>(
        for keyPath: ReferenceWritableKeyPath<EnhancedDashboardViewModel, Loadable<T>>,
        error: Error,
        cacheKey: String,
        type: T.Type
    ) async {
        // Try cache fallback
        if let cachedData = await cacheManager.load(for: cacheKey, type: type) {
            await MainActor.run {
                self[keyPath: keyPath] = .loaded(cachedData)
                self.isOffline = true
            }
        } else {
            await MainActor.run {
                self[keyPath: keyPath] = Loadable<T>.failed(ErrorMapper.map(error))
            }
        }
    }
}

// MARK: - Cache Management Extension

extension EnhancedDashboardViewModel {
    
    func getCacheStatus() async -> CacheStatus {
        let activitiesExpired = await cacheManager.isExpired(for: CacheKey.dashboardActivities)
        let statsExpired = await cacheManager.isExpired(for: CacheKey.dashboardStats)
        let eventsExpired = await cacheManager.isExpired(for: CacheKey.dashboardEvents)
        
        let cacheSize = await cacheManager.cacheSize
        
        return CacheStatus(
            activitiesExpired: activitiesExpired,
            statsExpired: statsExpired,
            eventsExpired: eventsExpired,
            totalCacheSize: cacheSize,
            lastUpdated: lastUpdated
        )
    }
    
    func clearCache() async {
        await cacheManager.clear()
        
        // Reset to idle state
        await MainActor.run {
            self.activities = .idle
            self.stats = .idle
            self.recentEvents = .idle
            self.lastUpdated = nil
        }
    }
    
    func refreshSpecificData(_ dataType: DashboardDataType) async {
        switch dataType {
        case .activities:
            activities = .loading()
            await loadActivitiesFromNetwork()
        case .stats:
            stats = .loading()
            await loadStatsFromNetwork()
        case .events:
            recentEvents = .loading()
            await loadEventsFromNetwork()
        }
    }
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    private var monitor: Any?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Simplified network monitoring
        // In a real app, you'd use Network framework
        
        // Simulate network status changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // This would be actual network status in production
            DispatchQueue.main.async {
                // For demo purposes, assume always connected
                self?.isConnected = true
            }
        }
    }
}

// MARK: - Supporting Types

struct CacheStatus {
    let activitiesExpired: Bool
    let statsExpired: Bool
    let eventsExpired: Bool
    let totalCacheSize: Int64
    let lastUpdated: Date?
    
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCacheSize)
    }
    
    var hasExpiredData: Bool {
        activitiesExpired || statsExpired || eventsExpired
    }
    
    var cacheHealthScore: Double {
        let expiredCount = [activitiesExpired, statsExpired, eventsExpired].filter { $0 }.count
        return Double(3 - expiredCount) / 3.0
    }
}

enum DashboardDataType {
    case activities
    case stats
    case events
}

// MARK: - API Extensions

extension Endpoint {
    static func recentEvents() -> Endpoint {
        Endpoint(path: "/events/recent", method: .GET)
    }
}

