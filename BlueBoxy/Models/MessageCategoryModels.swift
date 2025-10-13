//
//  MessageCategoryModels.swift
//  BlueBoxy
//
//  Comprehensive message categories and data models for the iOS messaging implementation.
//  Builds upon existing RequestModels.swift with enhanced categorization and validation.
//

import Foundation
import SwiftUI

// MARK: - Message Category Definitions

enum MessageCategoryType: String, CaseIterable, Codable {
    case dailyCheckins = "daily_checkins"
    case appreciation = "appreciation"
    case support = "support"
    case romantic = "romantic"
    case playful = "playful"
    case encouragement = "encouragement"
    case gratitude = "gratitude"
    case flirty = "flirty"
    case thoughtful = "thoughtful"
    case celebratory = "celebratory"
    case apology = "apology"
    case goodMorning = "good_morning"
    case goodNight = "good_night"
    
    var displayName: String {
        switch self {
        case .dailyCheckins: return "Daily Check-ins"
        case .appreciation: return "Appreciation"
        case .support: return "Support"
        case .romantic: return "Romantic"
        case .playful: return "Playful"
        case .encouragement: return "Encouragement"
        case .gratitude: return "Gratitude"
        case .flirty: return "Flirty"
        case .thoughtful: return "Thoughtful"
        case .celebratory: return "Celebratory"
        case .apology: return "Apology"
        case .goodMorning: return "Good Morning"
        case .goodNight: return "Good Night"
        }
    }
    
    var description: String {
        switch self {
        case .dailyCheckins: return "Sweet check-ins to stay connected throughout the day"
        case .appreciation: return "Express gratitude and appreciation for your partner"
        case .support: return "Offer comfort and support during challenging times"
        case .romantic: return "Romantic messages to spark intimacy and connection"
        case .playful: return "Fun and lighthearted messages to bring joy"
        case .encouragement: return "Motivating messages to lift your partner's spirits"
        case .gratitude: return "Express thankfulness for the little things"
        case .flirty: return "Playful and flirtatious messages to keep the spark alive"
        case .thoughtful: return "Meaningful messages that show you're thinking of them"
        case .celebratory: return "Celebrate achievements and special moments"
        case .apology: return "Heartfelt apologies to mend and strengthen your bond"
        case .goodMorning: return "Start the day with loving morning messages"
        case .goodNight: return "End the day with sweet goodnight wishes"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .dailyCheckins: return "message"
        case .appreciation: return "heart"
        case .support: return "hand.raised"
        case .romantic: return "heart.fill"
        case .playful: return "face.smiling"
        case .encouragement: return "star"
        case .gratitude: return "hands.sparkles"
        case .flirty: return "wink"
        case .thoughtful: return "brain.head.profile"
        case .celebratory: return "party.popper"
        case .apology: return "heart.text.square"
        case .goodMorning: return "sun.rise"
        case .goodNight: return "moon.stars"
        }
    }
    
    var displayColor: Color {
        switch self {
        case .dailyCheckins: return .blue
        case .appreciation: return .pink
        case .support: return .green
        case .romantic: return .red
        case .playful: return .orange
        case .encouragement: return .purple
        case .gratitude: return .yellow
        case .flirty: return .pink
        case .thoughtful: return .indigo
        case .celebratory: return .cyan
        case .apology: return .mint
        case .goodMorning: return .yellow
        case .goodNight: return .indigo
        }
    }
    
    var priority: Int {
        switch self {
        case .dailyCheckins, .romantic, .appreciation: return 10
        case .support, .encouragement, .thoughtful: return 9
        case .playful, .flirty, .gratitude: return 8
        case .celebratory, .goodMorning, .goodNight: return 7
        case .apology: return 6
        }
    }
    
    var tags: [String] {
        switch self {
        case .dailyCheckins: return ["daily", "connection", "check-in"]
        case .appreciation: return ["gratitude", "thanks", "appreciation"]
        case .support: return ["support", "comfort", "empathy"]
        case .romantic: return ["romance", "intimacy", "love"]
        case .playful: return ["fun", "playful", "humor"]
        case .encouragement: return ["motivation", "support", "encouragement"]
        case .gratitude: return ["grateful", "thankful", "appreciation"]
        case .flirty: return ["flirt", "tease", "playful"]
        case .thoughtful: return ["thoughtful", "caring", "mindful"]
        case .celebratory: return ["celebration", "achievement", "milestone"]
        case .apology: return ["sorry", "apology", "forgiveness"]
        case .goodMorning: return ["morning", "start", "energy"]
        case .goodNight: return ["night", "sleep", "dreams"]
        }
    }
}

// MARK: - Enhanced Message Category Model

