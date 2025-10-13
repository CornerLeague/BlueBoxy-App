//
//  BlueBoxyAPIService.swift
//  BlueBoxy
//
//  Service layer demonstrating how to use APIClient with endpoints
//  Provides high-level methods for common operations
//

import Foundation

final class BlueBoxyAPIService {
    static let shared = BlueBoxyAPIService()
    
    private let client: APIClient
    
    init(client: APIClient = APIClient.shared) {
        self.client = client
    }
    
    // MARK: - Authentication Services
    
    /// Register a new user account
    func register(email: String, password: String, name: String? = nil, 
                 partnerName: String? = nil, relationshipDuration: String? = nil,
                 partnerAge: Int? = nil) async throws -> BasicUserResponse {
        let request = RegisterRequest(
            email: email,
            password: password,
            name: name,
            partnerName: partnerName,
            relationshipDuration: relationshipDuration,
            partnerAge: partnerAge
        )
        return try await client.request(Endpoint.authRegister(request))
    }
    
    /// Login existing user
    func login(email: String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(email: email, password: password)
        return try await client.request(Endpoint.authLogin(request))
    }
    
    /// Get current user info
    func getCurrentUser() async throws -> BasicUserResponse {
        return try await client.request(Endpoint.authMe())
    }
    
    /// Logout current user
    func logout() async throws {
        try await client.requestEmpty(Endpoint.authLogout())
    }
    
    // MARK: - Assessment Services
    
    /// Submit assessment responses for authenticated user
    func submitAssessment(responses: [String: String], personalityType: String? = nil) async throws -> AssessmentResult {
        let request = AssessmentResponsesRequest(responses: responses, personalityType: personalityType)
        return try await client.request(Endpoint.assessmentSubmit(request))
    }
    
    /// Submit guest assessment (no authentication required)
    func submitGuestAssessment(responses: [String: String], personalityType: String,
                              onboardingData: JSONValue? = nil) async throws -> AssessmentResult {
        let request = GuestAssessmentRequest(
            responses: responses,
            personalityType: personalityType,
            onboardingData: onboardingData
        )
        return try await client.request(Endpoint.assessmentGuest(request))
    }
    
    /// Get assessment results
    func getAssessmentResults() async throws -> AssessmentResult {
        return try await client.request(Endpoint.assessmentResults())
    }
    
    // MARK: - Activities Services
    
    /// Get list of available activities
    func getActivities() async throws -> ActivitiesResponse {
        return try await client.request(Endpoint.activitiesList())
    }
    
    /// Get specific activity details
    func getActivity(id: Int) async throws -> Activity {
        return try await client.request(Endpoint.activitiesDetail(id: id))
    }
    
    // MARK: - Messages Services
    
    /// Generate personalized message
    func generateMessage(category: String, timeOfDay: TimeOfDay? = nil,
                        recentContext: String? = nil, specialOccasion: String? = nil) async throws -> MessageResponse {
        let request = MessageGenerateRequest(
            category: category,
            timeOfDay: timeOfDay,
            recentContext: recentContext,
            specialOccasion: specialOccasion
        )
        return try await client.request(Endpoint.messagesGenerate(request))
    }
    
    /// Get message history
    func getMessageHistory(limit: Int = 50, offset: Int = 0) async throws -> MessageHistoryResponse {
        return try await client.request(Endpoint.messagesHistory(limit: limit, offset: offset))
    }
    
    /// Save a generated message
    func saveMessage(messageId: String) async throws {
        try await client.requestEmpty(Endpoint.messagesSave(messageId: messageId))
    }
    
    // MARK: - Events Services
    
    /// Create a new event
    func createEvent(_ request: CreateEventRequest) async throws -> Event {
        return try await client.request(Endpoint.eventsCreate(request))
    }
    
    /// Get user's events within date range
    func getEvents(startDate: String? = nil, endDate: String? = nil) async throws -> EventsResponse {
        return try await client.request(Endpoint.eventsList(startDate: startDate, endDate: endDate))
    }
    
    /// Get specific event
    func getEvent(id: Int) async throws -> Event {
        return try await client.request(Endpoint.eventsDetail(id: id))
    }
    
    /// Update existing event
    func updateEvent(id: Int, _ request: CreateEventRequest) async throws -> Event {
        return try await client.request(Endpoint.eventsUpdate(id: id, request))
    }
    
    /// Delete event
    func deleteEvent(id: Int) async throws {
        try await client.requestEmpty(Endpoint.eventsDelete(id: id))
    }
    
    // MARK: - Recommendations Services
    
    /// Get activity recommendations
    func getActivityRecommendations() async throws -> RecommendationsResponse {
        return try await client.request(Endpoint.recommendationsActivities())
    }
    
    /// Get location-based recommendations
    func getLocationRecommendations(radius: Int, category: String? = nil) async throws -> RecommendationsResponse {
        return try await client.request(Endpoint.recommendationsLocationGET(radius: radius, category: category))
    }
    
    /// Get detailed location-based recommendations with filters
    func getLocationRecommendations(_ request: LocationBasedPostRequest) async throws -> RecommendationsResponse {
        return try await client.request(Endpoint.recommendationsLocationPOST(request))
    }
    
    /// Get drinks recommendations
    func getDrinksRecommendations(_ request: DrinksRecommendationsRequest) async throws -> RecommendationsResponse {
        return try await client.request(Endpoint.recommendationsDrinks(request))
    }
    
    /// Get AI-powered recommendations
    func getAIRecommendations(_ request: AIPoweredRecommendationsRequest) async throws -> RecommendationsResponse {
        return try await client.request(Endpoint.recommendationsAIPowered(request))
    }
    
