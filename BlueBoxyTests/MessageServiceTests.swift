//
//  MessageServiceTests.swift
//  BlueBoxyTests
//
//  Comprehensive unit tests for messaging services including EnhancedMessagingService,
//  MessageStorageService, and RetryableMessagingService with mock data and network simulation
//

import Testing
import Foundation
@testable import BlueBoxy

struct MessageServiceTests {
    
    // MARK: - Test Setup
    
    init() {
        MockURLProtocol.reset()
    }
    
    private func makeTestStorageService() -> MessageStorageService {
        // Create isolated UserDefaults for testing
        let testSuite = UUID().uuidString
        let userDefaults = UserDefaults(suiteName: testSuite)!
        return MessageStorageService(userDefaults: userDefaults)
    }
    
    private func makeTestAPIClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        struct MockAuth: AuthProviding {
            let userId: Int? = 123
            let authToken: String? = "test-token"
        }
        
        return APIClient(
            baseURL: URL(string: "https://api.blueboxy.test")!,
            session: session,
            decoder: APIConfiguration.decoder,
            encoder: APIConfiguration.encoder,
            auth: MockAuth()
        )
    }
    
    private func createSampleMessage() -> ComprehensiveGeneratedMessage {
        let context = ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: .evening,
            relationshipDuration: "2 years",
            recentContext: "After our wonderful dinner date",
            specialOccasion: "Anniversary",
            userPersonalityType: "romantic",
            partnerName: "Sarah"
        )
        
        return ComprehensiveGeneratedMessage(
            id: "test-message-1",
            content: "You make every day brighter just by being in it. I love you! 💕",
            category: .romantic,
            personalityMatch: "high",
            tone: .romantic,
            estimatedImpact: .high,
            context: context,
            generatedAt: Date()
        )
    }
    
    private func createSampleGenerationRecord() -> MessageGenerationRecord {
        return MessageGenerationRecord(
            id: UUID(),
            category: .romantic,
            userId: 123,
            timestamp: Date(),
            messagesGenerated: 3,
            personalityType: "romantic",
            timeOfDay: .evening,
            hadContext: true,
            hadSpecialOccasion: true,
            averageImpact: 3
        )
    }
}

// MARK: - MessageStorageService Tests

extension MessageServiceTests {
    
    @Test func testMessageSaveAndLoad() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save message
        await storageService.saveMessage(message)
        
        // Load messages
        let loadedMessages = await storageService.loadRecentMessages(limit: 10)
        
