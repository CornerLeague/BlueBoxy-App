//
//  MessageModelBridge.swift
//  BlueBoxy
//
//  Bridge file that connects existing BlueBoxy models with the comprehensive messaging models.
//  Provides seamless integration and conversion between model types.
//

import Foundation
import SwiftUI

// MARK: - Model Conversion Extensions

extension MessageItem {
    /// Convert to ComprehensiveGeneratedMessage
    func toComprehensiveMessage(context: ComprehensiveGeneratedMessage.MessageContext? = nil) -> ComprehensiveGeneratedMessage {
        let messageContext = context ?? ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: .current,
            relationshipDuration: nil,
            recentContext: nil,
            specialOccasion: nil,
            userPersonalityType: nil,
            partnerName: nil
        )
        
        let categoryType = MessageCategoryType(rawValue: category) ?? .dailyCheckins
        let messageTone = MessageTone(rawValue: tone.lowercased()) ?? .warm
        let messageImpact = MessageImpact(rawValue: estimatedImpact.lowercased()) ?? .medium
        
        return ComprehensiveGeneratedMessage(
            id: id,
            content: content,
            category: categoryType,
            personalityMatch: personalityMatch,
            tone: messageTone,
            estimatedImpact: messageImpact,
            context: messageContext,
            generatedAt: Date()
        )
    }
}

extension MessageGenerateRequest {
    /// Convert to ComprehensiveMessageRequest
    func toComprehensiveRequest(userId: Int) -> ComprehensiveMessageRequest {
        let categoryType = MessageCategoryType(rawValue: category) ?? .dailyCheckins
        let tone = preferredTone.flatMap { MessageTone(rawValue: $0.lowercased()) }
        let impact = desiredImpact.flatMap { MessageImpact(rawValue: $0.lowercased()) }
        
        return ComprehensiveMessageRequest(
            userId: userId,
            category: categoryType,
            timeOfDay: timeOfDay ?? .current,
            personalityType: personalityType,
            partnerName: partnerName,
            relationshipDuration: relationshipDuration,
            recentContext: recentContext,
            specialOccasion: specialOccasion,
            preferredTone: tone,
            desiredImpact: impact,
            maxWordCount: maxWordCount,
            includePersonalization: includePersonalization ?? true,
            generateAlternatives: generateAlternatives ?? true
        )
    }
}

extension MessageCategory {
    /// Convert to DetailedMessageCategory
    func toDetailedCategory() -> DetailedMessageCategory {
        guard let type = MessageCategoryType(rawValue: id) else {
            // Fallback for unknown categories
            return DetailedMessageCategory(type: .dailyCheckins)
        }
        return DetailedMessageCategory(type: type)
    }
    
    /// Convert to EnhancedMessageCategory
    func toEnhancedCategory() -> EnhancedMessageCategory {
        return EnhancedMessageCategory(
            id: id,
            label: name,
            description: description
        )
    }
}

// MARK: - DomainUser Extensions for Messaging

extension DomainUser {
    /// Create a comprehensive message request template for this user
    func createComprehensiveMessageRequest(
        for category: MessageCategoryType,
        recentContext: String? = nil,
        specialOccasion: String? = nil
    ) -> ComprehensiveMessageRequest {
        return ComprehensiveMessageRequest(
            userId: id,
            category: category,
            timeOfDay: .current,
            personalityType: personalityType,
            partnerName: partnerName,
            relationshipDuration: relationshipDuration,
            recentContext: recentContext,
            specialOccasion: specialOccasion
        )
    }
    
    /// Get recommended message categories based on user profile
    var recommendedMessageCategories: [DetailedMessageCategory] {
        guard let personalityType = personalityType else {
            return MessageCategoryManager.shared.getAllCategories()
        }
        
        return MessageCategoryManager.shared.getRecommendedCategories(for: personalityType)
    }
    
    /// Get time-appropriate message categories
    var timeAppropriateCategories: [DetailedMessageCategory] {
        return MessageCategoryManager.shared.getCategoriesForTime(.current)
    }
    
    /// Get personalized contextual suggestions
    func getContextualSuggestions(for category: MessageCategoryType) -> [String] {
        return MessageCategoryManager.shared.getContextualSuggestions(
            for: category,
            personalityType: personalityType
        )
    }
    
    /// Check if user has sufficient data for advanced messaging features
    var canUseAdvancedMessaging: Bool {
        return partnerName != nil && personalityType != nil
    }
    
    /// Generate a message context from user data
    func createMessageContext(
        timeOfDay: TimeOfDay = .current,
        recentContext: String? = nil,
        specialOccasion: String? = nil
    ) -> ComprehensiveGeneratedMessage.MessageContext {
        return ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: timeOfDay,
            relationshipDuration: relationshipDuration,
            recentContext: recentContext,
            specialOccasion: specialOccasion,
            userPersonalityType: personalityType,
            partnerName: partnerName
        )
    }
}

