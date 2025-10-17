//
//  MessagingModels.swift
//  BlueBoxy
//
//  Enhanced messaging models for AI message generation with personality insights,
//  iOS-specific UI mappings, and comprehensive message categorization
//

import Foundation
import SwiftUI

// MARK: - Enhanced Message Category Model

struct EnhancedMessageCategory: Codable, Identifiable {
    let id: String
    let label: String
    let description: String
    
    // iOS-specific UI mappings from the implementation guide
    var systemImageName: String {
        switch id {
        case "daily_checkins": return "message"
        case "appreciation": return "heart"
        case "support": return "hand.raised"
        case "romantic": return "heart.fill"
        case "playful": return "face.smiling"
        case "encouragement": return "star"
        case "gratitude": return "hands.sparkles"
        case "flirty": return "wink"
        case "thoughtful": return "brain.head.profile"
        default: return "text.bubble"
        }
    }
    
    var displayColor: Color {
        switch id {
        case "daily_checkins": return .blue
        case "appreciation": return .pink
        case "support": return .green
        case "romantic": return .red
        case "playful": return .orange
        case "encouragement": return .purple
        case "gratitude": return .yellow
        case "flirty": return .pink
        case "thoughtful": return .indigo
        default: return .gray
        }
    }
    
    var colorString: String {
        switch id {
        case "daily_checkins": return "blue"
        case "appreciation": return "pink"
        case "support": return "green"
        case "romantic": return "red"
        case "playful": return "orange"
        case "encouragement": return "purple"
        case "gratitude": return "yellow"
        case "flirty": return "pink"
        case "thoughtful": return "indigo"
        default: return "gray"
        }
    }
}

// MARK: - Enhanced Generated Message Model

struct EnhancedGeneratedMessage: Codable, Identifiable {
    let id: String
    let content: String
    let category: String
    let personalityMatch: String
    let tone: String
    let estimatedImpact: ImpactLevel
    let generatedAt: Date?
    
    enum ImpactLevel: String, Codable, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .yellow
            case .low: return .blue
            }
        }
        
        var colorString: String {
            switch self {
            case .high: return "green"
            case .medium: return "yellow"
            case .low: return "blue"
            }
        }
        
        var displayName: String {
            return rawValue.capitalized + " Impact"
        }
        
        var numericValue: Int {
            switch self {
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }
    
    // Convenience initializer from existing MessageItem
    init(from messageItem: MessageItem) {
        self.id = messageItem.id
        self.content = messageItem.content
        self.category = messageItem.category
        self.personalityMatch = messageItem.personalityMatch
        self.tone = messageItem.tone
        
        // Convert string impact to enum
        switch messageItem.estimatedImpact.lowercased() {
        case "high": self.estimatedImpact = .high
        case "medium": self.estimatedImpact = .medium
        case "low": self.estimatedImpact = .low
        default: self.estimatedImpact = .medium
        }
        
        self.generatedAt = Date()
    }
}

// MARK: - Message Generation Context

struct MessageGenerationContext: Codable {
    let category: String
    let personalityType: String
    let partnerName: String
    let timeOfDay: TimeOfDay?
    let relationshipDuration: String?
    let specialOccasion: String?
    let generatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case category, personalityType, partnerName, timeOfDay
        case relationshipDuration, specialOccasion, generatedAt
    }
    
    init(category: String, personalityType: String, partnerName: String, timeOfDay: TimeOfDay? = nil, relationshipDuration: String? = nil, specialOccasion: String? = nil) {
        self.category = category
        self.personalityType = personalityType
        self.partnerName = partnerName
        self.timeOfDay = timeOfDay
        self.relationshipDuration = relationshipDuration
        self.specialOccasion = specialOccasion
        self.generatedAt = Date()
    }
}

// MARK: - Enhanced Message Generation Request

struct EnhancedMessageGenerateRequest: Codable {
    let userId: Int
    let category: String
    let timeOfDay: TimeOfDay?
    let recentContext: String?
    let specialOccasion: String?
    let personalityType: String?
    let partnerName: String?
    