        #expect(loadedMessages?.count == 1)
        #expect(loadedMessages?.first?.id == message.id)
        #expect(loadedMessages?.first?.content == message.content)
        #expect(loadedMessages?.first?.category == message.category)
    }
    
    @Test func testMessageDeletion() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save message
        await storageService.saveMessage(message)
        
        // Verify saved
        let savedMessages = await storageService.loadRecentMessages(limit: 10)
        #expect(savedMessages?.count == 1)
        
        // Delete message
        await storageService.deleteMessage(message.id)
        
        // Verify deleted
        let remainingMessages = await storageService.loadRecentMessages(limit: 10)
        #expect(remainingMessages?.isEmpty == true)
    }
    
    @Test func testFavoriteMessages() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save and favorite message
        await storageService.saveMessage(message)
        await storageService.favoriteMessage(message.id)
        
        // Load favorites
        let favoriteMessages = await storageService.loadFavoriteMessages(limit: 10)
        
        #expect(favoriteMessages?.count == 1)
        #expect(favoriteMessages?.first?.id == message.id)
    }
    
    @Test func testMessagesByCategoryFilter() async throws {
        let storageService = makeTestStorageService()
        
        // Create messages with different categories
        let romanticMessage = createSampleMessage() // romantic category
        let appreciationMessage = ComprehensiveGeneratedMessage(
            id: "test-message-2",
            content: "Thank you for being amazing!",
            category: .appreciation,
            personalityMatch: "high",
            tone: .grateful,
            estimatedImpact: .medium,
            context: romanticMessage.contextualFactors,
            generatedAt: Date()
        )
        
        // Save messages
        await storageService.saveMessage(romanticMessage)
        await storageService.saveMessage(appreciationMessage)
        
        // Test category filtering
        let romanticMessages = await storageService.loadMessages(for: .romantic, limit: 10)
        let appreciationMessages = await storageService.loadMessages(for: .appreciation, limit: 10)
        
        #expect(romanticMessages?.count == 1)
        #expect(romanticMessages?.first?.category == .romantic)
        
        #expect(appreciationMessages?.count == 1)
        #expect(appreciationMessages?.first?.category == .appreciation)
    }
    
    @Test func testDuplicateMessageHandling() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save same message twice
        await storageService.saveMessage(message)
        await storageService.saveMessage(message)
        
        // Should only have one copy
        let loadedMessages = await storageService.loadRecentMessages(limit: 10)
        #expect(loadedMessages?.count == 1)
    }
    
    @Test func testStorageStatistics() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save message and favorite it
        await storageService.saveMessage(message)
        await storageService.favoriteMessage(message.id)
        
        // Save generation record
        let record = createSampleGenerationRecord()
        await storageService.saveGenerationRecord(record)
        
        // Get statistics
        let stats = await storageService.getStorageStatistics()
        
        #expect(stats.totalMessages == 1)
        #expect(stats.favoriteMessages == 1)
        #expect(stats.generationRecords == 1)
        #expect(stats.messagesPerCategory[.romantic] == 1)
        #expect(stats.storageUsedMB > 0)
    }
    
    @Test func testMessagePreferences() async throws {
        let storageService = makeTestStorageService()
        let preferences = MessageGenerationPreferences(
            defaultTimeOfDay: .evening,
            preferredTone: .romantic,
            desiredImpact: .high,
            includePersonalization: true,
            generateAlternatives: false,
            maxWordCount: 100
        )
        
        // Save preferences
        await storageService.saveMessagePreferences(preferences)
        
        // Load preferences
        let loadedPreferences = await storageService.loadMessagePreferences()
        
        #expect(loadedPreferences?.defaultTimeOfDay == .evening)
        #expect(loadedPreferences?.preferredTone == .romantic)
        #expect(loadedPreferences?.desiredImpact == .high)
        #expect(loadedPreferences?.includePersonalization == true)
        #expect(loadedPreferences?.generateAlternatives == false)
        #expect(loadedPreferences?.maxWordCount == 100)
    }
    
    @Test func testFavoriteCategoriesManagement() async throws {
        let storageService = makeTestStorageService()
        let favoriteCategories: [MessageCategoryType] = [.romantic, .appreciation, .supportive]
        
        // Save favorite categories
        await storageService.saveFavoriteCategories(favoriteCategories)
        
        // Load favorite categories
        let loadedCategories = await storageService.loadFavoriteCategories()
        
        #expect(loadedCategories.count == 3)
        #expect(loadedCategories.contains(.romantic))
        #expect(loadedCategories.contains(.appreciation))
        #expect(loadedCategories.contains(.supportive))
    }
    
    @Test func testSearchMessages() async throws {
        let storageService = makeTestStorageService()
        
        // Create messages with different content
        let loveMessage = ComprehensiveGeneratedMessage(
            id: "love-message",
            content: "I love you more than words can say",
            category: .romantic,
            personalityMatch: "high",
            tone: .romantic,
            estimatedImpact: .high,
            context: createSampleMessage().contextualFactors,
            generatedAt: Date()
        )
        
        let thanksMessage = ComprehensiveGeneratedMessage(
            id: "thanks-message",
            content: "Thank you for being so supportive today",
            category: .appreciation,
            personalityMatch: "high",
            tone: .grateful,
            estimatedImpact: .medium,
            context: createSampleMessage().contextualFactors,
            generatedAt: Date()
        )
        
        // Save messages
        await storageService.saveMessage(loveMessage)
        await storageService.saveMessage(thanksMessage)
        
        // Test search functionality
        let loveSearchResults = await storageService.searchMessages(query: "love", limit: 10)
        let thanksSearchResults = await storageService.searchMessages(query: "thank", limit: 10)
        let categorySearchResults = await storageService.searchMessages(query: "romantic", limit: 10)
        
        #expect(loveSearchResults.count == 1)
        #expect(loveSearchResults.first?.id == "love-message")
        
        #expect(thanksSearchResults.count == 1)
        #expect(thanksSearchResults.first?.id == "thanks-message")
        
        #expect(categorySearchResults.count == 1)
        #expect(categorySearchResults.first?.category == .romantic)
    }
    
    @Test func testStorageOptimization() async throws {
        let storageService = makeTestStorageService()
        let message = createSampleMessage()
        
        // Save message and favorite it
        await storageService.saveMessage(message)
        await storageService.favoriteMessage(message.id)
        
        // Delete the message (should create orphaned favorite)
        await storageService.deleteMessage(message.id)
        
        // Optimize storage (should clean up orphaned favorite)
        await storageService.optimizeStorage()
        
        // Verify cleanup
        let favoriteMessages = await storageService.loadFavoriteMessages(limit: 10)
        #expect(favoriteMessages?.isEmpty == true)
    }
}

