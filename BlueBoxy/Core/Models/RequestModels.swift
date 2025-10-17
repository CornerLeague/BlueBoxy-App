//
//  RequestModels.swift
//  BlueBoxy
//
//  Encodable request structs for API communication
//  These models represent data sent TO the backend API
//

import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Auth

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String?
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name
        case partnerName = "partner_name"
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
    }

    init(email: String,
         password: String,
         name: String? = nil,
         partnerName: String? = nil,
         relationshipDuration: String? = nil,
         partnerAge: Int? = nil) {
        self.email = email
        self.password = password
        self.name = name
        self.partnerName = partnerName
        self.relationshipDuration = relationshipDuration
        self.partnerAge = partnerAge
    }
}


// MARK: - Assessment

struct AssessmentResponsesRequest: Encodable {
    let responses: [String: String]
    let personalityType: String?

    init(responses: [String: String],
         personalityType: String? = nil) {
        self.responses = responses
        self.personalityType = personalityType
    }
}

struct GuestAssessmentRequest: Encodable {
    let responses: [String: String]
    let personalityType: String
    let onboardingData: JSONValue?

    init(responses: [String: String],
         personalityType: String,
         onboardingData: JSONValue? = nil) {
        self.responses = responses
        self.personalityType = personalityType
        self.onboardingData = onboardingData
    }
}

// MARK: - Preferences

struct GeoLocationPayload: Codable {
    let latitude: Double
    let longitude: Double
}

struct SavePreferencesRequest: Encodable {
    let preferences: [String: JSONValue]?
    let location: GeoLocationPayload?
    let partnerAge: Int?

    init(preferences: [String: JSONValue]? = nil,
         location: GeoLocationPayload? = nil,
         partnerAge: Int? = nil) {
        self.preferences = preferences
        self.location = location
        self.partnerAge = partnerAge
    }
}

struct UpdatePreferencesRequest: Encodable {
    let preferences: [String: JSONValue]
}

// MARK: - Recommendations (Grok / OpenAI)

struct LocationBasedPostRequest: Encodable {
    let location: GeoLocationPayload
    let radius: Int
    let category: String
    let preferences: [String: JSONValue]?
    let personalityType: String?
    let resetAlgorithm: Bool?

    init(location: GeoLocationPayload,
         radius: Int,
         category: String,
         preferences: [String: JSONValue]? = nil,
         personalityType: String? = nil,
         resetAlgorithm: Bool? = nil) {
        self.location = location
        self.radius = radius
        self.category = category
        self.preferences = preferences
        self.personalityType = personalityType
        self.resetAlgorithm = resetAlgorithm
    }
}

struct DrinksRecommendationsRequest: Encodable {
    let location: GeoLocationPayload
    let radius: Int
    let drinkPreferences: [String]
    let personalityType: String?
    let resetAlgorithm: Bool?

    init(location: GeoLocationPayload,
         radius: Int,
         drinkPreferences: [String],
         personalityType: String? = nil,
         resetAlgorithm: Bool? = nil) {
        self.location = location
        self.radius = radius
        self.drinkPreferences = drinkPreferences
        self.personalityType = personalityType
        self.resetAlgorithm = resetAlgorithm
    }
}

struct AIPoweredRecommendationsRequest: Encodable {
    let category: String
    let location: GeoLocationPayload?
    let preferences: [String: JSONValue]?

    init(category: String,
         location: GeoLocationPayload? = nil,
         preferences: [String: JSONValue]? = nil) {
        self.category = category
        self.location = location
        self.preferences = preferences
    }
}

// MARK: - Calendar

struct CalendarDisconnectRequest: Encodable {
    // Current backend expects userId in request body for disconnect (public route)
    // With Option A, this is redundant, but keep for compatibility.
    let userId: String
}

// MARK: - Events (DB)

struct CreateEventRequest: Encodable {
    let title: String
    let description: String?
    let location: String?
    // Server accepts string|Date; encode as Date with ISO8601 encoder
    let startTime: Date
    let endTime: Date
    let allDay: Bool?
    let eventType: String
    let status: String?
    let externalEventId: String?
    let calendarProvider: String?
    let reminders: JSONValue?
    let metadata: JSONValue?