struct DetailedMessageCategory: Codable, Identifiable, Hashable {
    let id: String
    let type: MessageCategoryType
    let label: String
    let description: String
    let emoji: String?
    let tags: [String]
    let priority: Int
    let isActive: Bool
    let contextualHints: [String]
    let personalityMatches: [String]
    let timePreferences: [TimeOfDay]
    
    // Define CodingKeys for proper Decodable conformance
    enum CodingKeys: String, CodingKey {
        case id, type, label, description, emoji, tags, priority, isActive
        case contextualHints, personalityMatches, timePreferences
    }
    
    init(type: MessageCategoryType) {
        self.id = type.rawValue
        self.type = type
        self.label = type.displayName
        self.description = type.description
        self.emoji = nil // Will be derived from systemImageName
        self.tags = type.tags
        self.priority = type.priority
        self.isActive = true
        self.contextualHints = Self.generateContextualHints(for: type)
        self.personalityMatches = Self.getPersonalityMatches(for: type)
        self.timePreferences = Self.getTimePreferences(for: type)
    }
    
    // iOS-specific properties
    var systemImageName: String { type.systemImageName }
    var displayColor: Color { type.displayColor }
    var colorString: String { type.rawValue.replacingOccurrences(of: "_", with: "-") }
    
    private static func generateContextualHints(for type: MessageCategoryType) -> [String] {
        switch type {
        case .dailyCheckins:
            return ["How's your day going?", "Thinking of you", "Hope you're having a great day"]
        case .appreciation:
            return ["Thank you for", "I appreciate how you", "You always make me feel"]
        case .support:
            return ["I'm here for you", "You've got this", "Remember that I believe in you"]
        case .romantic:
            return ["I love the way you", "You make my heart", "Can't wait to see you"]
        case .playful:
            return ["Remember when we", "You're such a goofball", "This made me think of you"]
        case .encouragement:
            return ["You're amazing at", "I believe in your", "You can do anything"]
        case .gratitude:
            return ["I'm so grateful for", "Thank you for always", "You mean the world to me"]
        case .flirty:
            return ["You look incredible when", "Can't stop thinking about", "You drive me crazy"]
        case .thoughtful:
            return ["I was just thinking about", "You came to mind because", "This reminded me of you"]
        case .celebratory:
            return ["Congratulations on", "So proud of you for", "Let's celebrate"]
        case .apology:
            return ["I'm sorry for", "I didn't mean to", "Please forgive me"]
        case .goodMorning:
            return ["Good morning beautiful", "Hope your day is", "Starting my day thinking of you"]
        case .goodNight:
            return ["Sweet dreams", "Sleep well my love", "Good night beautiful"]
        }
    }
    
    private static func getPersonalityMatches(for type: MessageCategoryType) -> [String] {
        switch type {
        case .dailyCheckins, .thoughtful:
            return ["introvert", "thoughtful", "caring"]
        case .playful, .flirty:
            return ["extrovert", "playful", "outgoing"]
        case .support, .encouragement:
            return ["supportive", "empathetic", "caring"]
        case .romantic:
            return ["romantic", "affectionate", "intimate"]
        case .appreciation, .gratitude:
            return ["grateful", "appreciative", "mindful"]
        default:
            return ["any"]
        }
    }
    
    private static func getTimePreferences(for type: MessageCategoryType) -> [TimeOfDay] {
        switch type {
        case .goodMorning, .encouragement:
            return [.morning]
        case .goodNight, .romantic:
            return [.night, .evening]
        case .dailyCheckins:
            return [.morning, .afternoon]
        case .playful, .flirty:
            return [.afternoon, .evening]
        default:
            return TimeOfDay.allCases
        }
    }
}

// MARK: - Message Impact and Tone Models

enum MessageImpact: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        return rawValue.capitalized + " Impact"
    }
    
    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .blue
        }
    }
    
    var numericValue: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    var description: String {
        switch self {
        case .high: return "Likely to create strong emotional connection"
        case .medium: return "Should generate positive response"
        case .low: return "Gentle, supportive message"
        }
    }
}

enum MessageTone: String, CaseIterable, Codable {
    case warm = "warm"
    case playful = "playful"
    case romantic = "romantic"
    case supportive = "supportive"
    case encouraging = "encouraging"
    case grateful = "grateful"
    case flirty = "flirty"
    case thoughtful = "thoughtful"
    case celebratory = "celebratory"
    case apologetic = "apologetic"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .warm: return .orange
        case .playful: return .yellow
        case .romantic: return .red
        case .supportive: return .green
        case .encouraging: return .purple
        case .grateful: return .mint
        case .flirty: return .pink
        case .thoughtful: return .indigo
        case .celebratory: return .cyan
        case .apologetic: return .blue
        }
    }
    
    var emoji: String {
        switch self {
        case .warm: return "🤗"
        case .playful: return "😄"
        case .romantic: return "💕"
        case .supportive: return "🤝"
        case .encouraging: return "💪"
        case .grateful: return "🙏"
        case .flirty: return "😉"
        case .thoughtful: return "🤔"
        case .celebratory: return "🎉"
        case .apologetic: return "😔"
        }
    }
}