// MARK: - Response Conversion Extensions

extension MessageGenerationResponse {
    /// Convert to ComprehensiveMessageResponse
    func toComprehensiveResponse(
        with context: ComprehensiveMessageResponse.MessageGenerationContext
    ) -> ComprehensiveMessageResponse {
        let comprehensiveMessages = messages.map { message in
            message.toComprehensiveMessage()
        }
        
        let metadata = ComprehensiveMessageResponse.ResponseMetadata(
            generatedAt: generatedAt ?? Date(),
            processingTimeMs: nil,
            totalAlternatives: messages.count,
            personalityMatchConfidence: nil,
            canGenerateMore: true,
            generationsRemaining: nil,
            suggestedCategory: nil
        )
        
        return ComprehensiveMessageResponse(
            success: success,
            messages: comprehensiveMessages,
            context: context,
            error: error,
            metadata: metadata
        )
    }
}

// MARK: - Category Selection Helpers

struct MessageCategorySelector {
    
    /// Get the best category for current context
    static func getBestCategory(
        for user: DomainUser,
        timeOfDay: TimeOfDay = .current,
        recentActivity: String? = nil
    ) -> MessageCategoryType {
        
        let timeCategories = MessageCategoryManager.shared.getCategoriesForTime(timeOfDay)
        let userCategories = user.recommendedMessageCategories
        
        // Find intersection of time-appropriate and user-recommended categories
        let intersectionCategories = timeCategories.filter { timeCategory in
            userCategories.contains { userCategory in
                userCategory.id == timeCategory.id
            }
        }
        
        // Return the highest priority category from the intersection
        if let bestCategory = intersectionCategories.sorted(by: { $0.priority > $1.priority }).first {
            return bestCategory.type
        }
        
        // Fallback to time-appropriate categories
        if let timeCategory = timeCategories.first {
            return timeCategory.type
        }
        
        // Final fallback
        return .dailyCheckins
    }
    
    /// Get categories filtered by user preferences and current context
    static func getContextualCategories(
        for user: DomainUser,
        excluding: [MessageCategoryType] = [],
        limit: Int = 5
    ) -> [DetailedMessageCategory] {
        
        let allRecommended = user.recommendedMessageCategories
        let timeAppropriate = user.timeAppropriateCategories
        
        // Combine and prioritize
        var categoriesWithScore: [(category: DetailedMessageCategory, score: Int)] = []
        
        for category in allRecommended {
            var score = category.priority
            
            // Boost score if time-appropriate
            if timeAppropriate.contains(where: { $0.id == category.id }) {
                score += 5
            }
            
            // Reduce score if excluded
            if excluding.contains(category.type) {
                score -= 10
            }
            
            categoriesWithScore.append((category: category, score: score))
        }
        
        return categoriesWithScore
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.category }
    }
}

// MARK: - Message Statistics and Analytics

extension Array where Element == ComprehensiveGeneratedMessage {
    /// Get usage statistics for message collection
    var messageStatistics: MessageStatistics {
        return MessageStatistics(messages: self)
    }
}

struct MessageStatistics {
    let totalMessages: Int
    let averageWordCount: Double
    let mostUsedCategory: MessageCategoryType?
    let mostUsedTone: MessageTone?
    let averageImpact: Double
    let categoryDistribution: [MessageCategoryType: Int]
    let toneDistribution: [MessageTone: Int]
    
    init(messages: [ComprehensiveGeneratedMessage]) {
        self.totalMessages = messages.count
        
        if messages.isEmpty {
            self.averageWordCount = 0
            self.mostUsedCategory = nil
            self.mostUsedTone = nil
            self.averageImpact = 0
            self.categoryDistribution = [:]
            self.toneDistribution = [:]
            return
        }
        
        // Calculate averages
        self.averageWordCount = Double(messages.map { $0.metadata.wordCount }.reduce(0, +)) / Double(messages.count)
        self.averageImpact = Double(messages.map { $0.estimatedImpact.numericValue }.reduce(0, +)) / Double(messages.count)
        
        // Calculate distributions
        var categoryCount: [MessageCategoryType: Int] = [:]
        var toneCount: [MessageTone: Int] = [:]
        
        for message in messages {
            categoryCount[message.category, default: 0] += 1
            toneCount[message.tone, default: 0] += 1
        }
        
        self.categoryDistribution = categoryCount
        self.toneDistribution = toneCount
        
        // Find most used
        self.mostUsedCategory = categoryCount.max { $0.value < $1.value }?.key
        self.mostUsedTone = toneCount.max { $0.value < $1.value }?.key
    }
}