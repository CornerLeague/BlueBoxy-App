//
//  Endpoints.swift
//  BlueBoxy
//
//  Endpoint factory methods for all API routes to centralize paths,
//  methods, and authentication requirements
//

import Foundation

extension Endpoint {
    
    // MARK: - Authentication Endpoints
    
    /// Register new user account
    static func authRegister(_ body: RegisterRequest) -> Endpoint {
        Endpoint(
            path: "/api/auth/register",
            method: .POST,
            body: body
        )
    }
    
    /// Login existing user
    static func authLogin(_ body: LoginRequest) -> Endpoint {
        Endpoint(
            path: "/api/auth/login",
            method: .POST,
            body: body
        )
    }
    
    /// Get current user information
    static func authMe() -> Endpoint {
        Endpoint(
            path: "/api/auth/me",
            method: .GET,
            requiresAuth: true
        )
    }
    
    /// Refresh authentication token
    static func authRefresh() -> Endpoint {
        Endpoint(
            path: "/api/auth/refresh",
            method: .POST,
            requiresAuth: true
        )
    }
    
    /// Logout current user
    static func authLogout() -> Endpoint {
        Endpoint(
            path: "/api/auth/logout",
            method: .POST,
            requiresAuth: true
        )
    }
    
    // MARK: - Activities Endpoints (Public)
    
    /// Get list of available activities
    static func activitiesList() -> Endpoint {
        Endpoint(
            path: "/api/activities",
            method: .GET
        )
    }
    
    /// Get specific activity by ID
    static func activitiesDetail(id: Int) -> Endpoint {
        Endpoint(
            path: "/api/activities/\(id)",
            method: .GET
        )
    }
    
    // MARK: - Assessment Endpoints
    