// MARK: - Enhanced Generated Message Model

struct ComprehensiveGeneratedMessage: Codable, Identifiable, Hashable {
    let id: String
    let content: String
    let category: MessageCategoryType
    let personalityMatch: String
    let tone: MessageTone
    let estimatedImpact: MessageImpact
    let generatedAt: Date
    let contextualFactors: MessageContext
    let metadata: MessageMetadata
    
    struct MessageContext: Codable, Hashable {
        let timeOfDay: TimeOfDay
        let relationshipDuration: String?
        let recentContext: String?
        let specialOccasion: String?
        let userPersonalityType: String?
        let partnerName: String?
        
        enum CodingKeys: String, CodingKey {
            case timeOfDay, relationshipDuration, recentContext
            case specialOccasion, userPersonalityType, partnerName
        }
    }
    
    struct MessageMetadata: Codable, Hashable {
        let wordCount: Int
        let sentimentScore: Double? // 0.0 to 1.0
        let readingTimeSeconds: Int
        let suggestedDeliveryTime: String?
        let alternativeVersions: Int
        let confidenceScore: Double? // AI confidence in message quality
    }
    
    init(
        id: String = UUID().uuidString,
        content: String,
        category: MessageCategoryType,
        personalityMatch: String,
        tone: MessageTone,
        estimatedImpact: MessageImpact,
        context: MessageContext,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.category = category
        self.personalityMatch = personalityMatch
        self.tone = tone
        self.estimatedImpact = estimatedImpact
        self.generatedAt = generatedAt
        self.contextualFactors = context
        
        // Generate metadata
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        self.metadata = MessageMetadata(
            wordCount: words.count,
            sentimentScore: nil, // Would be calculated by AI
            readingTimeSeconds: max(1, words.count / 3), // ~200 WPM
            suggestedDeliveryTime: Self.calculateOptimalDeliveryTime(for: context.timeOfDay),
            alternativeVersions: 3, // Default number of alternatives
            confidenceScore: nil // Would be provided by AI
        )
    }
    
    private static func calculateOptimalDeliveryTime(for timeOfDay: TimeOfDay) -> String {
        switch timeOfDay {
        case .morning: return "8:00 AM - 10:00 AM"
        case .afternoon: return "12:00 PM - 2:00 PM"
        case .evening: return "6:00 PM - 8:00 PM"
        case .night: return "9:00 PM - 10:00 PM"
        }
    }
}

// MARK: - Message Generation Request Enhancement

struct ComprehensiveMessageRequest: Codable {
    let userId: Int
    let category: MessageCategoryType
    let timeOfDay: TimeOfDay
    let personalityType: String?
    let partnerName: String?
    let relationshipDuration: String?
    let recentContext: String?
    let specialOccasion: String?
    let preferredTone: MessageTone?
    let desiredImpact: MessageImpact?
    let maxWordCount: Int?
    let includePersonalization: Bool
    let generateAlternatives: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId, category, timeOfDay, personalityType, partnerName
        case relationshipDuration, recentContext, specialOccasion
        case preferredTone, desiredImpact, maxWordCount
        case includePersonalization, generateAlternatives
    }
    
    init(
        userId: Int,
        category: MessageCategoryType,
        timeOfDay: TimeOfDay = .current,
        personalityType: String? = nil,
        partnerName: String? = nil,
        relationshipDuration: String? = nil,
        recentContext: String? = nil,
        specialOccasion: String? = nil,
        preferredTone: MessageTone? = nil,
        desiredImpact: MessageImpact? = nil,
        maxWordCount: Int? = nil,
        includePersonalization: Bool = true,
        generateAlternatives: Bool = true
    ) {
        self.userId = userId
        self.category = category
        self.timeOfDay = timeOfDay
        self.personalityType = personalityType
        self.partnerName = partnerName
        self.relationshipDuration = relationshipDuration
        self.recentContext = recentContext
        self.specialOccasion = specialOccasion
        self.preferredTone = preferredTone
        self.desiredImpact = desiredImpact
        self.maxWordCount = maxWordCount
        self.includePersonalization = includePersonalization
        self.generateAlternatives = generateAlternatives
    }
    
    // Convenience initializer from existing MessageGenerateRequest
    init(from request: MessageGenerateRequest, userId: Int) {
        self.init(
            userId: userId,
            category: MessageCategoryType(rawValue: request.category) ?? .dailyCheckins,
            timeOfDay: request.timeOfDay ?? .current,
            recentContext: request.recentContext,
            specialOccasion: request.specialOccasion
        )
    }
}