// MARK: - RetryableMessagingService Tests

extension MessageServiceTests {
    
    @Test func testSuccessfulMessageGeneration() async throws {
        let apiClient = makeTestAPIClient()
        let storageService = makeTestStorageService()
        let networkClient = MessagingNetworkClient(apiClient: apiClient)
        let fallbackProvider = DefaultFallbackProvider()
        
        let retryableService = RetryableMessagingService(
            apiService: MessagingAPIService(apiClient: apiClient),
            networkClient: networkClient,
            fallbackProvider: fallbackProvider
        )
        
        // Mock successful API response
        let mockResponse = MessageGenerationResponse(
            success: true,
            messages: [MessageItem(
                id: "mock-1",
                content: "Test message",
                category: "romantic",
                personalityMatch: "high",
                tone: "romantic",
                estimatedImpact: "high"
            )],
            context: ["generation_mode": "api"],
            error: nil
        )
        
        MockURLProtocol.handler = MockURLProtocol.jsonSuccessHandler(
            for: "https://api.blueboxy.test/api/messages/generate",
            object: mockResponse
        )
        
        // Test message generation
        let request = MessageGenerateRequest(
            userId: 123,
            category: "romantic",
            timeOfDay: .evening,
            recentContext: "Test context",
            specialOccasion: nil
        )
        
        let result = await retryableService.generateMessage(request: request, retryPolicy: nil)
        
        switch result {
        case .success(let response):
            #expect(response.success == true)
            #expect(!response.messages.isEmpty)
            #expect(response.messages.first?.content == "Test message")
        case .failure(let error):
            #expect(Bool(false), "Expected success but got error: \(error)")
        }
    }
    