    /// Refresh recommendations algorithm
    func refreshRecommendations() async throws {
        try await client.requestEmpty(Endpoint.recommendationsRefresh())
    }
    
    // MARK: - Preferences Services
    
    /// Save user preferences
    func savePreferences(_ request: SavePreferencesRequest) async throws -> PreferencesResponse {
        return try await client.request(Endpoint.preferencesSet(request))
    }
    
    /// Update user preferences
    func updatePreferences(_ request: UpdatePreferencesRequest) async throws -> PreferencesResponse {
        return try await client.request(Endpoint.preferencesUpdate(request))
    }
    
    /// Get user preferences
    func getPreferences() async throws -> PreferencesResponse {
        return try await client.request(Endpoint.preferencesGet())
    }
    
    /// Delete user preferences
    func deletePreferences() async throws {
        try await client.requestEmpty(Endpoint.preferencesDelete())
    }
    
    // MARK: - User Stats Services
    
    /// Get user statistics
    func getUserStats() async throws -> UserStatsResponse {
        return try await client.request(Endpoint.userStats())
    }
    
    /// Get user activity summary
    func getUserActivitySummary(days: Int = 30) async throws -> ActivitySummaryResponse {
        return try await client.request(Endpoint.userActivitySummary(days: days))
    }
    
    // MARK: - Calendar Services
    
    /// Get available calendar providers
    func getCalendarProviders() async throws -> CalendarProvidersResponse {
        return try await client.request(Endpoint.calendarProviders())
    }
    
    /// Connect to calendar provider
    func connectCalendar(providerId: String) async throws -> CalendarConnectionResponse {
        return try await client.request(Endpoint.calendarConnect(providerId: providerId))
    }
    
    /// Disconnect from calendar
    func disconnectCalendar(userId: String) async throws {
        let request = CalendarDisconnectRequest(userId: userId)
        try await client.requestEmpty(Endpoint.calendarDisconnect(request))
    }
    
    /// Get calendar events
    func getCalendarEvents(providerId: String, startDate: String, endDate: String) async throws -> CalendarEventsResponse {
        return try await client.request(Endpoint.calendarEvents(providerId: providerId, startDate: startDate, endDate: endDate))
    }
    
    /// Sync calendar events
    func syncCalendar(providerId: String) async throws -> CalendarSyncResponse {
        return try await client.request(Endpoint.calendarSync(providerId: providerId))
    }
    
    /// Get calendar connection status
    func getCalendarStatus() async throws -> CalendarStatusResponse {
        return try await client.request(Endpoint.calendarStatus())
    }
    
    // MARK: - User Profile Services
    
    /// Get user profile
    func getUserProfile() async throws -> UserProfileResponse {
        return try await client.request(Endpoint.userProfile())
    }
    
    /// Update user profile
    func updateUserProfile(_ request: UpdateProfileRequest) async throws -> UserProfileResponse {
        return try await client.request(Endpoint.userProfileUpdate(request))
    }
    
    /// Delete user account
    func deleteUser() async throws {
        try await client.requestEmpty(Endpoint.userDelete())
    }
}

// MARK: - Convenience Extensions

extension BlueBoxyAPIService {
    
    /// Quick login with validation
    func quickLogin(email: String, password: String) async throws -> AuthResponse {
        guard !email.isEmpty, !password.isEmpty else {
            throw APIServiceError.badRequest(message: "Email and password are required")
        }
        
        return try await login(email: email, password: password)
    }
    
    /// Create simple event with validation
    func createSimpleEvent(title: String, startTime: Date, endTime: Date, location: String? = nil) async throws -> Event {
        guard !title.isEmpty else {
            throw APIServiceError.badRequest(message: "Event title is required")
        }
        
        guard startTime < endTime else {
            throw APIServiceError.badRequest(message: "Start time must be before end time")
        }
        
        let request = CreateEventRequest(
            title: title,
            location: location,
            startTime: startTime,
            endTime: endTime,
            eventType: "date"
        )
        
        return try await createEvent(request)
    }
    
    /// Get nearby recommendations with current location
    func getNearbyRecommendations(latitude: Double, longitude: Double, 
                                radius: Int = 5, category: String = "dining") async throws -> RecommendationsResponse {
        let request = LocationBasedPostRequest(
            latitude: latitude,
            longitude: longitude,
            category: category,
            radiusInMiles: radius
        )
        
        return try await getLocationRecommendations(request)
    }
}

// MARK: - Response Model Placeholders

/// Response models - these should match your backend API responses
struct AuthResponse: Codable {
    let token: String
    let user: BasicUserResponse
    let expiresIn: Int
}

// UserResponse is defined as typealias in Core/Models/User.swift

struct MessageResponse: Codable {
    let id: String
    let content: String
    let category: String
    let generatedAt: Date
}

// MessageHistoryResponse is defined in Models/MessagingModels.swift


// Using UserStatsResponse from Core/Models/BackendModels.swift

struct ActivitySummaryResponse: Codable {
    let period: String
    let eventsCreated: Int
    let messagesGenerated: Int
    let recommendationsUsed: Int
}


// CalendarEventsResponse, CalendarSyncResponse, and CalendarStatusResponse are defined in Core/Models/BackendModels.swift
// CalendarEvent is defined as ExternalCalendarEvent in BackendModels.swift

struct UserProfileResponse: Codable {
    let id: Int
    let email: String
    let name: String?
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    let createdAt: Date
    let updatedAt: Date
}