    init(title: String,
         description: String? = nil,
         location: String? = nil,
         startTime: Date,
         endTime: Date,
         allDay: Bool? = nil,
         eventType: String,
         status: String? = nil,
         externalEventId: String? = nil,
         calendarProvider: String? = nil,
         reminders: JSONValue? = nil,
         metadata: JSONValue? = nil) {
        self.title = title
        self.description = description
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.allDay = allDay
        self.eventType = eventType
        self.status = status
        self.externalEventId = externalEventId
        self.calendarProvider = calendarProvider
        self.reminders = reminders
        self.metadata = metadata
    }
}

// MARK: - Messages

enum TimeOfDay: String, Codable, CaseIterable {
    case morning, afternoon, evening, night
    
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// Enhanced message generation request with comprehensive features
struct MessageGenerateRequest: Encodable {
    let category: String // consider an enum if you want stronger typing
    let timeOfDay: TimeOfDay?
    let recentContext: String?
    let specialOccasion: String?
    
    // Enhanced fields for comprehensive messaging
    let userId: Int?
    let personalityType: String?
    let partnerName: String?
    let relationshipDuration: String?
    let preferredTone: String?
    let desiredImpact: String?
    let maxWordCount: Int?
    let includePersonalization: Bool?
    let generateAlternatives: Bool?

    init(category: String,
         timeOfDay: TimeOfDay? = nil,
         recentContext: String? = nil,
         specialOccasion: String? = nil,
         userId: Int? = nil,
         personalityType: String? = nil,
         partnerName: String? = nil,
         relationshipDuration: String? = nil,
         preferredTone: String? = nil,
         desiredImpact: String? = nil,
         maxWordCount: Int? = nil,
         includePersonalization: Bool? = nil,
         generateAlternatives: Bool? = nil) {
        self.category = category
        self.timeOfDay = timeOfDay
        self.recentContext = recentContext
        self.specialOccasion = specialOccasion
        self.userId = userId
        self.personalityType = personalityType
        self.partnerName = partnerName
        self.relationshipDuration = relationshipDuration
        self.preferredTone = preferredTone
        self.desiredImpact = desiredImpact
        self.maxWordCount = maxWordCount
        self.includePersonalization = includePersonalization
        self.generateAlternatives = generateAlternatives
    }
    
    // Backward compatibility convenience initializer
    init(category: String,
         timeOfDay: TimeOfDay? = nil,
         recentContext: String? = nil,
         specialOccasion: String? = nil) {
        self.init(
            category: category,
            timeOfDay: timeOfDay,
            recentContext: recentContext,
            specialOccasion: specialOccasion,
            userId: nil,
            personalityType: nil,
            partnerName: nil,
            relationshipDuration: nil,
            preferredTone: nil,
            desiredImpact: nil,
            maxWordCount: nil,
            includePersonalization: nil,
            generateAlternatives: nil
        )
    }
}

// MARK: - Additional Helper Models

// MARK: - Request Validation Extensions

extension RegisterRequest {
    /// Validates that the registration request has required fields
    var isValid: Bool {
        return !email.isEmpty && !password.isEmpty
    }
    
    /// Validates email format (basic validation)
    var hasValidEmail: Bool {
        return email.contains("@") && email.contains(".")
    }
    
    /// Validates password strength (basic validation)
    var hasValidPassword: Bool {
        return password.count >= 8
    }
}

extension LoginRequest {
    /// Validates that the login request has required fields
    var isValid: Bool {
        return !email.isEmpty && !password.isEmpty
    }
}

extension SavePreferencesRequest {
    /// Validates that at least one field is being updated
    var hasData: Bool {
        return preferences != nil || location != nil || partnerAge != nil
    }
}

extension CreateEventRequest {
    /// Validates that the event has required fields and valid dates
    var isValid: Bool {
        return !title.isEmpty && 
               !eventType.isEmpty && 
               startTime < endTime
    }
    
    /// Calculates the duration of the event
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Checks if the event is in the future
    var isFuture: Bool {
        return startTime > Date()
    }
}

extension MessageGenerateRequest {
    /// Validates that the message generation request has required fields
    var isValid: Bool {
        return !category.isEmpty && 
               (userId == nil || userId! > 0) &&
               (maxWordCount == nil || maxWordCount! > 0)
    }
    
    /// Comprehensive message categories for validation
    static let validCategories = [
        "daily_checkins", "appreciation", "support", "romantic", "playful",
        "encouragement", "gratitude", "flirty", "thoughtful", "celebratory",
        "apology", "good_morning", "good_night"
    ]
    