    enum CodingKeys: String, CodingKey {
        case userId, category, timeOfDay, recentContext
        case specialOccasion, personalityType, partnerName
    }
    
    init(userId: Int, category: String, timeOfDay: TimeOfDay? = nil, recentContext: String? = nil, specialOccasion: String? = nil, personalityType: String? = nil, partnerName: String? = nil) {
        self.userId = userId
        self.category = category
        self.timeOfDay = timeOfDay ?? .current
        self.recentContext = recentContext
        self.specialOccasion = specialOccasion
        self.personalityType = personalityType
        self.partnerName = partnerName
    }
}

// MARK: - Time of Day Enhancement

extension TimeOfDay {
    // current property is defined in the main TimeOfDay enum in RequestModels.swift
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .morning: return "sun.rise"
        case .afternoon: return "sun.max"
        case .evening: return "sun.dust"
        case .night: return "moon.stars"
        }
    }
    
    var contextualGreeting: String {
        switch self {
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good night"
        }
    }
}

// MARK: - Enhanced Message Generation Response

struct EnhancedMessageGenerationResponse: Codable {
    let success: Bool
    let messages: [EnhancedGeneratedMessage]
    let context: MessageGenerationContext
    let error: String?
    let generatedAt: Date?
    let canGenerateMore: Bool?
    let generationsRemaining: Int?
    
    // Convenience initializer from existing response
    init(from response: MessageGenerationResponse, context: MessageGenerationContext) {
        self.success = response.success
        self.messages = response.messages.map { EnhancedGeneratedMessage(from: $0) }
        self.context = context
        self.error = response.error
        self.generatedAt = response.generatedAt
        self.canGenerateMore = true // Default assumption
        self.generationsRemaining = nil // Will be set by server if needed
    }
}

// MARK: - Message Categories Response Enhancement

struct EnhancedMessageCategoriesResponse: Codable {
    let success: Bool
    let categories: [EnhancedMessageCategory]
    
    // Convenience initializer from existing response
    init(from response: MessageCategoriesResponse) {
        self.success = response.success
        self.categories = response.categories.map { category in
            EnhancedMessageCategory(
                id: category.id,
                label: category.name,
                description: category.description
            )
        }
    }
}

// MARK: - User Integration for Messaging

extension DomainUser {
    /// Get messaging context for personalized generation
    var messagingContext: MessageGenerationContext? {
        guard let partnerName = partnerName,
              let personalityType = personalityType else {
            return nil
        }
        
        return MessageGenerationContext(
            category: "daily_checkins", // Default category
            personalityType: personalityType,
            partnerName: partnerName,
            timeOfDay: TimeOfDay.current,
            relationshipDuration: relationshipDuration
        )
    }
    
    /// Check if user has sufficient data for message generation
    var canGenerateMessages: Bool {
        return partnerName != nil && personalityType != nil
    }
    
    /// Get personalized message request template
    func createMessageRequest(for category: String, userId: Int) -> EnhancedMessageGenerateRequest {
        return EnhancedMessageGenerateRequest(
            userId: userId,
            category: category,
            timeOfDay: TimeOfDay.current,
            recentContext: nil,
            specialOccasion: nil,
            personalityType: personalityType,
            partnerName: partnerName
        )
    }
    
    // createComprehensiveMessageRequest is defined in MessageModelBridge.swift
}

// MARK: - Message Personalization Helpers

struct MessagePersonalizationHelper {
    
    /// Generate contextual suggestions based on user profile
    static func generateContextSuggestions(for user: DomainUser) -> [String] {
        var suggestions: [String] = []
        
        // Add relationship duration context
        if let duration = user.relationshipDuration {
            suggestions.append("After \(duration) together")
        }
        
        // Add personality-based context
        if let personality = user.personalityType {
            switch personality.lowercased() {
            case "introvert":
                suggestions.append("After a quiet evening")
            case "extrovert":
                suggestions.append("After our fun night out")
            default:
                suggestions.append("After spending time together")
            }
        }
        
        // Add time-based context
        let timeOfDay = TimeOfDay.current
        suggestions.append("This \(timeOfDay.rawValue)")
        
        return suggestions
    }
    
