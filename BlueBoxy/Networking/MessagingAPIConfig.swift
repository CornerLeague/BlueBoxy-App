//
//  MessagingAPIConfig.swift
//  BlueBoxy
//
//  Messaging-specific API configuration that extends the base APIConfiguration
//  with message generation endpoints and authentication headers
//

import Foundation

// MARK: - Messaging API Configuration

extension APIConfiguration {
    
    /// Messaging-specific endpoints
    enum MessagingEndpoints {
        static let categories = "/api/messages/categories"
        static let generate = "/api/messages/generate"
        static let history = "/api/messages/history"
        static let save = "/api/messages/{messageId}/save"
        static let delete = "/api/messages/{messageId}"
        static let favorite = "/api/messages/{messageId}/favorite"
    }
    
    /// Headers for messaging API requests (based on implementation guide requirements)
    static func messagingHeaders(for userId: Int) -> [String: String] {
        var headers = defaultHeaders
        headers["x-user-id"] = String(userId)
        return headers
    }
    
    /// Headers for messaging API requests with authentication
    static func messagingHeadersWithAuth(for userId: Int, authToken: String) -> [String: String] {
        var headers = messagingHeaders(for: userId)
        headers["Authorization"] = "Bearer \(authToken)"
        return headers
    }
    
    /// Messaging-specific timeout configuration for AI generation
    static var messagingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // Extended timeouts for AI message generation
        configuration.timeoutIntervalForRequest = 45 // seconds (longer for AI processing)
        configuration.timeoutIntervalForResource = 120 // seconds
        
        // Network behavior
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Cache policy - fresh data for messaging
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        return URLSession(configuration: configuration)
    }()
}

// MARK: - Messaging Request Headers Helper

struct MessagingHeaders {
    
    /// Generate headers for message API calls
    static func forUser(_ userId: Int) -> [String: String] {
        return APIConfiguration.messagingHeaders(for: userId)
    }
    
    /// Generate headers for authenticated message API calls
    static func forAuthenticatedUser(_ userId: Int, token: String) -> [String: String] {
        return APIConfiguration.messagingHeadersWithAuth(for: userId, authToken: token)
    }
    
    /// Generate headers with additional context
    static func forUserWithContext(_ userId: Int, timeOfDay: TimeOfDay? = nil, personalityType: String? = nil) -> [String: String] {
        var headers = APIConfiguration.messagingHeaders(for: userId)
        
        if let timeOfDay = timeOfDay {
            headers["x-time-of-day"] = timeOfDay.rawValue
        }
        
        if let personalityType = personalityType {
            headers["x-personality-type"] = personalityType
        }
        
        return headers
    }
}

// MARK: - Enhanced Endpoint Extensions

extension Endpoint {
    
    /// Create messaging endpoint with user ID in headers
    static func messagingEndpoint(
        path: String,
        method: HTTPMethod,
        userId: Int,
        body: Encodable? = nil,
        query: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) -> Endpoint {
        return Endpoint(
            path: path,
            method: method,
            query: query,
            headers: MessagingHeaders.forUser(userId),
            body: body,
            requiresUser: true,
            requiresAuth: requiresAuth
        )
    }
    
    /// Create messaging endpoint with full authentication
    static func authenticatedMessagingEndpoint(
        path: String,
        method: HTTPMethod,
        userId: Int,
        authToken: String,
        body: Encodable? = nil,
        query: [URLQueryItem]? = nil
    ) -> Endpoint {
        return Endpoint(
            path: path,
            method: method,
            query: query,
            headers: MessagingHeaders.forAuthenticatedUser(userId, token: authToken),
            body: body,
            requiresUser: true,
            requiresAuth: true
        )
    }
}