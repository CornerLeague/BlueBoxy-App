//
//  CalendarAPIClient.swift
//  BlueBoxy
//
//  Enhanced API client specifically for calendar integration with comprehensive error handling,
//  type-safe requests, authentication management, and loadable state support
//

import Foundation
import Combine

// MARK: - Calendar API Client

@MainActor
class CalendarAPIClient: ObservableObject {
    
    // MARK: - Published State
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var syncStatus: SyncStatus = .idle
    @Published var requestMetrics: RequestMetrics = RequestMetrics()
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let errorMapper: ErrorMapper.Type
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Connection State
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected(providers: [CalendarProvider])
        case error(CalendarAPIError)
        
        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }
        
        var isLoading: Bool {
            return self == .connecting
        }
        
        var connectedProviders: [CalendarProvider] {
            if case .connected(let providers) = self {
                return providers.filter { $0.isConnected }
            }
            return []
        }
    }
    
    // MARK: - Sync Status
    
    enum SyncStatus {
        case idle
        case syncing(progress: Double, message: String)
        case completed(Date, eventCount: Int)
        case failed(CalendarAPIError)
        
        var isActive: Bool {
            if case .syncing = self {
                return true
            }
            return false
        }
    }
    
    // MARK: - Request Metrics
    
    struct RequestMetrics {
        var totalRequests: Int = 0
        var successfulRequests: Int = 0
        var failedRequests: Int = 0
        var averageResponseTime: TimeInterval = 0
        var lastRequestTime: Date?
        
        var successRate: Double {
            return totalRequests > 0 ? Double(successfulRequests) / Double(totalRequests) : 0.0
        }
        
        mutating func recordSuccess(responseTime: TimeInterval) {
            totalRequests += 1
            successfulRequests += 1
            updateAverageResponseTime(responseTime)
            lastRequestTime = Date()
        }
        
        mutating func recordFailure() {
            totalRequests += 1
            failedRequests += 1
            lastRequestTime = Date()
        }
        
        private mutating func updateAverageResponseTime(_ responseTime: TimeInterval) {
            if totalRequests == 1 {
                averageResponseTime = responseTime
            } else {
                averageResponseTime = (averageResponseTime * Double(totalRequests - 1) + responseTime) / Double(totalRequests)
            }
        }
    }
    
    // MARK: - Calendar API Errors
    
    enum CalendarAPIError: LocalizedError {
        case providerNotFound(String)
        case providerAlreadyConnected(String)
        case authenticationFailed(String)
        case syncFailed(String)
        case eventCreationFailed(String)
        case eventUpdateFailed(String)
        case eventDeletionFailed(String)
        case quotaExceeded
        case networkUnavailable
        case underlying(NetworkError)
        
        var errorDescription: String? {
            switch self {
            case .providerNotFound(let provider):
                return "Calendar provider '\(provider)' not found or not available"
            case .providerAlreadyConnected(let provider):
                return "Already connected to '\(provider)'. Please disconnect first."
            case .authenticationFailed(let provider):
                return "Failed to authenticate with '\(provider)'. Please try connecting again."
            case .syncFailed(let message):
                return "Calendar sync failed: \(message)"
            case .eventCreationFailed(let message):
                return "Failed to create event: \(message)"
            case .eventUpdateFailed(let message):
                return "Failed to update event: \(message)"
            case .eventDeletionFailed(let message):
                return "Failed to delete event: \(message)"
            case .quotaExceeded:
                return "API quota exceeded. Please try again later."
            case .networkUnavailable:
                return "Network unavailable. Please check your connection."
            case .underlying(let networkError):
                return networkError.localizedDescription
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .providerNotFound, .providerAlreadyConnected:
                return "Try refreshing the provider list or contact support."
            case .authenticationFailed:
                return "Check your credentials and try reconnecting to the calendar provider."
            case .syncFailed, .eventCreationFailed, .eventUpdateFailed, .eventDeletionFailed:
                return "Please try again. If the problem persists, contact support."
            case .quotaExceeded:
                return "Wait a few minutes before making more requests."
            case .networkUnavailable:
                return "Check your internet connection and try again."
            case .underlying(let networkError):
                return networkError.recoverySuggestion
            }
        }
        
        var isRetryable: Bool {
            switch self {
            case .quotaExceeded, .networkUnavailable, .syncFailed, .eventCreationFailed, .eventUpdateFailed, .eventDeletionFailed:
                return true
            case .providerNotFound, .providerAlreadyConnected, .authenticationFailed:
                return false
            case .underlying(let networkError):
                return networkError.isRetryable
            }
        }
    }
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.errorMapper = ErrorMapper.self
        
        setupMetricsTracking()
    }
    
    // MARK: - Provider Management
    
    /// Fetch available calendar providers
    func fetchProviders() async -> Result<[CalendarProvider], CalendarAPIError> {
        connectionState = .connecting
        
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.request<CalendarProvidersResponse>(.calendarProviders())
        }
        
        switch result {
        case .success(let response):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            
            connectionState = .connected(providers: response.providers)
            return .success(response.providers)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            connectionState = .error(error)
            return .failure(error)
        }
    }
    
    /// Connect to a calendar provider
    func connectProvider(_ providerId: String) async -> Result<CalendarConnectionResponse, CalendarAPIError> {
        // Validate provider exists and is not already connected
        if case .connected(let providers) = connectionState {
            guard providers.contains(where: { $0.id == providerId }) else {
                let error = CalendarAPIError.providerNotFound(providerId)
                return .failure(error)
            }
            
            if providers.contains(where: { $0.id == providerId && $0.isConnected }) {
                let error = CalendarAPIError.providerAlreadyConnected(providerId)
                return .failure(error)
            }
        }
        
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.request<CalendarConnectionResponse>(.calendarConnect(providerId: providerId))
        }
        
        switch result {
        case .success(let response):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            
            // Refresh providers after successful connection
            _ = await fetchProviders()
            
            return .success(response)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(.authenticationFailed(providerId))
        }
    }
    
    /// Disconnect from calendar
    func disconnectProvider(_ userId: String) async -> Result<Void, CalendarAPIError> {
        let startTime = Date()
        let request = CalendarDisconnectRequest(userId: userId)
        
        let result = await executeRequest {
            try await apiClient.requestEmpty(.calendarDisconnect(request))
        }
        
        switch result {
        case .success:
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            
            // Refresh providers after disconnection
            _ = await fetchProviders()
            
            return .success(())
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(error)
        }
    }
    
    // MARK: - Event Management
    
    /// Fetch events from calendar providers
    func fetchEvents(startDate: String, endDate: String) async -> Result<[Event], CalendarAPIError> {
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.request<EventsResponse>(.eventsList(startDate: startDate, endDate: endDate))
        }
        
        switch result {
        case .success(let response):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            return .success(response.events)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(error)
        }
    }
    
    /// Create a new event
    func createEvent(_ request: CreateEventRequest) async -> Result<Event, CalendarAPIError> {
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.request<Event>(.eventsCreate(request))
        }
        
        switch result {
        case .success(let event):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            return .success(event)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(.eventCreationFailed(error.localizedDescription))
        }
    }
    
    /// Update an existing event
    func updateEvent(id: Int, request: CreateEventRequest) async -> Result<Event, CalendarAPIError> {
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.request<Event>(.eventsUpdate(id: id, request))
        }
        
        switch result {
        case .success(let event):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            return .success(event)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(.eventUpdateFailed(error.localizedDescription))
        }
    }
    
    /// Delete an event
    func deleteEvent(id: Int) async -> Result<Void, CalendarAPIError> {
        let startTime = Date()
        let result = await executeRequest {
            try await apiClient.requestEmpty(.eventsDelete(id: id))
        }
        
        switch result {
        case .success:
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            return .success(())
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(.eventDeletionFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Sync Operations
    
    /// Sync events from connected providers
    func syncEvents(providerId: String? = nil) async -> Result<SyncResult, CalendarAPIError> {
        syncStatus = .syncing(progress: 0.1, message: "Starting sync...")
        
        let providers = connectionState.connectedProviders
        let providersToSync = providerId != nil ? providers.filter { $0.id == providerId } : providers
        
        guard !providersToSync.isEmpty else {
            let error = CalendarAPIError.syncFailed("No connected providers found")
            syncStatus = .failed(error)
            return .failure(error)
        }
        
        var totalEvents = 0
        var syncedProviders = 0
        
        for (index, provider) in providersToSync.enumerated() {
            let progress = 0.1 + (Double(index) / Double(providersToSync.count)) * 0.8
            syncStatus = .syncing(progress: progress, message: "Syncing \(provider.displayName)...")
            
            // Sync individual provider
            let result = await syncProvider(provider)
            
            switch result {
            case .success(let eventCount):
                totalEvents += eventCount
                syncedProviders += 1
                
            case .failure(let error):
                syncStatus = .failed(error)
                return .failure(error)
            }
        }
        
        let syncResult = SyncResult(
            syncedProviders: syncedProviders,
            totalEvents: totalEvents,
            syncTime: Date()
        )
        
        syncStatus = .completed(Date(), eventCount: totalEvents)
        return .success(syncResult)
    }
    
    // MARK: - Private Methods
    
    private func executeRequest<T>(_ operation: @escaping () async throws -> T) async -> Result<T, CalendarAPIError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            let mappedError = mapError(error)
            return .failure(mappedError)
        }
    }
    
    private func mapError(_ error: Error) -> CalendarAPIError {
        // First map to NetworkError using existing mapper
        let networkError = errorMapper.map(error)
        
        // Then map NetworkError to CalendarAPIError
        switch networkError {
        case .connectivity:
            return .networkUnavailable
        case .rateLimited:
            return .quotaExceeded
        case .unauthorized, .forbidden:
            return .authenticationFailed("Authentication required")
        case .notFound:
            return .providerNotFound("Resource not found")
        default:
            return .underlying(networkError)
        }
    }
    
    private func syncProvider(_ provider: CalendarProvider) async -> Result<Int, CalendarAPIError> {
        let startTime = Date()
        
        // Calculate date range (last 30 days to next 365 days)
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let endDate = calendar.date(byAdding: .day, value: 365, to: now) ?? now
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let result = await executeRequest {
            try await apiClient.request<CalendarEventsResponse>(.calendarEvents(
                providerId: provider.id,
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            ))
        }
        
        switch result {
        case .success(let response):
            let responseTime = Date().timeIntervalSince(startTime)
            requestMetrics.recordSuccess(responseTime: responseTime)
            return .success(response.events.count)
            
        case .failure(let error):
            requestMetrics.recordFailure()
            return .failure(.syncFailed("Failed to sync \(provider.displayName): \(error.localizedDescription)"))
        }
    }
    
    private func setupMetricsTracking() {
        // Reset metrics daily
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                self.requestMetrics = RequestMetrics()
            }
        }
    }
}