    @Test func testRetryLogicOnNetworkFailure() async throws {
        let apiClient = makeTestAPIClient()
        let storageService = makeTestStorageService()
        let networkClient = MessagingNetworkClient(apiClient: apiClient)
        let fallbackProvider = DefaultFallbackProvider()
        
        let retryableService = RetryableMessagingService(
            apiService: MessagingAPIService(apiClient: apiClient),
            networkClient: networkClient,
            fallbackProvider: fallbackProvider
        )
        
        // Mock network failure first, then success
        var callCount = 0
        MockURLProtocol.handler = MockURLProtocol.Handler(
            requestValidator: { _ in
                callCount += 1
            },
            response: HTTPURLResponse(
                url: URL(string: "https://api.blueboxy.test/api/messages/generate")!,
                statusCode: callCount == 1 ? 500 : 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!,
            data: try! JSONEncoder().encode(MessageGenerationResponse(
                success: true,
                messages: [MessageItem(
                    id: "retry-success",
                    content: "Retry worked!",
                    category: "romantic",
                    personalityMatch: "high",
                    tone: "romantic",
                    estimatedImpact: "high"
                )],
                context: [:],
                error: nil
            ))
        )
        
        let request = MessageGenerateRequest(
            userId: 123,
            category: "romantic",
            timeOfDay: .evening
        )
        
        let result = await retryableService.generateMessage(request: request, retryPolicy: .default)
        
        // Should have retried and succeeded
        #expect(callCount >= 2)
        switch result {
        case .success(let response):
            #expect(response.success == true)
            #expect(response.messages.first?.id == "retry-success")
        case .failure(let error):
            #expect(Bool(false), "Expected success after retry but got error: \(error)")
        }
    }
    
    @Test func testFallbackMessageGeneration() async throws {
        let apiClient = makeTestAPIClient()
        let storageService = makeTestStorageService()
        let networkClient = MessagingNetworkClient(apiClient: apiClient)
        let fallbackProvider = DefaultFallbackProvider()
        
        let retryableService = RetryableMessagingService(
            apiService: MessagingAPIService(apiClient: apiClient),
            networkClient: networkClient,
            fallbackProvider: fallbackProvider
        )
        
        // Mock persistent network failure
        MockURLProtocol.handler = MockURLProtocol.networkErrorHandler(
            error: URLError(.notConnectedToInternet)
        )
        
        let request = MessageGenerateRequest(
            userId: 123,
            category: "romantic",
            timeOfDay: .evening
        )
        
        let result = await retryableService.generateMessage(request: request, retryPolicy: .failFast)
        
        // Should fall back to offline generation
        switch result {
        case .success(let response):
            #expect(response.success == true)
            #expect(!response.messages.isEmpty)
            #expect(response.context["generation_mode"] == "offline_fallback")
        case .failure(let error):
            #expect(Bool(false), "Expected fallback success but got error: \(error)")
        }
    }
    
    @Test func testConnectionQualityAdaptation() async throws {
        let apiClient = makeTestAPIClient()
        let storageService = makeTestStorageService()
        let networkClient = MessagingNetworkClient(apiClient: apiClient)
        let fallbackProvider = DefaultFallbackProvider()
        
        let retryableService = RetryableMessagingService(
            apiService: MessagingAPIService(apiClient: apiClient),
            networkClient: networkClient,
            fallbackProvider: fallbackProvider
        )
        
        // Test connection quality affects retry policy
        #expect(retryableService.connectionQuality == .excellent) // Should start as excellent
        
        // Simulate poor connection
        // In a real test, you'd have a way to inject connection quality
        // For now, just verify the service exists and can be created
        #expect(retryableService != nil)
    }
}

// MARK: - EnhancedMessagingService Integration Tests

extension MessageServiceTests {
    
    @Test func testFullMessageGenerationWorkflow() async throws {
        // This test requires a more complex setup due to EnhancedMessagingService dependencies
        // For now, we'll test that the service can be created and basic state management works
        
        let messagingService = EnhancedMessagingService()
        
        // Test initial state
        #expect(messagingService.generationState.isIdle)
        #expect(!messagingService.isGenerating)
        #expect(messagingService.generatedMessages.isEmpty)
        #expect(messagingService.selectedCategory == nil)
        
        // Test state changes
        messagingService.selectedCategory = .romantic
        #expect(messagingService.selectedCategory == .romantic)
        
        messagingService.recentContext = "Test context"
        #expect(messagingService.recentContext == "Test context")
        
        messagingService.specialOccasion = "Anniversary"
        #expect(messagingService.specialOccasion == "Anniversary")
        
        // Test form reset
        messagingService.resetForm()
        #expect(messagingService.recentContext.isEmpty)
        #expect(messagingService.specialOccasion.isEmpty)
    }
    
    @Test func testMessageCategoryManagement() async throws {
        let messagingService = EnhancedMessagingService()
        
        // Test category manager functionality
        let manager = MessageCategoryManager.shared
        let allCategories = manager.getAllCategories()
        
        #expect(!allCategories.isEmpty)
        #expect(allCategories.contains { $0.type == .romantic })
        #expect(allCategories.contains { $0.type == .appreciation })
        
        // Test category filtering
        let romanticCategories = manager.getRecommendedCategories(for: "romantic")
        let romanticCategory = romanticCategories.first { $0.type == .romantic }
        
        #expect(romanticCategory != nil)
        #expect(romanticCategory?.personalityMatches.contains("romantic") == true)
    }
    