// MARK: - Message Generation Response

struct ComprehensiveMessageResponse: Codable {
    let success: Bool
    let messages: [ComprehensiveGeneratedMessage]
    let context: MessageGenerationContext
    let error: String?
    let metadata: ResponseMetadata
    
    struct ResponseMetadata: Codable {
        let generatedAt: Date
        let processingTimeMs: Int?
        let totalAlternatives: Int
        let personalityMatchConfidence: Double?
        let canGenerateMore: Bool
        let generationsRemaining: Int?
        let suggestedCategory: MessageCategoryType?
    }
    
    struct MessageGenerationContext: Codable {
        let category: String
        let personalityType: String
        let partnerName: String
        let timeOfDay: TimeOfDay
        let relationshipStage: String?
        let contextualFactors: [String: String]
        
        enum CodingKeys: String, CodingKey {
            case category, personalityType, partnerName, timeOfDay
            case relationshipStage, contextualFactors
        }
    }
}

// MARK: - Category Management

class MessageCategoryManager {
    static let shared = MessageCategoryManager()
    
    private init() {}
    
    /// Get all available message categories
    func getAllCategories() -> [DetailedMessageCategory] {
        return MessageCategoryType.allCases.map { DetailedMessageCategory(type: $0) }
    }
    
    /// Get categories filtered by personality type
    func getRecommendedCategories(for personalityType: String) -> [DetailedMessageCategory] {
        let allCategories = getAllCategories()
        
        return allCategories.filter { category in
            category.personalityMatches.contains(personalityType.lowercased()) ||
            category.personalityMatches.contains("any")
        }.sorted { $0.priority > $1.priority }
    }
    
    /// Get categories appropriate for time of day
    func getCategoriesForTime(_ timeOfDay: TimeOfDay) -> [DetailedMessageCategory] {
        return getAllCategories().filter { category in
            category.timePreferences.contains(timeOfDay)
        }.sorted { $0.priority > $1.priority }
    }
    
    /// Get category by ID
    func getCategory(id: String) -> DetailedMessageCategory? {
        guard let type = MessageCategoryType(rawValue: id) else { return nil }
        return DetailedMessageCategory(type: type)
    }
    
    /// Get contextual suggestions for a category
    func getContextualSuggestions(for category: MessageCategoryType, personalityType: String? = nil) -> [String] {
        let categoryDetail = DetailedMessageCategory(type: category)
        var suggestions = categoryDetail.contextualHints
        
        // Add personality-specific suggestions
        if let personality = personalityType {
            suggestions.append(contentsOf: getPersonalitySpecificSuggestions(for: category, personality: personality))
        }
        
        return Array(Set(suggestions)) // Remove duplicates
    }
    
    private func getPersonalitySpecificSuggestions(for category: MessageCategoryType, personality: String) -> [String] {
        switch (category, personality.lowercased()) {
        case (.romantic, "introvert"):
            return ["In quiet moments like these", "Your gentle touch means"]
        case (.romantic, "extrovert"):
            return ["I love how we laugh together", "You light up every room"]
        case (.support, "introvert"):
            return ["I understand you need space", "Take your time, I'm here"]
        case (.support, "extrovert"):
            return ["Want to talk it out?", "I'm here to listen and help"]
        default:
            return []
        }
    }
}

// MARK: - Validation Extensions

extension ComprehensiveMessageRequest {
    var isValid: Bool {
        return userId > 0 && 
               !category.rawValue.isEmpty &&
               (maxWordCount == nil || maxWordCount! > 0)
    }
    
    var estimatedComplexity: Int {
        var complexity = 1
        
        if includePersonalization { complexity += 1 }
        if generateAlternatives { complexity += 1 }
        if recentContext != nil { complexity += 1 }
        if specialOccasion != nil { complexity += 1 }
        
        return complexity
    }
}

extension DetailedMessageCategory {
    /// Check if category is suitable for current time
    var isSuitableForCurrentTime: Bool {
        let currentTime = TimeOfDay.current
        return timePreferences.contains(currentTime)
    }
    
    /// Get difficulty level for personality matching
    func getDifficultyLevel(for personalityType: String) -> Int {
        if personalityMatches.contains(personalityType.lowercased()) {
            return 1 // Easy match
        } else if personalityMatches.contains("any") {
            return 2 // Medium
        } else {
            return 3 // Challenging match
        }
    }
}