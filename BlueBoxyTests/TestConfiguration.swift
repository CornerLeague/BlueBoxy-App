//
//  TestConfiguration.swift
//  BlueBoxyTests
//
//  Test configuration utilities and shared test setup for comprehensive testing
//

import Foundation
import Testing
@testable import BlueBoxy

/// Test configuration and utilities for messaging tests
enum TestConfiguration {
    
    /// Standard test timeout for async operations
    static let standardTimeout: TimeInterval = 5.0
    
    /// Extended timeout for performance tests
    static let extendedTimeout: TimeInterval = 10.0
    
    /// Test message categories for consistent testing
    static let testCategories: [MessageCategory] = [
        .romantic, .appreciation, .support, .daily, .celebration
    ]
    
    /// Test message tones for consistent testing  
    static let testTones: [MessageTone] = [
        .affectionate, .grateful, .encouraging, .uplifting, .romantic, .supportive
    ]
    
    /// Sample test contexts for message generation
    static let testContexts = [
        "After a wonderful dinner together",
        "Celebrating our anniversary", 
        "Starting a new week together",
        "After a difficult day at work",
        "Just thinking of you"
    ]
    
    /// Sample recipient information for testing
    static let sampleRecipient = RecipientInfo(
        name: "TestPartner",
        relationship: .partner,
        preferences: ["romantic dinners", "morning texts", "surprise gestures"]
    )
    
    /// Sample user profile for testing
    static let sampleUserProfile = UserProfile(
        communicationStyle: .warm,
        relationshipLength: .longTerm,
        preferredTones: [.affectionate, .romantic, .supportive]
    )
    
    /// Create a test message generation request
    static func createTestRequest(
        category: MessageCategory = .romantic,
        tone: MessageTone = .affectionate,
        context: String = "Test context"
    ) -> MessageGenerationRequest {
        return MessageGenerationRequest(
            category: category,
            tone: tone,
            context: context,
            specialOccasion: nil,
            recipientInfo: sampleRecipient,
            userProfile: sampleUserProfile
        )
    }
    
    /// Create a sample generated message for testing
    static func createSampleMessage(
        id: String = UUID().uuidString,
        content: String = "Sample test message",
        category: MessageCategory = .romantic,
        tone: MessageTone = .affectionate
    ) -> GeneratedMessage {
        return GeneratedMessage(
            id: id,
            content: content,
            category: category,
            tone: tone,
            impactScore: 8.5,
            context: "Test context",
            specialOccasion: nil,
            generatedAt: Date()
        )
    }
    
    /// Create multiple sample messages for testing
    static func createSampleMessages(count: Int = 3) -> [GeneratedMessage] {
        return (1...count).map { index in
            createSampleMessage(
                content: "Sample message \(index)",
                category: testCategories.randomElement() ?? .romantic,
                tone: testTones.randomElement() ?? .affectionate
            )
        }
    }
    
    /// Mock OpenAI API response for testing
    static func createMockOpenAIResponse(messages: [String]) -> String {
        let choices = messages.enumerated().map { index, message in
            """
            {
                "index": \(index),
                "message": {
                    "role": "assistant",
                    "content": "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
                },
                "finish_reason": "stop"
            }
            """
        }.joined(separator: ",")
        
        return """
        {
            "id": "chatcmpl-test-\(UUID().uuidString)",
            "object": "chat.completion",
            "created": \(Int(Date().timeIntervalSince1970)),
            "model": "gpt-3.5-turbo",
            "choices": [\(choices)],
            "usage": {
                "prompt_tokens": 50,
                "completion_tokens": \(messages.count * 20),
                "total_tokens": \(50 + messages.count * 20)
            }
        }
        """
    }
    
    /// Clear all test data from UserDefaults
    static func clearTestData() {
        let defaults = UserDefaults.standard
        let testKeys = defaults.dictionaryRepresentation().keys.filter { 
            $0.hasPrefix("blueboxy_") || $0.hasPrefix("test_")
        }
        
        for key in testKeys {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize()
    }
    
    /// Wait for condition to be true within timeout
    static func waitForCondition(
        timeout: TimeInterval = standardTimeout,
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return false
    }
    
    /// Generate test environment variables for UI testing
    static var testEnvironmentVariables: [String: String] {
        return [
            "UI_TESTING": "1",
            "ENABLE_MOCK_API": "1",
            "MOCK_GENERATION_DELAY": "0.5",
            "DISABLE_ANALYTICS": "1",
            "TEST_MODE": "1"
        ]
    }
}

/// Test helpers for common operations
enum TestHelpers {
    