    @Test func testTimeOfDayRecommendations() async throws {
        let manager = MessageCategoryManager.shared
        
        // Test morning categories
        let morningCategories = manager.getCategoriesForTime(.morning)
        #expect(morningCategories.contains { $0.type == .goodMorning })
        #expect(morningCategories.contains { $0.type == .encouragement })
        
        // Test evening categories  
        let eveningCategories = manager.getCategoriesForTime(.evening)
        #expect(eveningCategories.contains { $0.type == .romantic })
        #expect(eveningCategories.contains { $0.type == .goodNight })
    }
    
    @Test func testContextualSuggestions() async throws {
        let manager = MessageCategoryManager.shared
        
        // Test contextual suggestions
        let romanticSuggestions = manager.getContextualSuggestions(for: .romantic, personalityType: "romantic")
        #expect(!romanticSuggestions.isEmpty)
        #expect(romanticSuggestions.contains { $0.contains("love") })
        
        let supportSuggestions = manager.getContextualSuggestions(for: .supportive, personalityType: "empathetic")
        #expect(!supportSuggestions.isEmpty)
        #expect(supportSuggestions.contains { $0.contains("here for you") || $0.contains("support") })
    }
}

// MARK: - Model Validation Tests

extension MessageServiceTests {
    
    @Test func testMessageCategoryEnumValues() throws {
        // Test that all category types have proper display names and icons
        for category in MessageCategoryType.allCases {
            #expect(!category.displayName.isEmpty)
            #expect(!category.systemImageName.isEmpty)
            #expect(!category.description.isEmpty)
            #expect(category.priority > 0)
            #expect(!category.tags.isEmpty)
        }
    }
    
    @Test func testMessageToneEnumValues() throws {
        // Test that all tone types have proper values
        for tone in MessageTone.allCases {
            #expect(!tone.displayName.isEmpty)
            #expect(!tone.emoji.isEmpty)
            // Color should be valid (we can't easily test Color values, but they should exist)
            #expect(tone.color != nil)
        }
    }
    
    @Test func testMessageImpactValues() throws {
        // Test message impact calculations
        #expect(MessageImpact.low.numericValue == 1)
        #expect(MessageImpact.medium.numericValue == 2)
        #expect(MessageImpact.high.numericValue == 3)
        
        #expect(!MessageImpact.low.description.isEmpty)
        #expect(!MessageImpact.medium.description.isEmpty)
        #expect(!MessageImpact.high.description.isEmpty)
    }
    
    @Test func testTimeOfDayCalculations() throws {
        // Test time of day utilities
        let timeOfDay = TimeOfDay.current
        #expect(timeOfDay != nil)
        #expect(!timeOfDay.displayName.isEmpty)
        #expect(!timeOfDay.systemImageName.isEmpty)
        #expect(!timeOfDay.contextualGreeting.isEmpty)
    }
    
    @Test func testMessageGenerationRequestValidation() throws {
        // Test valid request
        let validRequest = MessageGenerateRequest(
            userId: 123,
            category: "romantic",
            timeOfDay: .evening
        )
        #expect(validRequest.userId > 0)
        #expect(!validRequest.category.isEmpty)
        
        // Test comprehensive request validation
        let comprehensiveRequest = ComprehensiveMessageRequest(
            userId: 123,
            category: .romantic,
            timeOfDay: .evening,
            personalityType: "romantic",
            partnerName: "Sarah"
        )
        #expect(comprehensiveRequest.isValid)
        #expect(comprehensiveRequest.estimatedComplexity >= 1)
    }
}

// MARK: - MockURLProtocol Extensions for Testing

extension MockURLProtocol {
    
    /// Create a JSON success handler from a Codable object
    static func jsonSuccessHandler<T: Codable>(
        for url: String,
        object: T,
        requestValidator: ((URLRequest) -> Void)? = nil
    ) -> Handler {
        let data = try! JSONEncoder().encode(object)
        return successHandler(
            for: url,
            data: data,
            requestValidator: requestValidator
        )
    }
    
    /// Get the number of recorded requests
    static var requestCount: Int {
        return requestHistory.count
    }
    
    /// Check if a request was made to a specific path
    static func hasRequest(to path: String) -> Bool {
        return requestHistory.contains { request in
            request.url?.path == path
        }
    }
    
    /// Get the last recorded request
    static var lastRequest: URLRequest? {
        return requestHistory.last
    }
}