    /// Get recommended categories based on user profile
    static func recommendedCategories(for user: DomainUser, from categories: [EnhancedMessageCategory]) -> [EnhancedMessageCategory] {
        guard let personality = user.personalityType?.lowercased() else {
            return categories
        }
        
        // Sort categories based on personality type
        return categories.sorted { category1, category2 in
            let score1 = categoryScore(for: category1.id, personality: personality)
            let score2 = categoryScore(for: category2.id, personality: personality)
            return score1 > score2
        }
    }
    
    private static func categoryScore(for categoryId: String, personality: String) -> Int {
        switch personality {
        case "introvert":
            switch categoryId {
            case "thoughtful": return 10
            case "appreciation": return 9
            case "support": return 8
            case "romantic": return 7
            default: return 5
            }
        case "extrovert":
            switch categoryId {
            case "playful": return 10
            case "flirty": return 9
            case "encouragement": return 8
            case "daily_checkins": return 7
            default: return 5
            }
        default:
            return 5
        }
    }
}

// MARK: - Message Storage Models

struct MessageHistoryItem: Codable, Identifiable {
    let id: String
    let message: EnhancedGeneratedMessage
    let context: MessageGenerationContext
    let savedAt: Date
    let isFavorite: Bool
    let wasShared: Bool
    
    init(message: EnhancedGeneratedMessage, context: MessageGenerationContext, isFavorite: Bool = false, wasShared: Bool = false) {
        self.id = message.id
        self.message = message
        self.context = context
        self.savedAt = Date()
        self.isFavorite = isFavorite
        self.wasShared = wasShared
    }
}

struct MessageHistoryResponse: Codable {
    let messages: [MessageHistoryItem]
    let total: Int
    let page: Int
    let hasMore: Bool
}

// MARK: - Type Aliases for Backward Compatibility

/// Alias for EnhancedGeneratedMessage to maintain compatibility
typealias GeneratedMessage = EnhancedGeneratedMessage

/// Alias for MessageGenerationResponse to maintain compatibility
typealias GeneratedMessageResponse = MessageGenerationResponse

/// Alias for MessageItem to maintain compatibility
typealias Message = MessageItem

// MARK: - Missing Service Types

// MessageGenerationOptions is defined in MessagingNetworkClient.swift

// MessageCategorySelector and MessageStatistics are defined in MessageModelBridge.swift

// MARK: - Type Conversion Extensions

extension EnhancedGeneratedMessage {
    /// Convert to ComprehensiveGeneratedMessage for compatibility
    func toComprehensiveMessage(with context: MessageGenerationContext? = nil) -> ComprehensiveGeneratedMessage {
        let messageContext = context ?? MessageGenerationContext(
            category: self.category,
            personalityType: self.personalityMatch,
            partnerName: "Partner", // Default value
            timeOfDay: .current,
            relationshipDuration: nil,
            specialOccasion: nil
        )
        
        let comprehensiveContext = ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: messageContext.timeOfDay ?? .current,
            relationshipDuration: messageContext.relationshipDuration,
            recentContext: nil,
            specialOccasion: messageContext.specialOccasion,
            userPersonalityType: messageContext.personalityType,
            partnerName: messageContext.partnerName
        )
        
        return ComprehensiveGeneratedMessage(
            id: self.id,
            content: self.content,
            category: MessageCategoryType(rawValue: self.category) ?? .dailyCheckins,
            personalityMatch: self.personalityMatch,
            tone: MessageTone.warm, // Default tone
            estimatedImpact: MessageImpact.medium, // Default impact
            context: comprehensiveContext,
            generatedAt: self.generatedAt ?? Date()
        )
    }
}
