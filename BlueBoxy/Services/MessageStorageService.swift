//
//  MessageStorageService.swift
//  BlueBoxy
//
//  Comprehensive local storage service for messaging features using UserDefaults
//  with efficient caching, data compression, and analytics support
//

import Foundation
import SwiftUI

// MARK: - Message Storage Service Implementation

final class MessageStorageService: MessageStorageServiceProtocol, ObservableObject {
    
    // MARK: - Constants
    
    private enum StorageKeys {
        static let messages = "blueboxy_messages"
        static let generationHistory = "blueboxy_generation_history"
        static let favoriteCategories = "blueboxy_favorite_categories"
        static let messagePreferences = "blueboxy_message_preferences"
        static let lastCleanupDate = "blueboxy_last_cleanup"
        static let storageVersion = "blueboxy_storage_version"
    }
    
    private let currentStorageVersion = 1
    private let maxStoredMessages = 1000
    private let maxGenerationRecords = 500
    private let cleanupIntervalDays = 7
    private let maxMessageAgeDays = 90
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    // Use actor-based serialization instead of DispatchQueue for async methods
    private actor StorageActor {
        func execute<T>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
            return try await operation()
        }
    }
    private let storageActor = StorageActor()
    
    @Published private(set) var storageStatistics = MessageStorageStatistics(
        totalMessages: 0,
        favoriteMessages: 0,
        messagesPerCategory: [:],
        storageUsedMB: 0.0,
        oldestMessageDate: nil,
        newestMessageDate: nil,
        generationRecords: 0,
        averageMessagesPerGeneration: 0.0
    )
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Configure JSON handling
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        // Migrate storage if needed
        Task {
            await migrateStorageIfNeeded()
            await performPeriodicCleanup()
            await updateStorageStatistics()
        }
    }
    
    // MARK: - Message Storage
    
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.saveGeneratedMessages([message], context: self.createDefaultContext(for: message))
            }
            
            group.addTask {
                await self.postNotification(.messagesSaved, userInfo: ["messageId": message.id])
            }
        }
    }
    
    func saveGeneratedMessages(_ messages: [ComprehensiveGeneratedMessage], context: ComprehensiveMessageResponse.MessageGenerationContext) async {
        await storageActor.execute {
            do {
                // Load existing messages
                var existingMessages = await self.loadAllStoredMessages()
                
                // Add new messages at the beginning
                existingMessages.insert(contentsOf: messages, at: 0)
                
                // Remove duplicates (prefer newer versions)
                existingMessages = self.removeDuplicates(from: existingMessages)
                
                // Trim to max count
                if existingMessages.count > self.maxStoredMessages {
                    existingMessages = Array(existingMessages.prefix(self.maxStoredMessages))
                }
                
                // Save back to storage
                let data = try self.encoder.encode(existingMessages)
                self.userDefaults.set(data, forKey: StorageKeys.messages)
                
                // Save generation record
                await self.saveGenerationRecordInternal(
                    messages: messages,
                    context: context
                )
                
                // Update statistics
                await self.updateStorageStatistics()
                
                print("📱 Saved \(messages.count) messages to local storage")
                
            } catch {
                print("❌ Failed to save messages: \(error)")
            }
        }
    }
    
    func deleteMessage(_ messageId: String) async {
        await storageActor.execute {
            do {
                var existingMessages = await self.loadAllStoredMessages()
                existingMessages.removeAll { $0.id == messageId }
                
                let data = try self.encoder.encode(existingMessages)
                self.userDefaults.set(data, forKey: StorageKeys.messages)
                
                await self.updateStorageStatistics()
                await self.postNotification(.messagesDeleted, userInfo: ["messageId": messageId])
                
                print("🗑️ Deleted message: \(messageId)")
                
            } catch {
                print("❌ Failed to delete message: \(error)")
            }
        }
    }
    
    func favoriteMessage(_ messageId: String) async {
        await storageActor.execute {
            do {
                var existingMessages = await self.loadAllStoredMessages()
                
                if let index = existingMessages.firstIndex(where: { $0.id == messageId }) {
                    // Create updated message (since ComprehensiveGeneratedMessage doesn't have isFavorited)
                    // For this implementation, we'll track favorites separately
                    await self.addToFavorites(messageId)
                    await self.postNotification(.messageFavorited, userInfo: ["messageId": messageId])
                    
                    print("⭐ Favorited message: \(messageId)")
                }
                
            } catch {
                print("❌ Failed to favorite message: \(error)")
            }
        }
    }
    
    func markMessageAsShared(_ messageId: String) async {
        // This method doesn't need async operations, so we can simplify it
        await storageActor.execute {
            // Track shared messages in a separate set for analytics
            var sharedMessages = self.loadSharedMessageIds()
            sharedMessages.insert(messageId)
            
            let data = try? self.encoder.encode(Array(sharedMessages))
            self.userDefaults.set(data, forKey: "blueboxy_shared_messages")
            
            print("📤 Marked message as shared: \(messageId)")
        }
    }
    
    // MARK: - Message Retrieval
    
    func loadRecentMessages(limit: Int = 20) async -> [ComprehensiveGeneratedMessage]? {
        return await storageActor.execute {
            let allMessages = await self.loadAllStoredMessages()
            return Array(allMessages.prefix(limit))
        }
    }
    
    func loadMessages(for category: MessageCategoryType, limit: Int = 10) async -> [ComprehensiveGeneratedMessage]? {
        return await storageActor.execute {
            let allMessages = await self.loadAllStoredMessages()
            let categoryMessages = allMessages.filter { $0.category == category }
            return Array(categoryMessages.prefix(limit))
        }
    }
    
    func loadFavoriteMessages(limit: Int = 50) async -> [ComprehensiveGeneratedMessage]? {
        return await storageActor.execute {
            let favoriteIds = await self.loadFavoriteMessageIds()
            let allMessages = await self.loadAllStoredMessages()
            
            let favoriteMessages = allMessages.filter { favoriteIds.contains($0.id) }
            return Array(favoriteMessages.prefix(limit))
        }
    }
    
    func loadMessage(id: String) async -> ComprehensiveGeneratedMessage? {
        return await storageActor.execute {
            let allMessages = await self.loadAllStoredMessages()
            return allMessages.first { $0.id == id }
        }
    }
    
    // MARK: - Generation History
    
    func saveGenerationRecord(_ record: MessageGenerationRecord) async {
        await storageActor.execute {
            do {
                var existingRecords = await self.loadAllGenerationRecords()
                existingRecords.insert(record, at: 0)
                
                // Trim to max count
                if existingRecords.count > self.maxGenerationRecords {
                    existingRecords = Array(existingRecords.prefix(self.maxGenerationRecords))
                }
                
                let data = try self.encoder.encode(existingRecords)
                self.userDefaults.set(data, forKey: StorageKeys.generationHistory)
                
                await self.updateStorageStatistics()
                
            } catch {
                print("❌ Failed to save generation record: \(error)")
            }
        }
    }
    
    func loadGenerationHistory(limit: Int = 100) async -> [MessageGenerationRecord] {
        return await storageActor.execute {
            let allRecords = await self.loadAllGenerationRecords()
            return Array(allRecords.prefix(limit))
        }
    }
    
    func cleanupOldRecords(olderThan date: Date) async {
        await storageActor.execute {
            do {
                // Clean up generation records
                var generationRecords = await self.loadAllGenerationRecords()
                generationRecords.removeAll { $0.timestamp < date }
                
                let recordData = try self.encoder.encode(generationRecords)
                self.userDefaults.set(recordData, forKey: StorageKeys.generationHistory)
                
                // Clean up old messages
                await self.clearMessagesOlderThan(date)
                
                print("🧹 Cleaned up records older than \(date)")
                
            } catch {
                print("❌ Failed to cleanup old records: \(error)")
            }
        }
    }
    
    // MARK: - Categories and Preferences
    
    func saveFavoriteCategories(_ categories: [MessageCategoryType]) async {
        await storageActor.execute {
            do {
                let data = try self.encoder.encode(categories)
                self.userDefaults.set(data, forKey: StorageKeys.favoriteCategories)
                
                print("💾 Saved \(categories.count) favorite categories")
                
            } catch {
                print("❌ Failed to save favorite categories: \(error)")
            }
        }
    }
    
    func loadFavoriteCategories() async -> [MessageCategoryType] {
        return await storageActor.execute {
            guard let data = self.userDefaults.data(forKey: StorageKeys.favoriteCategories) else {
                return []
            }
            
            do {
                return try self.decoder.decode([MessageCategoryType].self, from: data)
            } catch {
                print("❌ Failed to load favorite categories: \(error)")
                return []
            }
        }
    }
    
    func saveMessagePreferences(_ preferences: MessageGenerationPreferences) async {
        await storageActor.execute {
            do {
                let data = try self.encoder.encode(preferences)
                self.userDefaults.set(data, forKey: StorageKeys.messagePreferences)
                
                print("⚙️ Saved message preferences")
                
            } catch {
                print("❌ Failed to save message preferences: \(error)")
            }
        }
    }
    
    func loadMessagePreferences() async -> MessageGenerationPreferences? {
        return await storageActor.execute {
            guard let data = self.userDefaults.data(forKey: StorageKeys.messagePreferences) else {
                return MessageGenerationPreferences.default
            }
            
            do {
                return try self.decoder.decode(MessageGenerationPreferences.self, from: data)
            } catch {
                print("❌ Failed to load message preferences: \(error)")
                return MessageGenerationPreferences.default
            }
        }
    }
    
    // MARK: - Cache Management
    
    func clearAllMessages() async {
        await storageActor.execute {
            self.userDefaults.removeObject(forKey: StorageKeys.messages)
            self.userDefaults.removeObject(forKey: "blueboxy_favorite_message_ids")
            self.userDefaults.removeObject(forKey: "blueboxy_shared_messages")
            
            await self.updateStorageStatistics()
            await self.postNotification(.messageStorageCleared, userInfo: nil)
            
            print("🗑️ Cleared all messages from storage")
        }
    }
    
    func clearMessagesOlderThan(_ date: Date) async {
        await storageActor.execute {
            do {
                var existingMessages = await self.loadAllStoredMessages()
                let originalCount = existingMessages.count
                
                existingMessages.removeAll { $0.generatedAt < date }
                
                let data = try self.encoder.encode(existingMessages)
                self.userDefaults.set(data, forKey: StorageKeys.messages)
                
                await self.updateStorageStatistics()
                
                let removedCount = originalCount - existingMessages.count
                print("🗑️ Removed \(removedCount) old messages from storage")
                
            } catch {
                print("❌ Failed to clear old messages: \(error)")
            }
        }
    }
    
    func getStorageStatistics() async -> MessageStorageStatistics {
        await updateStorageStatistics()
        return storageStatistics
    }
    
    func optimizeStorage() async {
        await storageActor.execute {
            await self.performPeriodicCleanup()
            await self.compactStorage()
            await self.updateStorageStatistics()
            
            print("⚡ Storage optimization completed")
        }
    }
    
    // MARK: - Private Storage Helpers
    
    private func loadAllStoredMessages() async -> [ComprehensiveGeneratedMessage] {
        // Since this is a private helper method, we can make it synchronous
        guard let data = userDefaults.data(forKey: StorageKeys.messages) else {
            return []
        }
        
        do {
            return try decoder.decode([ComprehensiveGeneratedMessage].self, from: data)
        } catch {
            print("❌ Failed to load stored messages: \(error)")
            return []
        }
    }
    
    private func loadAllGenerationRecords() async -> [MessageGenerationRecord] {
        // Since this is a private helper method, we can make it synchronous
        guard let data = userDefaults.data(forKey: StorageKeys.generationHistory) else {
            return []
        }
        
        do {
            return try decoder.decode([MessageGenerationRecord].self, from: data)
        } catch {
            print("❌ Failed to load generation records: \(error)")
            return []
        }
    }
    
    private func loadFavoriteMessageIds() async -> Set<String> {
        // Since this is a private helper method, we can make it synchronous
        guard let data = userDefaults.data(forKey: "blueboxy_favorite_message_ids") else {
            return Set()
        }
        
        do {
            let array = try decoder.decode([String].self, from: data)
            return Set(array)
        } catch {
            return Set()
        }
    }
    
    private func loadSharedMessageIds() -> Set<String> {
        guard let data = userDefaults.data(forKey: "blueboxy_shared_messages") else {
            return Set()
        }
        
        do {
            let array = try decoder.decode([String].self, from: data)
            return Set(array)
        } catch {
            return Set()
        }
    }
    
    private func addToFavorites(_ messageId: String) async {
        await storageActor.execute {
            do {
                var favorites = await self.loadFavoriteMessageIds()
                favorites.insert(messageId)
                
                let data = try self.encoder.encode(Array(favorites))
                self.userDefaults.set(data, forKey: "blueboxy_favorite_message_ids")
                
            } catch {
                print("❌ Failed to add to favorites: \(error)")
            }
        }
    }
    
    private func removeDuplicates(from messages: [ComprehensiveGeneratedMessage]) -> [ComprehensiveGeneratedMessage] {
        var seen = Set<String>()
        return messages.compactMap { message in
            guard !seen.contains(message.id) else { return nil }
            seen.insert(message.id)
            return message
        }
    }
    
    private func saveGenerationRecordInternal(
        messages: [ComprehensiveGeneratedMessage],
        context: ComprehensiveMessageResponse.MessageGenerationContext
    ) async {
        guard !messages.isEmpty else { return }
        
        let record = MessageGenerationRecord(
            id: UUID(),
            category: messages[0].category,
            userId: 0, // Would be set from current user context
            timestamp: Date(),
            messagesGenerated: messages.count,
            personalityType: context.personalityType,
            timeOfDay: context.timeOfDay,
            hadContext: !context.contextualFactors.isEmpty,
            hadSpecialOccasion: context.contextualFactors["specialOccasion"] != nil,
            averageImpact: messages.map { $0.estimatedImpact.numericValue }.reduce(0, +) / messages.count
        )
        
        await saveGenerationRecord(record)
    }
    
    // MARK: - Migration and Cleanup
    
    private func migrateStorageIfNeeded() async {
        let storedVersion = userDefaults.integer(forKey: StorageKeys.storageVersion)
        
        if storedVersion < currentStorageVersion {
            await performMigration(from: storedVersion, to: currentStorageVersion)
            userDefaults.set(currentStorageVersion, forKey: StorageKeys.storageVersion)
        }
    }
    
    private func performMigration(from oldVersion: Int, to newVersion: Int) async {
        print("📦 Migrating storage from version \(oldVersion) to \(newVersion)")
        
        // For now, just clear old incompatible data
        if oldVersion == 0 {
            // First time setup - no migration needed
            return
        }
        
        // Future migrations would go here
    }
    
    private func performPeriodicCleanup() async {
        let lastCleanupDate = userDefaults.object(forKey: StorageKeys.lastCleanupDate) as? Date ?? Date.distantPast
        let daysSinceCleanup = Date().timeIntervalSince(lastCleanupDate) / (24 * 60 * 60)
        
        if daysSinceCleanup >= Double(cleanupIntervalDays) {
            let cutoffDate = Date().addingTimeInterval(-Double(maxMessageAgeDays * 24 * 60 * 60))
            await cleanupOldRecords(olderThan: cutoffDate)
            
            userDefaults.set(Date(), forKey: StorageKeys.lastCleanupDate)
        }
    }
    
    private func compactStorage() async {
        // Remove orphaned favorite/shared references
        let allMessages = await loadAllStoredMessages()
        let validMessageIds = Set(allMessages.map { $0.id })
        
        // Clean favorite IDs
        let favoriteIds = await loadFavoriteMessageIds()
        let validFavoriteIds = favoriteIds.intersection(validMessageIds)
        
        if favoriteIds.count != validFavoriteIds.count {
            do {
                let data = try encoder.encode(Array(validFavoriteIds))
                userDefaults.set(data, forKey: "blueboxy_favorite_message_ids")
            } catch {
                print("❌ Failed to compact favorite IDs: \(error)")
            }
        }
        
        // Clean shared IDs
        let sharedIds = loadSharedMessageIds()
        let validSharedIds = sharedIds.intersection(validMessageIds)
        
        if sharedIds.count != validSharedIds.count {
            do {
                let data = try encoder.encode(Array(validSharedIds))
                userDefaults.set(data, forKey: "blueboxy_shared_messages")
            } catch {
                print("❌ Failed to compact shared IDs: \(error)")
            }
        }
    }
    
    // MARK: - Statistics
    
    @MainActor
    private func updateStorageStatistics() async {
        let allMessages = await loadAllStoredMessages()
        let favoriteIds = await loadFavoriteMessageIds()
        let generationRecords = await loadAllGenerationRecords()
        
        // Calculate category distribution
        let categoryDistribution = Dictionary(grouping: allMessages, by: { $0.category })
            .mapValues { $0.count }
        
        // Calculate storage size
        let storageSize = calculateStorageSize()
        
        // Find date range
        let sortedMessages = allMessages.sorted { $0.generatedAt < $1.generatedAt }
        let oldestDate = sortedMessages.first?.generatedAt
        let newestDate = sortedMessages.last?.generatedAt
        
        // Calculate average messages per generation
        let avgMessagesPerGeneration = generationRecords.isEmpty ? 0.0 : 
            Double(allMessages.count) / Double(generationRecords.count)
        
        storageStatistics = MessageStorageStatistics(
            totalMessages: allMessages.count,
            favoriteMessages: favoriteIds.count,
            messagesPerCategory: categoryDistribution,
            storageUsedMB: storageSize,
            oldestMessageDate: oldestDate,
            newestMessageDate: newestDate,
            generationRecords: generationRecords.count,
            averageMessagesPerGeneration: avgMessagesPerGeneration
        )
    }
    
    private func calculateStorageSize() -> Double {
        let keys = [
            StorageKeys.messages,
            StorageKeys.generationHistory,
            StorageKeys.favoriteCategories,
            StorageKeys.messagePreferences,
            "blueboxy_favorite_message_ids",
            "blueboxy_shared_messages"
        ]
        
        var totalSize = 0
        for key in keys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        return Double(totalSize) / (1024.0 * 1024.0) // Convert to MB
    }
    
    // MARK: - Notifications
    
    private func postNotification(_ name: Notification.Name, userInfo: [String: Any]?) async {
        await MainActor.run {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }
    
    // MARK: - Default Context Creation
    
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

// MARK: - Convenience Extensions

extension MessageStorageService {
    
    /// Quick save for a single message with minimal context
    func quickSave(_ message: ComprehensiveGeneratedMessage) async {
        await saveMessage(message)
    }
    
    /// Bulk save for multiple messages
    func bulkSave(_ messages: [ComprehensiveGeneratedMessage]) async {
        guard !messages.isEmpty else { return }
        
        let context = createDefaultContext(for: messages[0])
        await saveGeneratedMessages(messages, context: context)
    }
    
    /// Get messages by multiple categories
    func loadMessages(forCategories categories: [MessageCategoryType], limit: Int = 20) async -> [ComprehensiveGeneratedMessage] {
        let allMessages = await loadAllStoredMessages()
        let categorySet = Set(categories)
        
        let filtered = allMessages.filter { categorySet.contains($0.category) }
        return Array(filtered.prefix(limit))
    }
    
    /// Search messages by content
    func searchMessages(query: String, limit: Int = 20) async -> [ComprehensiveGeneratedMessage] {
        let allMessages = await loadAllStoredMessages()
        let lowercaseQuery = query.lowercased()
        
        let matches = allMessages.filter { message in
            message.content.lowercased().contains(lowercaseQuery) ||
            message.category.displayName.lowercased().contains(lowercaseQuery) ||
            message.tone.displayName.lowercased().contains(lowercaseQuery)
        }
        
        return Array(matches.prefix(limit))
    }
}

// MARK: - Preview and Testing Support

#if DEBUG
extension MessageStorageService {
    
    static let preview: MessageStorageService = {
        let service = MessageStorageService(userDefaults: UserDefaults(suiteName: "preview")!)
        return service
    }()
    
    /// Generate sample data for testing and previews
    func generateSampleData() async {
        let sampleMessages = createSampleMessages()
        await bulkSave(sampleMessages)
        
        let sampleCategories: [MessageCategoryType] = [.romantic, .appreciation, .dailyCheckins]
        await saveFavoriteCategories(sampleCategories)
        
        await saveMessagePreferences(.default)
    }
    
    private func createSampleMessages() -> [ComprehensiveGeneratedMessage] {
        let categories: [MessageCategoryType] = [.romantic, .appreciation, .playful, .support]
        let tones: [MessageTone] = [.romantic, .warm, .playful, .supportive]
        let impacts: [MessageImpact] = [.high, .medium, .low]
        
        let sampleContents = [
            "You make every day brighter just by being in it. I love you! 💕",
            "Thank you for always being my rock and supporting my dreams.",
            "Can't wait to see your beautiful smile when I get home tonight!",
            "I believe in you and know you can accomplish anything you set your mind to.",
            "Remember when we first met? I still get butterflies thinking about it."
        ]
        
        return (0..<5).map { index in
            let context = ComprehensiveGeneratedMessage.MessageContext(
                timeOfDay: .evening,
                relationshipDuration: "2 years",
                recentContext: "After a wonderful dinner date",
                specialOccasion: nil,
                userPersonalityType: "romantic",
                partnerName: "Sarah"
            )
            
            return ComprehensiveGeneratedMessage(
                id: "sample_\(index)",
                content: sampleContents[index],
                category: categories[index % categories.count],
                personalityMatch: "high",
                tone: tones[index % tones.count],
                estimatedImpact: impacts[index % impacts.count],
                context: context,
                generatedAt: Date().addingTimeInterval(-Double(index * 3600))
            )
        }
    }
}
#endif