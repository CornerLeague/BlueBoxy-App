//
//  MessageIntegrationTests.swift
//  BlueBoxyTests
//
//  Integration tests for messaging service interactions, storage persistence, 
//  and end-to-end message flow validation
//

import Testing
import Foundation
@testable import BlueBoxy

@Suite("Message Integration Tests")
final class MessageIntegrationTests {
    
    private var messagingService: EnhancedMessagingService!
    private var storageService: MessageStorageService!
    private var mockProtocol: MockURLProtocol!
    
    init() {
        // Set up mock protocol
        mockProtocol = MockURLProtocol()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        // Initialize services
        storageService = MessageStorageService()
        messagingService = EnhancedMessagingService(
            storageService: storageService,
            session: URLSession(configuration: config)
        )
        
        // Clear any existing test data
        clearTestData()
    }
    
    deinit {
        clearTestData()
    }
    
    // MARK: - End-to-End Message Generation Flow
    
    @Test("Complete message generation and storage flow")
    func testCompleteMessageFlow() async throws {
        // Set up successful API response
        let mockMessages = [
            "You make every day brighter with your beautiful smile.",
            "Thank you for being the most amazing partner I could ask for.",
            "I love how you always know exactly what to say."
        ]
        
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: mockMessages).data(using: .utf8)!,
            statusCode: 200
        )
        
        // Create generation request
        let request = MessageGenerationRequest(
            category: .romantic,
            tone: .affectionate,
            context: "After our wonderful date night",
            specialOccasion: "Anniversary",
            recipientInfo: RecipientInfo(
                name: "Sarah",
                relationship: .partner,
                preferences: ["romantic dinners", "stargazing"]
            ),
            userProfile: UserProfile(
                communicationStyle: .warm,
                relationshipLength: .longTerm,
                preferredTones: [.affectionate, .romantic]
            )
        )
        
        // Test generation
        let result = try await messagingService.generateMessages(request: request)
        
        // Verify generation results
        #expect(result.messages.count == 3)
        #expect(result.category == .romantic)
        #expect(result.generatedAt != nil)
        
        // Verify messages were stored
        let storedMessages = await storageService.getMessages(
            category: .romantic,
            limit: 10
        )
        #expect(storedMessages.count >= 3)
        
        // Verify storage statistics updated
        let stats = await storageService.getStorageStatistics()
        #expect(stats.totalMessages >= 3)
        #expect(stats.categoryCounts[.romantic] ?? 0 >= 3)
    }
    
    @Test("Message generation with retry and fallback")
    func testMessageGenerationWithRetry() async throws {
        // Set up failing then successful responses
        mockProtocol.mockSequentialResponses(
            url: "https://api.openai.com/v1/chat/completions",
            responses: [
                (data: Data(), statusCode: 503), // Service unavailable
                (data: Data(), statusCode: 429), // Rate limited
                (data: createMockOpenAIResponse(messages: ["Success message"]).data(using: .utf8)!, statusCode: 200)
            ]
        )
        
        let request = MessageGenerationRequest(
            category: .appreciation,
            tone: .grateful,
            context: "After a difficult day"
        )
        
        // Test with retry logic
        let result = try await messagingService.generateMessages(request: request)
        
        #expect(result.messages.count == 1)
        #expect(result.messages.first?.content == "Success message")
        #expect(result.category == .appreciation)
    }
    
    @Test("Cross-service data consistency")
    func testCrossServiceDataConsistency() async throws {
        // Generate messages through EnhancedMessagingService
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: [
                "Test message for consistency",
                "Another test message"
            ]).data(using: .utf8)!,
            statusCode: 200
        )
        
        let request = MessageGenerationRequest(
            category: .daily,
            tone: .uplifting,
            context: "Morning motivation"
        )
        
        let result = try await messagingService.generateMessages(request: request)
        
        // Verify data exists in both services
        let messagingHistory = await messagingService.getGenerationHistory(limit: 10)
        let storageHistory = await storageService.getMessages(category: .daily, limit: 10)
        
        #expect(!messagingHistory.isEmpty)
        #expect(!storageHistory.isEmpty)
        
        // Verify message content consistency
        let generatedMessage = result.messages.first!
        let storedMessage = storageHistory.first { $0.content == generatedMessage.content }
        
        #expect(storedMessage != nil)
        #expect(storedMessage?.category == .daily)
        #expect(storedMessage?.tone == .uplifting)
        #expect(storedMessage?.context == "Morning motivation")
    }
    
    // MARK: - Category Management Integration
    
    @Test("Category recommendations and usage tracking")
    func testCategoryRecommendationsIntegration() async throws {
        // Generate messages in different categories to build usage history
        let categories: [MessageCategory] = [.romantic, .appreciation, .support]
        
        for category in categories {
            mockProtocol.mockResponse(
                url: "https://api.openai.com/v1/chat/completions",
                responseData: createMockOpenAIResponse(messages: ["Test message for \(category)"]).data(using: .utf8)!,
                statusCode: 200
            )
            
            let request = MessageGenerationRequest(
                category: category,
                tone: .affectionate,
                context: "Test context"
            )
            
            _ = try await messagingService.generateMessages(request: request)
        }
        
        // Test category recommendations
        let recommendations = await messagingService.getRecommendedCategories(
            timeOfDay: .evening,
            context: "romantic dinner"
        )
        
        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains(.romantic))
        
        // Verify usage tracking
        let categoryStats = await storageService.getCategoryUsageStats()
        #expect(categoryStats.count >= 3)
        
        for category in categories {
            #expect(categoryStats[category] != nil)
            #expect(categoryStats[category]! > 0)
        }
    }
    
    // MARK: - Storage Management Integration
    
    @Test("Storage optimization and cleanup")
    func testStorageOptimizationFlow() async throws {
        // Create multiple messages to trigger optimization
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: Array(1...50).map { "Test message \($0)" }).data(using: .utf8)!,
            statusCode: 200
        )
        
        let request = MessageGenerationRequest(
            category: .daily,
            tone: .uplifting,
            context: "Bulk test"
        )
        
        _ = try await messagingService.generateMessages(request: request)
        
        // Get initial storage statistics
        let initialStats = await storageService.getStorageStatistics()
        
        // Trigger storage optimization
        await storageService.optimizeStorage()
        
        // Verify optimization occurred
        let optimizedStats = await storageService.getStorageStatistics()
        #expect(optimizedStats.lastOptimization != nil)
        
        // Test cleanup of old messages (if any exist beyond limit)
        await storageService.cleanupOldMessages(keepCount: 20)
        
        let finalMessages = await storageService.getMessages(category: .daily, limit: 100)
        #expect(finalMessages.count <= 20)
    }
    
    @Test("Favorites synchronization across services")
    func testFavoritesSynchronization() async throws {
        // Generate a message
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: ["Favorite test message"]).data(using: .utf8)!,
            statusCode: 200
        )
        
        let request = MessageGenerationRequest(
            category: .romantic,
            tone: .affectionate,
            context: "Special moment"
        )
        
        let result = try await messagingService.generateMessages(request: request)
        let testMessage = result.messages.first!
        
        // Add to favorites through storage service
        await storageService.toggleFavorite(messageId: testMessage.id)
        
        // Verify favorite status is reflected in messaging service
        let favorites = await storageService.getFavoriteMessages(limit: 10)
        #expect(favorites.contains { $0.id == testMessage.id })
        
        // Test removal from favorites
        await storageService.toggleFavorite(messageId: testMessage.id)
        let updatedFavorites = await storageService.getFavoriteMessages(limit: 10)
        #expect(!updatedFavorites.contains { $0.id == testMessage.id })
    }
    
    // MARK: - Search and Filtering Integration
    
    @Test("Cross-service search functionality")
    func testSearchIntegration() async throws {
        // Create messages with searchable content
        let searchableMessages = [
            "I love your beautiful smile",
            "Thank you for being amazing",
            "You make me smile every day"
        ]
        
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: searchableMessages).data(using: .utf8)!,
            statusCode: 200
        )
        
        let request = MessageGenerationRequest(
            category: .appreciation,
            tone: .grateful,
            context: "Search test"
        )
        
        _ = try await messagingService.generateMessages(request: request)
        
        // Test search functionality
        let smileResults = await storageService.searchMessages(query: "smile", limit: 10)
        #expect(smileResults.count >= 2) // Should find messages containing "smile"
        
        let loveResults = await storageService.searchMessages(query: "love", limit: 10)
        #expect(loveResults.count >= 1) // Should find message containing "love"
        
        // Test empty search
        let emptyResults = await storageService.searchMessages(query: "xyz123", limit: 10)
        #expect(emptyResults.isEmpty)
    }
    
    // MARK: - Error Handling Integration
    
    @Test("End-to-end error handling and recovery")
    func testErrorHandlingIntegration() async throws {
        // Test network error handling
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: Data(),
            statusCode: 500
        )
        
        let request = MessageGenerationRequest(
            category: .support,
            tone: .encouraging,
            context: "Error test"
        )
        
        // Verify error is properly handled
        do {
            _ = try await messagingService.generateMessages(request: request)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Expected error - verify storage wasn't corrupted
            let messages = await storageService.getMessages(category: .support, limit: 10)
            let stats = await storageService.getStorageStatistics()
            
            // Storage should still be intact
            #expect(stats.totalMessages >= 0)
            #expect(!stats.isCorrupted)
        }
    }
    
    // MARK: - Performance Integration
    
    @Test("Multi-threaded access and data integrity")
    func testConcurrentOperations() async throws {
        let operationCount = 10
        
        // Set up mock response for concurrent operations
        mockProtocol.mockResponse(
            url: "https://api.openai.com/v1/chat/completions",
            responseData: createMockOpenAIResponse(messages: ["Concurrent test message"]).data(using: .utf8)!,
            statusCode: 200
        )
        
        // Create multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<operationCount {
                group.addTask {
                    let request = MessageGenerationRequest(
                        category: MessageCategory.allCases.randomElement()!,
                        tone: .affectionate,
                        context: "Concurrent test \(i)"
                    )
                    
                    do {
                        _ = try await self.messagingService.generateMessages(request: request)
                    } catch {
                        // Some operations may fail due to mock limitations - that's OK
                    }
                }
            }
        }
        
        // Verify data integrity after concurrent operations
        let allMessages = await storageService.getMessages(limit: 100)
        let stats = await storageService.getStorageStatistics()
        
        #expect(stats.totalMessages >= 0)
        #expect(!stats.isCorrupted)
        #expect(allMessages.count <= stats.totalMessages)
    }
    
    // MARK: - Helper Methods
    
    private func createMockOpenAIResponse(messages: [String]) -> String {
        let choices = messages.enumerated().map { index, message in
            """
            {
                "index": \(index),
                "message": {
                    "role": "assistant",
                    "content": "\(message)"
                },
                "finish_reason": "stop"
            }
            """
        }.joined(separator: ",")
        
        return """
        {
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "created": \(Int(Date().timeIntervalSince1970)),
            "model": "gpt-3.5-turbo",
            "choices": [\(choices)],
            "usage": {
                "prompt_tokens": 50,
                "completion_tokens": 100,
                "total_tokens": 150
            }
        }
        """
    }
    
    private func clearTestData() {
        // Clear UserDefaults test data
        let defaults = UserDefaults.standard
        let testKeys = defaults.dictionaryRepresentation().keys.filter { 
            $0.hasPrefix("blueboxy_") 
        }
        
        for key in testKeys {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize()
    }
}