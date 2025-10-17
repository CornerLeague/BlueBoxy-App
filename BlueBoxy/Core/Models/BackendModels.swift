//
//  BackendModels.swift
//  BlueBoxy
//
//  Swift models (Codable) aligned to backend responses
//  Uses JSONValue for heterogenous JSON blobs (preferences, location, metadata)
//  Dates are ISO-8601 strings; JSONDecoder.dateDecodingStrategy = .iso8601 applies when properties are Date
//

import Foundation

// MARK: - Flexible JSON value for heterogenous blobs (preferences, location, metadata)
enum JSONValue: Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)   { self = .bool(v); return }
        if let v = try? c.decode(Int.self)    { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - Error envelopes
// APIErrorEnvelope and SimpleErrorEnvelope are defined in Core/Networking/APIError.swift and Networking/APIClient.swift

struct SuccessEnvelope: Decodable {
    let success: Bool
}

// MARK: - User and auth
// Using PersonalityInsight from AuthModels.swift

// User type is defined as typealias User = BasicUser in Core/Models/User.swift
// For users with extended properties, use DomainUser from Core/Models/AuthModels.swift

// AuthEnvelope is defined in Core/Models/AuthModels.swift

// MARK: - Assessment
// AssessmentSavedResponse is defined in ViewModels/AssessmentViewModel.swift

struct AssessmentResult: Decodable {
    let success: Bool
    let personalityType: String?
    let personalityInsight: PersonalityInsight?
    let responses: [String: String]
    let assessmentId: String?
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success
        case personalityType = "personality_type"
        case personalityInsight = "personality_insight"
        case responses
        case assessmentId = "assessment_id"
        case completedAt = "completed_at"
    }
}

struct GuestAssessmentResponse: Decodable {
    let personalityType: String
    let responses: [String: String]
    let onboardingData: JSONValue?
}

// MARK: - Preferences
struct PreferencesSaveResponse: Decodable {
    let message: String
    let user: PreferencesUser

    struct PreferencesUser: Decodable {
        let id: Int
        let name: String
        let preferences: [String: JSONValue]?
        let location: [String: JSONValue]?
    }
}

struct PreferencesUpdateResponse: Decodable {
    let success: Bool
    let user: User
    let preferences: [String: JSONValue]?
}

// General preferences response type
struct PreferencesResponse: Decodable {
    let success: Bool
    let preferences: [String: JSONValue]?
    let user: User?
}

// MARK: - Activities and recommendations
// Using Activity from Core/Models/Activity.swift

// OpenAI simple recommendations (/api/recommendations/activities)
struct SimpleRecommendation: Codable {
    let title: String
    let description: String
    let category: String
}

// GET /api/recommendations/location-based (OpenAI variant)
struct LocationBasedActivityGET: Decodable {
    let id: Int?
    let title: String
    let description: String
    let category: String
    let duration: String?
    let budget: String?
    let personalityMatch: String?
}
struct LocationBasedGETResponse: Decodable {
    let activities: [LocationBasedActivityGET]
}

// Grok (X.ai) recommendation item
struct GrokActivityRecommendation: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let rating: Double?
    let distance: Double?
    let price: String?
    let address: String?
    let phone: String?
    let website: String?
    let specialties: [String]?
    let atmosphere: String?
    let estimatedCost: String?
    let recommendedTime: String?
    let personalityMatch: String?
}

// POST /api/recommendations/location-based (Grok)
struct GrokLocationPostResponse: Codable {
    let success: Bool
    var recommendations: [GrokActivityRecommendation] // Made mutable
    let canGenerateMore: Bool
    let generationsRemaining: Int
    let category: String
    let radius: Int
}

// POST /api/recommendations/drinks (Grok)
struct GrokDrinksResponse: Decodable {
    let success: Bool
    let recommendations: [String: [GrokActivityRecommendation]]
    let canGenerateMore: Bool
    let generationsRemaining: Int
}

// Categories for recommendations
struct RecommendationCategoriesResponse: Decodable {
    struct Category: Decodable { 
        let id: String
        let label: String
        let icon: String
        let color: String 
    }
    struct DrinkPref: Decodable { 
        let id: String
        let label: String
        let icon: String 
    }
    let success: Bool
    let categories: [Category]
    let drinkPreferences: [DrinkPref]
}

// AI-powered recommendations
struct AIPoweredActivity: Codable {
    let id: Int
    let name: String
    let description: String
    let category: String
    let rating: Double?
    let personalityMatch: String?
    let distance: String?
    let imageUrl: String?
    let location: String?
}

struct AIPoweredRecommendationsResponse: Codable {
    let success: Bool
    var recommendations: ActivitiesWrapper
    let message: String

    struct ActivitiesWrapper: Codable {
        var activities: [AIPoweredActivity] // Made mutable
    }
}

// General recommendations response type
struct RecommendationsResponse: Decodable {
    let success: Bool
    let recommendations: [AIPoweredActivity]
    let message: String?
    let canGenerateMore: Bool?
    let generationsRemaining: Int?
}

// MARK: - Messages
// Using MessageItem and MessageGenerationResponse from AuthModels.swift
// MessageCategory and MessageCategoriesResponse are defined in ViewModels/MessagesViewModel.swift

// MARK: - Calendar providers and events
struct CalendarProvider: Decodable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let icon: String
    let description: String
    let isConnected: Bool
    let status: String
    let authUrl: String?
    let lastSync: String?
    let errorMessage: String?
}

struct CalendarConnectResponse: Decodable { 
    let authUrl: String 
}

struct CalendarDisconnectResponse: Decodable { 
    let success: Bool 
}

// Provider (Google/Outlook) events
struct ExternalCalendarEvent: Decodable {
    let id: String
    let title: String
    let description: String?
    let start: String // ISO-8601 string
    let end: String   // ISO-8601 string
    let location: String?
    let attendees: [String]?
    let providerId: String
    let externalId: String
}

// DB calendar events (app's own events)
struct CalendarEventDB: Codable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let location: String?
    let startTime: String // ISO-8601 string
    let endTime: String   // ISO-8601 string
    let allDay: Bool
    let eventType: String
    let status: String?
    let externalEventId: String?
    let calendarProvider: String?
    let reminders: JSONValue?
    let metadata: JSONValue?
    let createdAt: String?
    let updatedAt: String?
}

struct DeleteEventResponse: Decodable { 
    let success: Bool 
}

// Response wrappers for calendar providers and events
struct CalendarProvidersResponse: Decodable {
    let providers: [CalendarProvider]
}

struct CalendarConnectionResponse: Decodable {
    let success: Bool
    let providerId: String
    let authUrl: String?
}

struct CalendarEventsResponse: Decodable {
    let events: [ExternalCalendarEvent]
    let total: Int
    let providerId: String
}

struct CalendarSyncResponse: Decodable {
    let success: Bool
    let syncedCount: Int
    let providerId: String
    let lastSync: String
}

struct CalendarStatusResponse: Decodable {
    let isConnected: Bool
    let providerId: String?
    let lastSync: String?
    let status: String
}

struct EventsResponse: Codable {
    let events: [Event]
    let total: Int
}

// MARK: - Stats
struct UserStatsResponse: Codable {
    let eventsCreated: Int
    let id: Int?
    let userId: Int?
    let createdAt: String?
    let updatedAt: String?
}