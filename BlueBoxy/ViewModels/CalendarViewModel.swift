//
//  CalendarViewModel.swift
//  BlueBoxy
//
//  Calendar and events management state management
//  Handles calendar providers, event creation, scheduling, and integration
//

import Foundation
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var providers: Loadable<[CalendarProvider]> = .idle
    @Published var events: Loadable<[Event]> = .idle
    @Published var createEventState: Loadable<Event> = .idle
    @Published var updateEventState: Loadable<Event> = .idle
    @Published var deleteEventState: Loadable<Void> = .idle
    @Published var connectionState: Loadable<CalendarConnectionResponse> = .idle
    
    // Event form state
    @Published var eventTitle: String = ""
    @Published var eventDescription: String = ""
    @Published var eventLocation: String = ""
    @Published var eventStartTime: Date = Date()
    @Published var eventEndTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    @Published var isAllDay: Bool = false
    @Published var eventType: String = "date"
    @Published var selectedProvider: String = ""
    
    // Filter and view state
    @Published var selectedDateRange: DateRange = .thisWeek
    @Published var selectedEventTypes: Set<String> = []
    @Published var showPastEvents: Bool = false
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let cachedClient = CachedAPIClient.shared
    private let cache = FileResponseCache()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let maxEventsPerLoad = 100
    private let eventCategories = ["date", "anniversary", "reminder", "activity", "special"]
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        setupFormValidation()
        observeAuthenticationChanges()
        
        // Load initial data
        Task {
            await loadProviders()
        }
    }
    
    // MARK: - Data Loading
    
    /// Load available calendar providers
    func loadProviders() async {
        providers = .loading()
        
        do {
            let response: CalendarProvidersResponse = try await apiClient.request(.calendarProviders())
            providers = .loaded(response.providers)
            
            // Set default provider if none selected
            if selectedProvider.isEmpty, let firstProvider = response.providers.first {
                selectedProvider = firstProvider.id
            }
            return
        } catch {
            providers = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    /// Load events for the selected date range
    func loadEvents(forceRefresh: Bool = false) async {
        events = .loading()
        
        let (startDate, endDate) = selectedDateRange.dateInterval
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let cacheConfig = forceRefresh ? 
            CacheConfiguration(strategy: .networkThenCache, cache: cache, cacheKey: "events_\(selectedDateRange.rawValue)", policy: .default) :
            CacheConfiguration(strategy: .networkFirst, cache: cache, cacheKey: "events_\(selectedDateRange.rawValue)", policy: .default)
        
        let result: Result<EventsResponse, NetworkError> = await cachedClient.getCached(
            .eventsList(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: endDate)
            ),
            configuration: cacheConfig
        )
        
        switch result {
        case .success(let response):
            var filteredEvents = response.events
            
            // Apply event type filters
            if !selectedEventTypes.isEmpty {
                filteredEvents = filteredEvents.filter { event in
                    selectedEventTypes.contains(event.eventType)
                }
            }
            
            // Filter past events if needed
            if !showPastEvents {
                let now = Date()
                filteredEvents = filteredEvents.filter { event in
                    event.endTime > now
                }
            }
            
            events = .loaded(filteredEvents)
            
        case .failure(let error):
            events = .failed(error)
        }
    }
    
    // MARK: - Event Management
    
    /// Create a new event
    func createEvent() async {
        guard isFormValid else {
            createEventState = .failed(.badRequest(message: "Please fill in required fields"))
            return
        }
        
        createEventState = .loading()
        
        let request = CreateEventRequest(
            title: eventTitle,
            description: eventDescription.isEmpty ? nil : eventDescription,
            location: eventLocation.isEmpty ? nil : eventLocation,
            startTime: eventStartTime,
            endTime: eventEndTime,
            allDay: isAllDay,
            eventType: eventType,
            status: "confirmed",
            externalEventId: nil,
            calendarProvider: selectedProvider.isEmpty ? nil : selectedProvider,
            reminders: nil,
            metadata: nil
        )
        
        do {
            let event: Event = try await apiClient.request(.eventsCreate(request))
            createEventState = .loaded(event)
            
            // Clear form on success
            clearForm()
            
            // Refresh events list
            await loadEvents()
            return
        } catch {
            createEventState = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    /// Create a quick event with minimal details
    func quickCreateEvent(title: String, startTime: Date, endTime: Date, type: String = "quick") async -> Bool {
        let request = CreateEventRequest(
            title: title,
            startTime: startTime,
            endTime: endTime,
            eventType: type
        )
        
        do {
            let _: Event = try await apiClient.request(.eventsCreate(request))
            await loadEvents()
            return true
        } catch {
            print("⚠️ Failed to create quick event: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update an existing event
    func updateEvent(_ event: Event) async {
        updateEventState = .loading()
        
        let request = CreateEventRequest(
            title: event.title,
            description: event.description,
            location: event.location,
            startTime: event.startTime,
            endTime: event.endTime,
            allDay: event.allDay,
            eventType: event.eventType,
            status: event.status,
            externalEventId: event.externalEventId,
            calendarProvider: event.calendarProvider,
            reminders: convertToJSONValue(event.reminders),
            metadata: convertMetadataToJSONValue(event.metadata)
        )
        
        do {
            let updatedEvent: Event = try await apiClient.request(.eventsUpdate(id: event.id, request))
            updateEventState = .loaded(updatedEvent)
            await loadEvents()
            return
        } catch {
            updateEventState = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    /// Delete an event
    func deleteEvent(_ eventId: Int) async {
        deleteEventState = .loading()
        
        do {
            let _: DeleteEventResponse = try await apiClient.request(.eventsDelete(id: eventId))
            deleteEventState = .loaded(())
            await loadEvents()
            return
        } catch {
            deleteEventState = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    // MARK: - Calendar Integration
    
    /// Connect to a calendar provider
    func connectToProvider(_ providerId: String) async {
        connectionState = .loading()
        
        do {
            let response: CalendarConnectionResponse = try await apiClient.request(.calendarConnect(providerId: providerId))
            connectionState = .loaded(response)
            
            // Refresh providers to update connection status
            await loadProviders()
            return
        } catch {
            connectionState = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    /// Disconnect from calendar
    func disconnectFromCalendar() async {
        guard let userId = SessionStore.shared.userId else { return }
        
        connectionState = .loading()
        
        let request = CalendarDisconnectRequest(userId: String(userId))
        do {
            let _: CalendarDisconnectResponse = try await apiClient.request(.calendarDisconnect(request))
            connectionState = .loaded(CalendarConnectionResponse(success: true, providerId: "", authUrl: nil))
            await loadProviders()
            return
        } catch {
            connectionState = .failed(ErrorMapper.map(error))
            return
        }
    }
    
    // MARK: - Form Management
    
    /// Clear event creation form
    func clearForm() {
        eventTitle = ""
        eventDescription = ""
        eventLocation = ""
        eventStartTime = Date()
        eventEndTime = Date().addingTimeInterval(3600)
        isAllDay = false
        eventType = "date"
        createEventState = .idle
    }
    
    /// Load event data into form for editing
    func loadEventIntoForm(_ event: Event) {
        eventTitle = event.title
        eventDescription = event.description ?? ""
        eventLocation = event.location ?? ""
        eventStartTime = event.startTime
        eventEndTime = event.endTime
        isAllDay = event.allDay
        eventType = event.eventType
    }
    
    // MARK: - Computed Properties
    
    /// Whether the form is valid for event creation
    var isFormValid: Bool {
        return !eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               eventStartTime < eventEndTime
    }
    
    /// Whether any event operation is in progress
    var isLoading: Bool {
        return createEventState.isLoading || 
               updateEventState.isLoading || 
               deleteEventState.isLoading ||
               events.isLoading
    }
    
    /// Get connected calendar providers
    var connectedProviders: [CalendarProvider] {
        guard let providersData = providers.value else { return [] }
        return providersData.filter { $0.isConnected }
    }
    
    /// Get available calendar providers for connection
    var availableProviders: [CalendarProvider] {
        guard let providersData = providers.value else { return [] }
        return providersData.filter { !$0.isConnected }
    }
    
    /// Get events grouped by date
    var eventsGroupedByDate: [Date: [Event]] {
        guard let eventsData = events.value else { return [:] }
        
        let calendar = Calendar.current
        return Dictionary(grouping: eventsData) { event in
            calendar.startOfDay(for: event.startTime)
        }
    }
    
    /// Get upcoming events (next 7 days)
    var upcomingEvents: [Event] {
        guard let eventsData = events.value else { return [] }
        
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        
        return eventsData
            .filter { $0.startTime >= now && $0.startTime <= nextWeek }
            .sorted { $0.startTime < $1.startTime }
    }
    
    /// Get today's events
    var todaysEvents: [Event] {
        guard let eventsData = events.value else { return [] }
        
        let calendar = Calendar.current
        let today = Date()
        
        return eventsData
            .filter { calendar.isDate($0.startTime, inSameDayAs: today) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    /// Calendar statistics
    var calendarStats: CalendarStats {
        guard let eventsData = events.value else {
            return CalendarStats(totalEvents: 0, upcomingCount: 0, todayCount: 0, eventTypeBreakdown: [:])
        }
        
        var eventTypeBreakdown: [String: Int] = [:]
        for event in eventsData {
            eventTypeBreakdown[event.eventType, default: 0] += 1
        }
        
        return CalendarStats(
            totalEvents: eventsData.count,
            upcomingCount: upcomingEvents.count,
            todayCount: todaysEvents.count,
            eventTypeBreakdown: eventTypeBreakdown
        )
    }
    
    // MARK: - Date Range Management
    
    /// Change selected date range and reload events
    func changeDateRange(to range: DateRange) {
        selectedDateRange = range
        Task {
            await loadEvents()
        }
    }
    
    /// Move to next date range period
    func moveToNextPeriod() {
        selectedDateRange = selectedDateRange.next()
        Task {
            await loadEvents()
        }
    }
    
    /// Move to previous date range period
    func moveToPreviousPeriod() {
        selectedDateRange = selectedDateRange.previous()
        Task {
            await loadEvents()
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupFormValidation() {
        // Ensure end time is always after start time
        $eventStartTime
            .sink { [weak self] startTime in
                if let self = self, self.eventEndTime <= startTime {
                    self.eventEndTime = startTime.addingTimeInterval(3600) // Add 1 hour
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeAuthenticationChanges() {
        // Clear data when user logs out
        NotificationCenter.default
            .publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearAllData()
            }
            .store(in: &cancellables)
        
        // Load data when user logs in
        NotificationCenter.default
            .publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadProviders()
                    await self?.loadEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    private func clearAllData() {
        providers = .idle
        events = .idle
        createEventState = .idle
        updateEventState = .idle
        deleteEventState = .idle
        connectionState = .idle
        clearForm()
    }
    
    // MARK: - JSONValue Conversion Helpers
    
    private func convertToJSONValue(_ strings: [String]) -> JSONValue? {
        return .array(strings.map { .string($0) })
    }
    
    private func convertMetadataToJSONValue(_ metadata: [String: AnyDecodable]?) -> JSONValue? {
        guard let metadata = metadata else { return nil }
        var jsonObject: [String: JSONValue] = [:]
        
        for (key, value) in metadata {
            // Convert AnyDecodable to JSONValue
            if let stringValue = value.value as? String {
                jsonObject[key] = .string(stringValue)
            } else if let intValue = value.value as? Int {
                jsonObject[key] = .int(intValue)
            } else if let doubleValue = value.value as? Double {
                jsonObject[key] = .double(doubleValue)
            } else if let boolValue = value.value as? Bool {
                jsonObject[key] = .bool(boolValue)
            } else {
                // Fallback to string representation
                jsonObject[key] = .string("\(value.value)")
            }
        }
        
        return .object(jsonObject)
    }
}

// MARK: - Date Range

enum DateRange: String, CaseIterable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case nextWeek = "nextWeek"
    case nextMonth = "nextMonth"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .nextWeek: return "Next Week"
        case .nextMonth: return "Next Month"
        }
    }
    
    var dateInterval: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return (start, end)
            
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return (start, end)
            
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
            
        case .nextWeek:
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart) ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return (start, end)
            
        case .nextMonth:
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let start = calendar.date(byAdding: .month, value: 1, to: thisMonthStart) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        }
    }
    
    func next() -> DateRange {
        switch self {
        case .today: return .today // Stay on today for next
        case .thisWeek: return .nextWeek
        case .thisMonth: return .nextMonth
        case .nextWeek: return .thisWeek // Cycle back
        case .nextMonth: return .thisMonth // Cycle back
        }
    }
    
    func previous() -> DateRange {
        switch self {
        case .today: return .today // Stay on today for previous
        case .thisWeek: return .thisWeek // Stay on this week
        case .thisMonth: return .thisMonth // Stay on this month
        case .nextWeek: return .thisWeek
        case .nextMonth: return .thisMonth
        }
    }
}

// MARK: - Calendar Stats

struct CalendarStats {
    let totalEvents: Int
    let upcomingCount: Int
    let todayCount: Int
    let eventTypeBreakdown: [String: Int]
    
    var mostCommonEventType: String? {
        return eventTypeBreakdown.max { $0.value < $1.value }?.key
    }
    
    var averageEventsPerType: Double {
        guard !eventTypeBreakdown.isEmpty else { return 0 }
        let total = eventTypeBreakdown.values.reduce(0, +)
        return Double(total) / Double(eventTypeBreakdown.count)
    }
}

// MARK: - Cache Configuration Extension

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