// MARK: - Supporting Types

struct SyncResult {
    let syncedProviders: Int
    let totalEvents: Int
    let syncTime: Date
    
    var summary: String {
        return "Synced \(totalEvents) events from \(syncedProviders) provider\(syncedProviders == 1 ? "" : "s")"
    }
}

// MARK: - Loadable State Extension

extension CalendarAPIClient {
    
    /// Execute a request and return a Loadable result
    func loadable<T>(_ operation: @escaping () async -> Result<T, CalendarAPIError>) -> AnyPublisher<Loadable<T>, Never> {
        return Future { promise in
            Task {
                let result = await operation()
                
                switch result {
                case .success(let value):
                    promise(.success(.loaded(value)))
                case .failure(let error):
                    let networkError = self.errorMapper.map(error)
                    promise(.success(.failed(networkError)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Convenience method for provider loading
    var providersLoadable: AnyPublisher<Loadable<[CalendarProvider]>, Never> {
        return loadable {
            await self.fetchProviders()
        }
    }
    
    /// Convenience method for events loading
    func eventsLoadable(startDate: String, endDate: String) -> AnyPublisher<Loadable<[Event]>, Never> {
        return loadable {
            await self.fetchEvents(startDate: startDate, endDate: endDate)
        }
    }
}

// MARK: - Request Retry Logic

extension CalendarAPIClient {
    
    /// Execute request with automatic retry logic
    func executeWithRetry<T>(
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async -> Result<T, CalendarAPIError>
    ) async -> Result<T, CalendarAPIError> {
        
        var lastError: CalendarAPIError?
        
        for attempt in 0...maxRetries {
            let result = await operation()
            
            switch result {
            case .success(let value):
                return .success(value)
                
            case .failure(let error):
                lastError = error
                
                // Don't retry on certain errors
                if !error.isRetryable || attempt == maxRetries {
                    return .failure(error)
                }
                
                // Exponential backoff
                let retryDelay = delay * pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        return .failure(lastError ?? .networkUnavailable)
    }
}

// MARK: - Calendar API Client Extensions

extension CalendarAPIClient {
    
    /// Check if any providers are connected
    var hasConnectedProviders: Bool {
        return !connectionState.connectedProviders.isEmpty
    }
    
    /// Get connection status summary
    var connectionSummary: String {
        let connectedCount = connectionState.connectedProviders.count
        if connectedCount == 0 {
            return "No calendar providers connected"
        } else {
            return "\(connectedCount) calendar provider\(connectedCount == 1 ? "" : "s") connected"
        }
    }
    
    /// Get performance summary
    var performanceSummary: String {
        let metrics = requestMetrics
        if metrics.totalRequests == 0 {
            return "No requests made"
        } else {
            let successRate = Int(metrics.successRate * 100)
            let avgTime = Int(metrics.averageResponseTime * 1000)
            return "\(metrics.totalRequests) requests, \(successRate)% success, avg \(avgTime)ms"
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension CalendarAPIClient {
    
    /// Test all calendar API endpoints
    func testAllEndpoints() async {
        print("🧪 Testing Calendar API endpoints...")
        
        // Test provider fetching
        let providersResult = await fetchProviders()
        print("📋 Providers: \(providersResult)")
        
        // Test event fetching (if providers are connected)
        if hasConnectedProviders {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            let now = Date()
            let startDate = formatter.string(from: now)
            let endDate = formatter.string(from: Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
            
            let eventsResult = await fetchEvents(startDate: startDate, endDate: endDate)
            print("📅 Events: \(eventsResult)")
        }
        
        print("📊 Performance: \(performanceSummary)")
        print("🔗 Connection: \(connectionSummary)")
    }
}
#endif
