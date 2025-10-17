//
//  AuthModels.swift
//  BlueBoxy
//
//  Authentication and user domain models with personality insights
//  and relationship-focused features
//

import Foundation

// MARK: - Personality & Relationship Models

struct PersonalityInsight: Codable {
    let description: String
    let loveLanguage: String
    let communicationStyle: String
    let idealActivities: [String]
    let stressResponse: String
    
    enum CodingKeys: String, CodingKey {
        case description
        case loveLanguage = "love_language"
        case communicationStyle = "communication_style"
        case idealActivities = "ideal_activities"
        case stressResponse = "stress_response"
    }
}

// MARK: - Full Domain User Model

struct DomainUser: Codable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    let personalityType: String?
    let personalityInsight: PersonalityInsight?
    let preferences: [String: AnyDecodable]?
    let location: [String: AnyDecodable]?
    
    // Additional fields for comprehensive user management
    let createdAt: Date?
    let updatedAt: Date?
    let lastLoginAt: Date?
    let isActive: Bool?
    let subscriptionTier: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name
        case partnerName = "partner_name"
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
        case personalityType = "personality_type"
        case personalityInsight = "personality_insight"
        case preferences, location
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLoginAt = "last_login_at"
        case isActive = "is_active"
        case subscriptionTier = "subscription_tier"
    }
}

// MARK: - Authentication Envelope

struct AuthEnvelope: Decodable {
    let user: DomainUser
    let token: String?
    let refreshToken: String?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case user, token
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

// MARK: - Authentication Request Models

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let name: String
    let partnerName: String?
    let personalityType: String?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name
        case partnerName = "partner_name"
        case personalityType = "personality_type"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct UpdateProfileRequest: Encodable {
    let name: String?
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    let personalityType: String?
    let preferences: [String: AnyEncodable]?
    let location: [String: AnyEncodable]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case partnerName = "partner_name"
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
        case personalityType = "personality_type"
        case preferences, location
    }
}

// MARK: - Message Generation Models

struct MessageItem: Decodable, Identifiable {
    let id: String
    let content: String
    let category: String
    let personalityMatch: String
    let tone: String
    let estimatedImpact: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, content, category, tone
        case personalityMatch = "personality_match"
        case estimatedImpact = "estimated_impact"
        case createdAt = "created_at"
    }
}

struct MessageGenerationRequest: Encodable {
    let context: String?
    let mood: String?
    let category: String?
    let personalityType: String?
    let relationshipStage: String?
    
    enum CodingKeys: String, CodingKey {
        case context, mood, category
        case personalityType = "personality_type"
        case relationshipStage = "relationship_stage"
    }
}

struct MessageGenerationResponse: Decodable {
    let success: Bool
    let messages: [MessageItem]
    let context: [String: String]
    let error: String?
    let generatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success, messages, context, error
        case generatedAt = "generated_at"
    }
}

// MARK: - User Preference Models

struct UserPreferences: Codable {
    let communicationFrequency: String?
    let preferredMessageTone: String?
    let relationshipGoals: [String]?
    let activityPreferences: [String]?
    let notificationSettings: NotificationSettings?
    
    enum CodingKeys: String, CodingKey {
        case communicationFrequency = "communication_frequency"
        case preferredMessageTone = "preferred_message_tone"
        case relationshipGoals = "relationship_goals"
        case activityPreferences = "activity_preferences"
        case notificationSettings = "notification_settings"
    }
}

struct NotificationSettings: Codable {
    let dailyMessages: Bool
    let weeklyInsights: Bool
    let relationshipMilestones: Bool
    let personalityUpdates: Bool
    
    enum CodingKeys: String, CodingKey {
        case dailyMessages = "daily_messages"
        case weeklyInsights = "weekly_insights"
        case relationshipMilestones = "relationship_milestones"
        case personalityUpdates = "personality_updates"
    }
}

// MARK: - Location Models

struct UserLocation: Codable {
    let city: String?
    let state: String?
    let country: String?
    let timezone: String?
    let coordinates: LocationCoordinates?
}

struct LocationCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Convenience Extensions

extension DomainUser {
    /// Convert to BasicUser for general operations
    var basicUser: BasicUser {
        return BasicUser(
            id: id,
            email: email,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastLoginAt: lastLoginAt
        )
    }
    
    /// Get preferences as strongly typed object
    var typedPreferences: UserPreferences? {
        guard let prefs = preferences else { return nil }
        let data = try? JSONSerialization.data(withJSONObject: prefs)
        return data.flatMap { try? JSONDecoder().decode(UserPreferences.self, from: $0) }
    }
    
    /// Get location as strongly typed object
    var typedLocation: UserLocation? {
        guard let loc = location else { return nil }
        let data = try? JSONSerialization.data(withJSONObject: loc)
        return data.flatMap { try? JSONDecoder().decode(UserLocation.self, from: $0) }
    }
    
    /// Check if user has complete profile
    var hasCompleteProfile: Bool {
        return name.count > 0 && 
               partnerName != nil && 
               personalityType != nil &&
               personalityInsight != nil
    }
    
    /// Get relationship duration in months (if parseable)
    var relationshipDurationMonths: Int? {
        guard let duration = relationshipDuration else { return nil }
        // Simple parsing for formats like "6 months", "1 year", etc.
        let components = duration.lowercased().components(separatedBy: " ")
        guard components.count >= 2,
              let value = Int(components[0]) else { return nil }
        
        if components[1].contains("year") {
            return value * 12
        } else if components[1].contains("month") {
            return value
        }
        return nil
    }
}

extension MessageItem {
    /// Get estimated impact as numeric value
    var impactScore: Int? {
        switch estimatedImpact.lowercased() {
        case "low": return 1
        case "medium": return 2
        case "high": return 3
        default: return Int(estimatedImpact)
        }
    }
    
    /// Check if message matches current user's personality
    func matchesPersonality(_ personalityType: String?) -> Bool {
        guard let userPersonality = personalityType else { return true }
        return personalityMatch.lowercased() == userPersonality.lowercased()
    }
}