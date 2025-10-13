//
//  MessageStorageServiceProtocol.swift
//  BlueBoxy
//
//  Protocol for message storage service that provides local persistence
//  and caching capabilities for the messaging feature.
//

import Foundation

// MARK: - Message Storage Service Protocol

protocol MessageStorageServiceProtocol {
    
    // MARK: - Message Storage
    
    /// Save a single generated message
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async
    
    /// Save multiple generated messages with context
    func saveGeneratedMessages(_ messages: [ComprehensiveGeneratedMessage], context: ComprehensiveMessageResponse.MessageGenerationContext) async
    
    /// Delete a message by ID
    func deleteMessage(_ messageId: String) async
    
    /// Mark a message as favorite
    func favoriteMessage(_ messageId: String) async
    
    /// Mark a message as shared
    func markMessageAsShared(_ messageId: String) async
    
    // MARK: - Message Retrieval
    
    /// Load recent messages from storage
    func loadRecentMessages(limit: Int) async -> [ComprehensiveGeneratedMessage]?
    
    /// Load messages by category
    func loadMessages(for category: MessageCategoryType, limit: Int) async -> [ComprehensiveGeneratedMessage]?
    
    /// Load favorite messages
    func loadFavoriteMessages(limit: Int) async -> [ComprehensiveGeneratedMessage]?
    
    /// Load message by ID
    func loadMessage(id: String) async -> ComprehensiveGeneratedMessage?
    
    // MARK: - Generation History
    
    /// Save generation context and metadata
    func saveGenerationRecord(_ record: MessageGenerationRecord) async
    
    /// Load recent generation history
    func loadGenerationHistory(limit: Int) async -> [MessageGenerationRecord]
    
    /// Clear old generation records
    func cleanupOldRecords(olderThan: Date) async
    
    // MARK: - Categories and Preferences
    
    /// Save favorite categories
    func saveFavoriteCategories(_ categories: [MessageCategoryType]) async
    
    /// Load favorite categories
    func loadFavoriteCategories() async -> [MessageCategoryType]
    
    /// Save user preferences for message generation
    func saveMessagePreferences(_ preferences: MessageGenerationPreferences) async
    
    /// Load user preferences
    func loadMessagePreferences() async -> MessageGenerationPreferences?
    
    // MARK: - Cache Management
    
    /// Clear all stored messages
    func clearAllMessages() async
    
    /// Clear messages older than specified date
    func clearMessagesOlderThan(_ date: Date) async
    
    /// Get storage statistics
    func getStorageStatistics() async -> MessageStorageStatistics
    
    /// Optimize storage (cleanup, compress, etc.)
    func optimizeStorage() async
}

// MARK: - Supporting Models

struct MessageGenerationPreferences: Codable {
    let defaultTimeOfDay: TimeOfDay?
    let preferredTone: MessageTone?
    let desiredImpact: MessageImpact?
    let includePersonalization: Bool
    let generateAlternatives: Bool
    let maxWordCount: Int?
    let contextualHintsEnabled: Bool
    let smartSuggestionsEnabled: Bool
    
    init(
        defaultTimeOfDay: TimeOfDay? = nil,
        preferredTone: MessageTone? = nil,
        desiredImpact: MessageImpact? = nil,
        includePersonalization: Bool = true,
        generateAlternatives: Bool = true,
        maxWordCount: Int? = nil,
        contextualHintsEnabled: Bool = true,
        smartSuggestionsEnabled: Bool = true
    ) {
        self.defaultTimeOfDay = defaultTimeOfDay
        self.preferredTone = preferredTone
        self.desiredImpact = desiredImpact
        self.includePersonalization = includePersonalization
        self.generateAlternatives = generateAlternatives
        self.maxWordCount = maxWordCount
        self.contextualHintsEnabled = contextualHintsEnabled
        self.smartSuggestionsEnabled = smartSuggestionsEnabled
    }
    
    static let `default` = MessageGenerationPreferences()
}

struct MessageStorageStatistics {
    let totalMessages: Int
    let favoriteMessages: Int
    let messagesPerCategory: [MessageCategoryType: Int]
    let storageUsedMB: Double
    let oldestMessageDate: Date?
    let newestMessageDate: Date?
    let generationRecords: Int
    let averageMessagesPerGeneration: Double
}

// MARK: - Default Implementation Extensions

extension MessageStorageServiceProtocol {
    
    /// Save a single message with default parameters
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async {
        await saveGeneratedMessages([message], context: createDefaultContext(for: message))
    }
    
    /// Load recent messages with default limit
    func loadRecentMessages() async -> [ComprehensiveGeneratedMessage]? {
        return await loadRecentMessages(limit: 20)
    }
    
    /// Load messages for category with default limit
    func loadMessages(for category: MessageCategoryType) async -> [ComprehensiveGeneratedMessage]? {
        return await loadMessages(for: category, limit: 10)
    }
    
    /// Load favorite messages with default limit
    func loadFavoriteMessages() async -> [ComprehensiveGeneratedMessage]? {
        return await loadFavoriteMessages(limit: 50)
    }
    
    /// Load generation history with default limit
    func loadGenerationHistory() async -> [MessageGenerationRecord] {
        return await loadGenerationHistory(limit: 100)
    }
    
    // MARK: - Private Helpers
    
    private func createDefaultContext(for message: ComprehensiveGeneratedMessage) -> ComprehensiveMessageResponse.MessageGenerationContext {
        return ComprehensiveMessageResponse.MessageGenerationContext(
            category: message.category.rawValue,
            personalityType: message.personalityMatch,
            partnerName: message.contextualFactors.partnerName ?? "partner",
            timeOfDay: message.contextualFactors.timeOfDay,
            relationshipStage: message.contextualFactors.relationshipDuration,
            contextualFactors: [
                "generated_at": ISO8601DateFormatter().string(from: message.generatedAt),
                "tone": message.tone.rawValue,
                "impact": message.estimatedImpact.rawValue
            ]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let messagesSaved = Notification.Name("messagesSaved")
    static let messagesDeleted = Notification.Name("messagesDeleted")
    static let messageFavorited = Notification.Name("messageFavorited")
    static let messageStorageCleared = Notification.Name("messageStorageCleared")
}