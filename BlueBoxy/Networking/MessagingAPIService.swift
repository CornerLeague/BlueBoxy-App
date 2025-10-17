//
//  MessagingAPIService.swift
//  BlueBoxy
//
//  Messaging-specific API service that integrates with the existing APIClient architecture.
//  Handles message generation, categories, and history with comprehensive error handling.
//

import Foundation

// MARK: - Messaging API Service Protocol

protocol MessagingAPIServiceProtocol {
    func fetchMessageCategories() async throws -> MessageCategoriesResponse
    func fetchEnhancedMessageCategories() async throws -> EnhancedMessageCategoriesResponse
    func generateMessages(request: MessageGenerateRequest) async throws -> MessageGenerationResponse
    func generateComprehensiveMessages(request: ComprehensiveMessageRequest) async throws -> ComprehensiveMessageResponse
    func fetchMessageHistory(limit: Int, offset: Int) async throws -> MessageHistoryResponse
    func saveMessage(messageId: String) async throws
    func deleteMessage(messageId: String) async throws
    func favoriteMessage(messageId: String) async throws
}

// MARK: - Messaging API Service Implementation

@MainActor
final class MessagingAPIService: MessagingAPIServiceProtocol {
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let retryStrategy: RetryStrategy
    private let cache: ResponseCache?
    
    // MARK: - Configuration
    
    private let defaultTimeout: TimeInterval = 45 // Extended for AI processing
    private let maxRetries: Int = 3
    
    // MARK: - Initialization
    
    init(
        apiClient: APIClient = .shared,
        retryStrategy: RetryStrategy = .exponentialBackoff(maxAttempts: 3),
        cache: ResponseCache? = FileResponseCache()
    ) {
        self.apiClient = apiClient
        self.retryStrategy = retryStrategy
        self.cache = cache
    }
    
    // MARK: - Message Categories
    
