//
//  FixtureLoader.swift
//  BlueBoxy
//
//  Universal fixture loader for both app previews and tests
//  Loads JSON fixtures from Resources/Fixtures directory
//

import Foundation

/// Universal fixture loader that works in both app and test contexts
final class FixtureLoader {
    
    /// Load and decode a fixture from the Resources/Fixtures directory
    /// - Parameters:
    ///   - name: The fixture name (without .json extension)
    ///   - type: The type to decode to
    /// - Returns: Decoded model instance
    /// - Throws: Decoding or file loading errors
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        let bundle = Bundle.main
        
        // Try to find the fixture file
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.fileNotFound(name)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FixtureError.decodingFailed(name, error)
        }
    }
    
    /// Load raw JSON data from fixture (for custom processing)
    /// - Parameter name: The fixture name (without .json extension)
    /// - Returns: Raw JSON data
    /// - Throws: File loading errors
    static func loadData(_ name: String) throws -> Data {
        let bundle = Bundle.main
        
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.fileNotFound(name)
        }
        
        return try Data(contentsOf: url)
    }
    
    /// Load and parse JSON as dictionary (for dynamic processing)
    /// - Parameter name: The fixture name (without .json extension)
    /// - Returns: JSON dictionary
    /// - Throws: File loading or JSON parsing errors
    static func loadJSON(_ name: String) throws -> [String: Any] {
        let data = try loadData(name)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FixtureError.invalidJSON(name)
        }
        
        return json
    }
}

// MARK: - Fixture Error Types

enum FixtureError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String, Error)
    case invalidJSON(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Fixture file not found: \(name).json"
        case .decodingFailed(let name, let error):
            return "Failed to decode fixture \(name).json: \(error.localizedDescription)"
        case .invalidJSON(let name):
            return "Invalid JSON in fixture: \(name).json"
        }
    }
}

// MARK: - Convenience Methods for Common Fixtures

extension FixtureLoader {
    
    // MARK: - Auth Fixtures
    
    static func loadAuthMe() throws -> AuthEnvelope {
        return try load("Resources/Fixtures/auth/me_success", as: AuthEnvelope.self)
    }
    
    // MARK: - Message Fixtures
    
    static func loadMessageGeneration() throws -> MessageGenerationResponse {
        return try load("Resources/Fixtures/messages/generate_success", as: MessageGenerationResponse.self)
    }
    
    // MARK: - Activity Fixtures
    
    static func loadActivitiesList() throws -> [Activity] {
        return try load("Resources/Fixtures/activities/activities_list_success", as: [Activity].self)
    }
    
    // MARK: - Assessment Fixtures
    
    static func loadAssessmentSave() throws -> AssessmentSavedResponse {
        return try load("Resources/Fixtures/assessment/save_success", as: AssessmentSavedResponse.self)
    }
    
    // MARK: - Recommendation Fixtures
    
    static func loadSimpleRecommendations() throws -> [SimpleRecommendation] {
        return try load("Resources/Fixtures/recommendations/activities_success", as: [SimpleRecommendation].self)
    }
    
    static func loadLocationPostRecommendations() throws -> GrokLocationPostResponse {
        return try load("Resources/Fixtures/recommendations/location_post_success", as: GrokLocationPostResponse.self)
    }
    
    static func loadRecommendationCategories() throws -> RecommendationCategoriesResponse {
        return try load("Resources/Fixtures/recommendations/categories_success", as: RecommendationCategoriesResponse.self)
    }
    
    static func loadAIPoweredRecommendations() throws -> AIPoweredRecommendationsResponse {
        return try load("Resources/Fixtures/recommendations/ai_powered_success", as: AIPoweredRecommendationsResponse.self)
    }
    
    // MARK: - Event Fixtures
    
    static func loadEventCreate() throws -> CalendarEventDB {
        return try load("Resources/Fixtures/events/create_success", as: CalendarEventDB.self)
    }
    
    static func loadEventsList() throws -> [CalendarEventDB] {
        return try load("Resources/Fixtures/events/events_list_success", as: [CalendarEventDB].self)
    }
    
    // MARK: - User Stats Fixtures
    
    static func loadUserStats() throws -> UserStatsResponse {
        return try load("Resources/Fixtures/user/stats_success", as: UserStatsResponse.self)
    }
    
    // MARK: - Calendar Provider Fixtures
    
    static func loadCalendarProviders() throws -> [CalendarProvider] {
        return try load("Resources/Fixtures/calendar/providers_success", as: [CalendarProvider].self)
    }
}