    /// Assert that two dates are approximately equal (within 1 second)
    static func assertDatesEqual(_ date1: Date?, _ date2: Date?, accuracy: TimeInterval = 1.0) -> Bool {
        guard let date1 = date1, let date2 = date2 else {
            return date1 == nil && date2 == nil
        }
        return abs(date1.timeIntervalSince(date2)) <= accuracy
    }
    
    /// Assert that a message has required properties
    static func assertValidMessage(_ message: GeneratedMessage) -> Bool {
        return !message.id.isEmpty &&
               !message.content.isEmpty &&
               message.impactScore >= 0 &&
               message.impactScore <= 10 &&
               message.generatedAt <= Date()
    }
    
    /// Assert that storage statistics are valid
    static func assertValidStorageStats(_ stats: StorageStatistics) -> Bool {
        return stats.totalMessages >= 0 &&
               stats.favoriteCount >= 0 &&
               stats.favoriteCount <= stats.totalMessages &&
               stats.estimatedSizeBytes >= 0 &&
               stats.categoryCounts.values.allSatisfy { $0 >= 0 }
    }
    
    /// Create a temporary storage service for testing
    static func createTestStorageService() -> MessageStorageService {
        let service = MessageStorageService()
        // Clear any existing test data
        TestConfiguration.clearTestData()
        return service
    }
    
    /// Create a test messaging service with mock protocol
    static func createTestMessagingService() -> (service: EnhancedMessagingService, mockProtocol: MockURLProtocol) {
        let mockProtocol = MockURLProtocol()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        let storageService = createTestStorageService()
        let messagingService = EnhancedMessagingService(
            storageService: storageService,
            session: URLSession(configuration: config)
        )
        
        return (service: messagingService, mockProtocol: mockProtocol)
    }
}

/// Performance testing utilities
enum PerformanceTestHelpers {
    
    /// Measure execution time of an async operation
    static func measureTime<T>(operation: () async throws -> T) async throws -> (result: T, timeElapsed: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let timeElapsed = Date().timeIntervalSince(startTime)
        return (result: result, timeElapsed: timeElapsed)
    }
    
    /// Assert that an operation completes within expected time
    static func assertPerformance<T>(
        expectedTime: TimeInterval,
        tolerance: TimeInterval = 0.5,
        operation: () async throws -> T
    ) async throws -> T {
        let (result, timeElapsed) = try await measureTime(operation: operation)
        
        let maxAcceptableTime = expectedTime + tolerance
        if timeElapsed > maxAcceptableTime {
            throw TestError.performanceExpectationFailed(
                expected: expectedTime,
                actual: timeElapsed,
                tolerance: tolerance
            )
        }
        
        return result
    }
    
    /// Create load test by running multiple concurrent operations
    static func performLoadTest(
        operationCount: Int,
        concurrencyLimit: Int = 10,
        operation: @escaping () async throws -> Void
    ) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            var activeCount = 0
            var pendingCount = operationCount
            
            while pendingCount > 0 || activeCount > 0 {
                // Start new tasks up to concurrency limit
                while activeCount < concurrencyLimit && pendingCount > 0 {
                    group.addTask {
                        try await operation()
                    }
                    activeCount += 1
                    pendingCount -= 1
                }
                
                // Wait for at least one task to complete
                do {
                    try await group.next()
                    activeCount -= 1
                } catch {
                    // Continue with other operations even if some fail
                    activeCount -= 1
                }
            }
        }
    }
}

/// Custom test errors
enum TestError: Error, CustomStringConvertible {
    case performanceExpectationFailed(expected: TimeInterval, actual: TimeInterval, tolerance: TimeInterval)
    case mockSetupFailed(String)
    case dataValidationFailed(String)
    case timeoutExpired(TimeInterval)
    
    var description: String {
        switch self {
        case .performanceExpectationFailed(let expected, let actual, let tolerance):
            return "Performance expectation failed: expected \(expected)±\(tolerance)s, actual \(actual)s"
        case .mockSetupFailed(let message):
            return "Mock setup failed: \(message)"
        case .dataValidationFailed(let message):
            return "Data validation failed: \(message)"
        case .timeoutExpired(let timeout):
            return "Test timeout expired after \(timeout) seconds"
        }
    }
}