    func fetchMessageCategories() async throws -> MessageCategoriesResponse {
        let endpoint = Endpoint.messagesCategories()
        
        // Try cache first for categories (they change infrequently)
        if let cached = await getCachedResponse(for: "message_categories") as MessageCategoriesResponse? {
            return cached
        }
        
        do {
            let response: MessageCategoriesResponse = try await apiClient.request(endpoint)
            
            // Cache successful response
            await setCachedResponse(response, for: "message_categories", ttl: 3600) // 1 hour
            
            return response
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    func fetchEnhancedMessageCategories() async throws -> EnhancedMessageCategoriesResponse {
        let response = try await fetchMessageCategories()
        return EnhancedMessageCategoriesResponse(from: response)
    }
    
    // MARK: - Message Generation
    
    func generateMessages(request: MessageGenerateRequest) async throws -> MessageGenerationResponse {
        // Validate request
        guard request.isValid else {
            throw MessagingAPIError.invalidRequest("Message generation request validation failed")
        }
        
        let endpoint = Endpoint.messagesGenerate(request)
        
        do {
            let response: MessageGenerationResponse = try await executeWithRetry {
                try await self.apiClient.request(endpoint)
            }
            
            // Log successful generation for analytics
            logMessageGeneration(request: request, response: response)
            
            return response
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    func generateComprehensiveMessages(request: ComprehensiveMessageRequest) async throws -> ComprehensiveMessageResponse {
        // Validate comprehensive request
        guard request.isValid else {
            throw MessagingAPIError.invalidRequest("Comprehensive message request validation failed")
        }
        
        // Convert to backend-compatible request
        let backendRequest = createBackendRequest(from: request)
        let endpoint = Endpoint.messagesGenerateEnhanced(backendRequest)
        
        do {
            let backendResponse: MessageGenerationResponse = try await executeWithRetry {
                try await self.apiClient.request(endpoint)
            }
            
            // Convert response to comprehensive format
            let comprehensiveResponse = try convertToComprehensiveResponse(
                backendResponse,
                originalRequest: request
            )
            
            // Log successful generation
            logComprehensiveMessageGeneration(request: request, response: comprehensiveResponse)
            
            return comprehensiveResponse
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    // MARK: - Message History
    
    func fetchMessageHistory(limit: Int = 50, offset: Int = 0) async throws -> MessageHistoryResponse {
        let endpoint = Endpoint.messagesHistory(limit: limit, offset: offset)
        
        do {
            let response: MessageHistoryResponse = try await apiClient.request(endpoint)
            return response
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    // MARK: - Message Actions
    
    func saveMessage(messageId: String) async throws {
        let endpoint = Endpoint.messagesSave(messageId: messageId)
        
        do {
            try await apiClient.requestEmpty(endpoint)
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    func deleteMessage(messageId: String) async throws {
        let endpoint = Endpoint.messagesDelete(messageId: messageId)
        
        do {
            try await apiClient.requestEmpty(endpoint)
            
            // Clear any cached data that might include this message
            await clearMessageCaches()
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    func favoriteMessage(messageId: String) async throws {
        let endpoint = Endpoint.messagesFavorite(messageId: messageId)
        
        do {
            try await apiClient.requestEmpty(endpoint)
        } catch {
            throw mapMessagingError(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private func createBackendRequest(from request: ComprehensiveMessageRequest) -> EnhancedMessageGenerateRequest {
        return EnhancedMessageGenerateRequest(
            userId: request.userId,
            category: request.category.rawValue,
            timeOfDay: request.timeOfDay,
            recentContext: request.recentContext,
            specialOccasion: request.specialOccasion,
            personalityType: request.personalityType,
            partnerName: request.partnerName
        )
    }
    
    private func convertToComprehensiveResponse(
        _ backendResponse: MessageGenerationResponse,
        originalRequest: ComprehensiveMessageRequest
    ) throws -> ComprehensiveMessageResponse {
        
        let comprehensiveMessages = backendResponse.messages.map { message in
            let context = ComprehensiveGeneratedMessage.MessageContext(
                timeOfDay: originalRequest.timeOfDay,
                relationshipDuration: originalRequest.relationshipDuration,
                recentContext: originalRequest.recentContext,
                specialOccasion: originalRequest.specialOccasion,
                userPersonalityType: originalRequest.personalityType,
                partnerName: originalRequest.partnerName
            )
            
            return message.toComprehensiveMessage(context: context)
        }
        
        let responseContext = ComprehensiveMessageResponse.MessageGenerationContext(
            category: originalRequest.category.rawValue,
            personalityType: originalRequest.personalityType ?? "unknown",
            partnerName: originalRequest.partnerName ?? "partner",
            timeOfDay: originalRequest.timeOfDay,
            relationshipStage: originalRequest.relationshipDuration,
            contextualFactors: createContextualFactors(from: originalRequest)
        )
        
        let metadata = ComprehensiveMessageResponse.ResponseMetadata(
            generatedAt: Date(),
            processingTimeMs: nil,
            totalAlternatives: comprehensiveMessages.count,
            personalityMatchConfidence: calculatePersonalityMatchConfidence(comprehensiveMessages),
            canGenerateMore: true,
            generationsRemaining: nil,
            suggestedCategory: getSuggestedNextCategory(based: originalRequest.category)
        )
        
        return ComprehensiveMessageResponse(
            success: backendResponse.success,
            messages: comprehensiveMessages,
            context: responseContext,
            error: backendResponse.error,
            metadata: metadata
        )
    }
    
    private func createContextualFactors(from request: ComprehensiveMessageRequest) -> [String: String] {
        var factors: [String: String] = [:]
        
        factors["time_of_day"] = request.timeOfDay.rawValue
        factors["category"] = request.category.rawValue
        
        if let personalityType = request.personalityType {
            factors["personality_type"] = personalityType
        }
        
        if let relationshipDuration = request.relationshipDuration {
            factors["relationship_duration"] = relationshipDuration
        }
        
        if let preferredTone = request.preferredTone {
            factors["preferred_tone"] = preferredTone.rawValue
        }
        
        if let desiredImpact = request.desiredImpact {
            factors["desired_impact"] = desiredImpact.rawValue
        }
        
        factors["personalization_enabled"] = String(request.includePersonalization)
        factors["alternatives_requested"] = String(request.generateAlternatives)
        
        return factors
    }
    
    private func calculatePersonalityMatchConfidence(_ messages: [ComprehensiveGeneratedMessage]) -> Double? {
        // Simple confidence calculation based on personality match consistency
        guard !messages.isEmpty else { return nil }
        
        let personalityMatches = Set(messages.map { $0.personalityMatch.lowercased() })
        
        // Higher confidence if messages consistently match the same personality
        if personalityMatches.count == 1 {
            return 0.95
        } else if personalityMatches.count == 2 {
            return 0.75
        } else {
            return 0.60
        }
    }
    
    private func getSuggestedNextCategory(based currentCategory: MessageCategoryType) -> MessageCategoryType? {
        // Suggest complementary categories based on current selection
        switch currentCategory {
        case .romantic:
            return .appreciation
        case .playful:
            return .flirty
        case .support:
            return .encouragement
        case .dailyCheckins:
            return .thoughtful
        case .appreciation:
            return .gratitude
        default:
            return nil
        }
    }
    
    // MARK: - Retry and Error Handling
    
    private func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as APIServiceError {
                lastError = error
                
                // Don't retry certain errors
                if case .unauthorized = error {
                    throw mapMessagingError(error)
                }
                if case .forbidden = error {
                    throw mapMessagingError(error)
                }
                
                // Wait before retrying
                if attempt < maxRetries - 1 {
                    let delay = retryStrategy.backoffPolicy.delay(for: attempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    let delay = retryStrategy.backoffPolicy.delay(for: attempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw mapMessagingError(lastError ?? MessagingAPIError.unknown)
    }
    
    private func mapMessagingError(_ error: Error) -> MessagingAPIError {
        if let apiError = error as? APIServiceError {
            switch apiError {
            case .unauthorized:
                return .unauthorized
            case .forbidden:
                return .forbidden
            case .notFound:
                return .notFound
            case .badRequest(let message):
                return .invalidRequest(message)
            case .server(let message):
                return .serverError(message)
            case .network(let networkError):
                return .networkError(networkError)
            case .decoding(let decodingError):
                return .decodingError(decodingError)
            case .missingAuth:
                return .unauthorized
            case .invalidURL:
                return .invalidConfiguration("Invalid API URL")
            case .noContent:
                return .notFound
            case .unknown(let status):
                return .httpError(status)
            }
        }
        
        if let messagingError = error as? MessagingAPIError {
            return messagingError
        }
        
        return .networkError(error)
    }
    
    // MARK: - Caching Support
    
    private func getCachedResponse<T: Codable>(for key: String) async -> T? {
        guard let cache = cache else { return nil }
        
        // ResponseCache works synchronously and with Data
        guard let data = cache.load(for: key) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("📦 Cache decode error for \(key): \(error)")
            #endif
            // Remove invalid cached data
            cache.remove(for: key)
            return nil
        }
    }
    
    private func setCachedResponse<T: Codable>(_ response: T, for key: String, ttl: TimeInterval) async {
        guard let cache = cache else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            
            // ResponseCache doesn't support TTL, so we just save the data
            // TTL would need to be handled at the protocol level or with metadata
            cache.save(data, for: key)
            
            #if DEBUG
            print("💾 Cached response for key: \(key)")
            #endif
        } catch {
            #if DEBUG
            print("📦 Cache encode error for \(key): \(error)")
            #endif
        }
    }
    
    private func clearMessageCaches() async {
        guard let cache = cache else { return }
        
        // Clear message-related caches
        cache.remove(for: "message_categories")
        // Clear other message-related caches as needed
    }
    
    // MARK: - Analytics and Logging
    
    private func logMessageGeneration(request: MessageGenerateRequest, response: MessageGenerationResponse) {
        #if DEBUG
        print("📝 Message Generation:")
        print("   Category: \(request.category)")
        print("   Time: \(request.timeOfDay?.rawValue ?? "any")")
        print("   Generated: \(response.messages.count) messages")
        print("   Success: \(response.success)")
        #endif
        
        // Here you could add analytics tracking
        // Analytics.track("message_generated", properties: [...])
    }
    
    private func logComprehensiveMessageGeneration(request: ComprehensiveMessageRequest, response: ComprehensiveMessageResponse) {
        #if DEBUG
        print("🤖 Comprehensive Message Generation:")
        print("   Category: \(request.category.displayName)")
        print("   Personality: \(request.personalityType ?? "none")")
        print("   Partner: \(request.partnerName ?? "unnamed")")
        print("   Generated: \(response.messages.count) messages")
        print("   Confidence: \(response.metadata.personalityMatchConfidence ?? 0)%")
        #endif
    }
}

// MARK: - Messaging API Errors

enum MessagingAPIError: Error, LocalizedError {
    case invalidRequest(String)
    case unauthorized
    case forbidden
    case notFound
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case invalidConfiguration(String)
    case httpError(Int)
    case aiServiceUnavailable
    case quotaExceeded
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .forbidden:
            return "Access forbidden. You don't have permission for this action."
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        case .httpError(let status):
            return "HTTP error (status: \(status))"
        case .aiServiceUnavailable:
            return "AI message generation service is temporarily unavailable. Please try again later."
        case .quotaExceeded:
            return "You've reached your message generation limit. Please try again later."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .aiServiceUnavailable:
            return true
        case .httpError(let status):
            return status >= 500 || status == 429 // Retry on server errors and rate limits
        case .unknown:
            return true
        default:
            return false
        }
    }
}

// MARK: - Convenience Extensions

extension MessagingAPIService {
    
    /// Generate messages for a specific user with smart defaults
    func generateMessagesForUser(
        _ user: DomainUser,
        category: MessageCategoryType,
        recentContext: String? = nil,
        specialOccasion: String? = nil
    ) async throws -> ComprehensiveMessageResponse {
        
        let request = user.createComprehensiveMessageRequest(
            for: category,
            recentContext: recentContext,
            specialOccasion: specialOccasion
        )
        
        return try await generateComprehensiveMessages(request: request)
    }
    
    /// Get recommended categories for a user
    func getRecommendedCategories(for user: DomainUser) async throws -> [DetailedMessageCategory] {
        // Get fresh categories from server
        _ = try await fetchEnhancedMessageCategories()
        
        // Return personalized recommendations
        return user.recommendedMessageCategories
    }
    
    /// Get time-appropriate categories
    func getTimeAppropriateCategories() async throws -> [DetailedMessageCategory] {
        // Ensure we have fresh categories
        _ = try await fetchEnhancedMessageCategories()
        
        return MessageCategoryManager.shared.getCategoriesForTime(.current)
    }
}