    /// Validates that the category is one of the known types
    var hasValidCategory: Bool {
        return Self.validCategories.contains(category.lowercased())
    }
    
    /// Checks if request includes personalization data
    var hasPersonalizationData: Bool {
        return personalityType != nil || partnerName != nil || relationshipDuration != nil
    }
    
    /// Estimates complexity of the generation request
    var complexityLevel: Int {
        var complexity = 1
        
        if hasPersonalizationData { complexity += 1 }
        if includePersonalization == true { complexity += 1 }
        if generateAlternatives == true { complexity += 1 }
        if recentContext != nil && !recentContext!.isEmpty { complexity += 1 }
        if specialOccasion != nil && !specialOccasion!.isEmpty { complexity += 1 }
        
        return complexity
    }
    
    /// Creates a request optimized for the current time of day
    static func forCurrentTime(
        category: String,
        userId: Int? = nil,
        personalityType: String? = nil,
        partnerName: String? = nil
    ) -> MessageGenerateRequest {
        return MessageGenerateRequest(
            category: category,
            timeOfDay: .current,
            userId: userId,
            personalityType: personalityType,
            partnerName: partnerName,
            includePersonalization: personalityType != nil,
            generateAlternatives: true
        )
    }
}

extension GeoLocationPayload {
    /// Validates that the coordinates are within valid ranges
    var isValid: Bool {
        return latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }
    
    /// Creates a location payload from CLLocationCoordinate2D (if using CoreLocation)
    #if canImport(CoreLocation)
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    /// Converts to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    #endif
}

// MARK: - Convenience Initializers

extension LocationBasedPostRequest {
    /// Convenience initializer with common defaults
    init(latitude: Double, 
         longitude: Double, 
         category: String, 
         radiusInMiles: Int = 5) {
        self.init(
            location: GeoLocationPayload(latitude: latitude, longitude: longitude),
            radius: radiusInMiles,
            category: category
        )
    }
}

extension DrinksRecommendationsRequest {
    /// Convenience initializer with common defaults
    init(latitude: Double,
         longitude: Double,
         drinkPreferences: [String],
         radiusInMiles: Int = 5) {
        self.init(
            location: GeoLocationPayload(latitude: latitude, longitude: longitude),
            radius: radiusInMiles,
            drinkPreferences: drinkPreferences
        )
    }
}

extension CreateEventRequest {
    /// Convenience initializer for simple events
    init(title: String,
         startTime: Date,
         endTime: Date,
         eventType: String = "date") {
        self.init(
            title: title,
            description: nil,
            location: nil,
            startTime: startTime,
            endTime: endTime,
            allDay: nil,
            eventType: eventType,
            status: nil,
            externalEventId: nil,
            calendarProvider: nil,
            reminders: nil,
            metadata: nil
        )
    }
    
    /// Convenience initializer for all-day events
    init(title: String,
         date: Date,
         eventType: String = "date") {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        self.init(
            title: title,
            description: nil,
            location: nil,
            startTime: startOfDay,
            endTime: endOfDay,
            allDay: true,
            eventType: eventType,
            status: nil,
            externalEventId: nil,
            calendarProvider: nil,
            reminders: nil,
            metadata: nil
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension RegisterRequest {
    /// Sample registration request for testing/previews
    static let sample = RegisterRequest(
        email: "test@example.com",
        password: "password123",
        name: "Test User",
        partnerName: "Test Partner",
        relationshipDuration: "1 year",
        partnerAge: 25
    )
}

extension LoginRequest {
    /// Sample login request for testing/previews
    static let sample = LoginRequest(
        email: "test@example.com",
        password: "password123"
    )
}

extension MessageGenerateRequest {
    /// Sample message generation request for testing/previews
    static let sample = MessageGenerateRequest(
        category: "appreciation",
        timeOfDay: .evening,
        recentContext: "Had a wonderful date last night",
        specialOccasion: "Anniversary"
    )
}

extension CreateEventRequest {
    /// Sample event creation request for testing/previews
    static let sample = CreateEventRequest(
        title: "Romantic Dinner",
        description: "Anniversary dinner at our favorite restaurant",
        location: "Downtown Bistro",
        startTime: Date().addingTimeInterval(3600), // 1 hour from now
        endTime: Date().addingTimeInterval(7200),   // 2 hours from now
        eventType: "date"
    )
}
#endif