    /// Submit assessment responses for authenticated user
    static func assessmentSubmit(_ body: AssessmentResponsesRequest) -> Endpoint {
        Endpoint(
            path: "/api/assessment/submit",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Submit guest assessment (no auth required)
    static func assessmentGuest(_ body: GuestAssessmentRequest) -> Endpoint {
        Endpoint(
            path: "/api/assessment/guest",
            method: .POST,
            body: body
        )
    }
    
    /// Get assessment results
    static func assessmentResults() -> Endpoint {
        Endpoint(
            path: "/api/assessment/results",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - Messages Endpoints
    
    /// Get message categories (public endpoint)
    static func messagesCategories() -> Endpoint {
        Endpoint(
            path: "/api/messages/categories",
            method: .GET
        )
    }
    
    /// Generate personalized message with enhanced request
    static func messagesGenerate(_ body: MessageGenerateRequest) -> Endpoint {
        Endpoint(
            path: "/api/messages/generate",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Generate messages with enhanced request model
    static func messagesGenerateEnhanced(_ body: EnhancedMessageGenerateRequest) -> Endpoint {
        Endpoint(
            path: "/api/messages/generate",
            method: .POST,
            headers: ["x-user-id": String(body.userId)],
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get message history
    static func messagesHistory(limit: Int = 50, offset: Int = 0) -> Endpoint {
        Endpoint(
            path: "/api/messages/history",
            method: .GET,
            query: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ],
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Save generated message
    static func messagesSave(messageId: String) -> Endpoint {
        Endpoint(
            path: "/api/messages/\(messageId)/save",
            method: .POST,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Delete message from history
    static func messagesDelete(messageId: String) -> Endpoint {
        Endpoint(
            path: "/api/messages/\(messageId)",
            method: .DELETE,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Mark message as favorite
    static func messagesFavorite(messageId: String) -> Endpoint {
        Endpoint(
            path: "/api/messages/\(messageId)/favorite",
            method: .POST,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - Events Endpoints
    
    /// Create new event
    static func eventsCreate(_ body: CreateEventRequest) -> Endpoint {
        Endpoint(
            path: "/api/events",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get user's events
    static func eventsList(startDate: String? = nil, endDate: String? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        
        if let start = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: start))
        }
        if let end = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: end))
        }
        
        return Endpoint(
            path: "/api/events",
            method: .GET,
            query: queryItems.isEmpty ? nil : queryItems,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get specific event by ID
    static func eventsDetail(id: Int) -> Endpoint {
        Endpoint(
            path: "/api/events/\(id)",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Update existing event
    static func eventsUpdate(id: Int, _ body: CreateEventRequest) -> Endpoint {
        Endpoint(
            path: "/api/events/\(id)",
            method: .PUT,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Delete event
    static func eventsDelete(id: Int) -> Endpoint {
        Endpoint(
            path: "/api/events/\(id)",
            method: .DELETE,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - Recommendations Endpoints
    
    /// Get activity recommendations
    static func recommendationsActivities() -> Endpoint {
        Endpoint(
            path: "/api/recommendations/activities",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get location-based recommendations (GET with query params)
    static func recommendationsLocationGET(radius: Int, category: String? = nil) -> Endpoint {
        var queryItems = [URLQueryItem(name: "radius", value: String(radius))]
        
        if let cat = category {
            queryItems.append(URLQueryItem(name: "category", value: cat))
        }
        
        return Endpoint(
            path: "/api/recommendations/location-based",
            method: .GET,
            query: queryItems,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get location-based recommendations (POST with body)
    static func recommendationsLocationPOST(_ body: LocationBasedPostRequest) -> Endpoint {
        Endpoint(
            path: "/api/recommendations/location-based",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get drinks recommendations
    static func recommendationsDrinks(_ body: DrinksRecommendationsRequest) -> Endpoint {
        Endpoint(
            path: "/api/recommendations/drinks",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get AI-powered recommendations
    static func recommendationsAIPowered(_ body: AIPoweredRecommendationsRequest) -> Endpoint {
        Endpoint(
            path: "/api/recommendations/ai-powered",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Refresh recommendations algorithm
    static func recommendationsRefresh() -> Endpoint {
        Endpoint(
            path: "/api/recommendations/refresh",
            method: .POST,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - User Preferences Endpoints
    
    /// Save user preferences
    static func preferencesSet(_ body: SavePreferencesRequest) -> Endpoint {
        Endpoint(
            path: "/api/user/preferences",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Update user preferences
    static func preferencesUpdate(_ body: UpdatePreferencesRequest) -> Endpoint {
        Endpoint(
            path: "/api/user/preferences",
            method: .PUT,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get user preferences
    static func preferencesGet() -> Endpoint {
        Endpoint(
            path: "/api/user/preferences",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Delete user preferences
    static func preferencesDelete() -> Endpoint {
        Endpoint(
            path: "/api/user/preferences",
            method: .DELETE,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - User Stats Endpoints
    
    /// Get user statistics (server ignores path param, uses authenticated user)
    static func userStats() -> Endpoint {
        Endpoint(
            path: "/api/user/stats/0", // Path param ignored by server
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get user activity summary
    static func userActivitySummary(days: Int = 30) -> Endpoint {
        Endpoint(
            path: "/api/user/activity-summary",
            method: .GET,
            query: [URLQueryItem(name: "days", value: String(days))],
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - Calendar Integration Endpoints
    
    /// Get available calendar providers
    static func calendarProviders() -> Endpoint {
        Endpoint(
            path: "/api/calendar/providers",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Connect to calendar provider
    static func calendarConnect(providerId: String) -> Endpoint {
        Endpoint(
            path: "/api/calendar/connect/\(providerId)",
            method: .POST,
            body: Empty(),
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Disconnect from calendar
    static func calendarDisconnect(_ body: CalendarDisconnectRequest) -> Endpoint {
        Endpoint(
            path: "/api/calendar/disconnect",
            method: .POST,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get calendar events
    static func calendarEvents(providerId: String, startDate: String, endDate: String) -> Endpoint {
        Endpoint(
            path: "/api/calendar/events/\(providerId)",
            method: .GET,
            query: [
                URLQueryItem(name: "startDate", value: startDate),
                URLQueryItem(name: "endDate", value: endDate)
            ],
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Sync calendar events
    static func calendarSync(providerId: String) -> Endpoint {
        Endpoint(
            path: "/api/calendar/sync/\(providerId)",
            method: .POST,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Get calendar connection status
    static func calendarStatus() -> Endpoint {
        Endpoint(
            path: "/api/calendar/status",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    // MARK: - User Profile Endpoints
    
    /// Get user profile
    static func userProfile() -> Endpoint {
        Endpoint(
            path: "/api/user/profile",
            method: .GET,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Update user profile
    static func userProfileUpdate(_ body: UpdateProfileRequest) -> Endpoint {
        Endpoint(
            path: "/api/user/profile",
            method: .PUT,
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
    
    /// Delete user account
    static func userDelete() -> Endpoint {
        Endpoint(
            path: "/api/user/delete",
            method: .DELETE,
            requiresUser: true,
            requiresAuth: true
        )
    }
}

// MARK: - Convenience Extensions

extension Endpoint {
    
    /// Create endpoint with custom headers
    static func withHeaders(_ endpoint: Endpoint, headers: [String: String]) -> Endpoint {
        var newHeaders = endpoint.headers ?? [:]
        headers.forEach { key, value in
            newHeaders[key] = value
        }
        
        return Endpoint(
            path: endpoint.path,
            method: endpoint.method,
            query: endpoint.query,
            headers: newHeaders,
            body: endpoint.body,
            requiresUser: endpoint.requiresUser,
            requiresAuth: endpoint.requiresAuth
        )
    }
    
    /// Create endpoint with additional query parameters
    static func withQuery(_ endpoint: Endpoint, query: [URLQueryItem]) -> Endpoint {
        let existingQuery = endpoint.query ?? []
        let combinedQuery = existingQuery + query
        
        return Endpoint(
            path: endpoint.path,
            method: endpoint.method,
            query: combinedQuery,
            headers: endpoint.headers,
            body: endpoint.body,
            requiresUser: endpoint.requiresUser,
            requiresAuth: endpoint.requiresAuth
        )
    }
}

// MARK: - Request Models
// Using UpdateProfileRequest from Core/Models/AuthModels.swift
