//
//  MessagingNetworkClient.swift
//  BlueBoxy
//
//  Enhanced messaging network client that integrates with the existing CachedAPIClient
//  architecture, providing messaging-specific optimizations and retry strategies.
//

import Foundation
import Combine

// MARK: - Messaging Network Client

@MainActor
final class MessagingNetworkClient: ObservableObject {
    
    // MARK: - Dependencies
    
    private let cachedAPIClient: CachedAPIClient
    private let messagingAPIService: MessagingAPIService
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var lastError: MessagingAPIError?
    @Published var connectionState: ConnectionState = .idle
    
    // MARK: - Configuration
    
    private let cacheConfiguration: CacheConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionState {
        case idle
        case connecting
        case connected
        case disconnected
        case error(MessagingAPIError)
    }
    
    // MARK: - Initialization
    
    init(
        cachedAPIClient: CachedAPIClient = CachedAPIClient.shared,
        messagingAPIService: MessagingAPIService? = nil
    ) {
        self.cachedAPIClient = cachedAPIClient
        self.messagingAPIService = messagingAPIService ?? MessagingAPIService(apiClient: cachedAPIClient.apiClient)
        
        // Configure caching for messaging-specific needs
        self.cacheConfiguration = CacheConfiguration(
            strategy: .networkFirst,
            cache: FileResponseCache(),
            policy: CachePolicy(
                maxAge: 3600, // 1 hour for categories
                staleWhileRevalidate: true
            )
        )
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Message Categories
    
    /// Fetch message categories with intelligent caching
    func fetchMessageCategories(forceRefresh: Bool = false) async throws -> [DetailedMessageCategory] {
        isLoading = true
        connectionState = .connecting
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let response: MessageCategoriesResponse
            
            if forceRefresh {
                // Bypass cache for fresh data
                response = try await messagingAPIService.fetchMessageCategories()
            } else {
                // Use cached response with intelligent fallback
                response = try await cachedAPIClient.getCached(
                    Endpoint.messagesCategories(),
                    configuration: cacheConfiguration.with(cacheKey: "enhanced_message_categories")
                )
            }
            
            connectionState = .connected
            
            // Convert to detailed categories
            return response.categories.map { category in
                category.toDetailedCategory()
            }
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            connectionState = .error(messagingError)
            throw messagingError
        }
    }
    
    /// Get categories with user-specific recommendations
    func fetchPersonalizedCategories(for user: DomainUser, forceRefresh: Bool = false) async throws -> [DetailedMessageCategory] {
        let allCategories = try await fetchMessageCategories(forceRefresh: forceRefresh)
        
        // Apply personalization filtering
        return MessageCategorySelector.getContextualCategories(
            for: user,
            excluding: [],
            limit: 8
        )
    }
    
    // MARK: - Message Generation
    
    /// Generate messages with comprehensive error handling and retry logic
    func generateMessages(
        for user: DomainUser,
        category: MessageCategoryType,
        recentContext: String? = nil,
        specialOccasion: String? = nil,
        options: MessageGenerationOptions = .default
    ) async throws -> ComprehensiveMessageResponse {
        
        isLoading = true
        connectionState = .connecting
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Create comprehensive request
            let request = user.createComprehensiveMessageRequest(
                for: category,
                recentContext: recentContext,
                specialOccasion: specialOccasion
            )
            
            // Apply generation options
            let enhancedRequest = applyGenerationOptions(request, options: options)
            
            // Generate messages with retry logic
            let response = try await messagingAPIService.generateComprehensiveMessages(request: enhancedRequest)
            
            connectionState = .connected
            
            // Post-process response if needed
            return try await postProcessResponse(response, for: user)
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            connectionState = .error(messagingError)
            throw messagingError
        }
    }
    
    /// Generate quick messages for immediate use
    func generateQuickMessage(
        for user: DomainUser,
        category: MessageCategoryType
    ) async throws -> ComprehensiveGeneratedMessage? {
        
        let response = try await generateMessages(
            for: user,
            category: category,
            options: .quick
        )
        
        return response.messages.first
    }
    
    /// Generate multiple alternatives for a category
    func generateMessageAlternatives(
        for user: DomainUser,
        category: MessageCategoryType,
        count: Int = 5
    ) async throws -> [ComprehensiveGeneratedMessage] {
        
        let options = MessageGenerationOptions(
            maxWordCount: nil,
            includePersonalization: true,
            generateAlternatives: true,
            preferredTone: nil,
            desiredImpact: nil,
            alternativeCount: count
        )
        
        let response = try await generateMessages(
            for: user,
            category: category,
            options: options
        )
        
        return response.messages
    }
    
    // MARK: - Message History and Management
    
    /// Fetch message history with pagination
    func fetchMessageHistory(
        limit: Int = 20,
        offset: Int = 0,
        useCache: Bool = true
    ) async throws -> MessageHistoryResponse {
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if useCache {
                return try await cachedAPIClient.getCached(
                    Endpoint.messagesHistory(limit: limit, offset: offset),
                    configuration: cacheConfiguration.with(
                        cacheKey: "message_history_\(limit)_\(offset)",
                        maxAge: 300 // 5 minutes for history
                    )
                )
            } else {
                return try await messagingAPIService.fetchMessageHistory(limit: limit, offset: offset)
            }
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            throw messagingError
        }
    }
    
    /// Save message with optimistic updates
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async throws {
        do {
            try await messagingAPIService.saveMessage(messageId: message.id)
            
            // Invalidate history cache to reflect changes
            await invalidateHistoryCache()
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            throw messagingError
        }
    }
    
    /// Delete message with cache invalidation
    func deleteMessage(_ messageId: String) async throws {
        do {
            try await messagingAPIService.deleteMessage(messageId: messageId)
            
            // Invalidate relevant caches
            await invalidateHistoryCache()
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            throw messagingError
        }
    }
    
    /// Favorite message
    func favoriteMessage(_ messageId: String) async throws {
        do {
            try await messagingAPIService.favoriteMessage(messageId: messageId)
            
            // Invalidate history cache to reflect favorite status
            await invalidateHistoryCache()
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            throw messagingError
        }
    }
    
    // MARK: - Smart Recommendations
    
    /// Get smart category recommendations based on user behavior and time
    func getSmartCategoryRecommendations(for user: DomainUser) async throws -> [DetailedMessageCategory] {
        let timeAppropriate = try await messagingAPIService.getTimeAppropriateCategories()
        let userRecommended = try await messagingAPIService.getRecommendedCategories(for: user)
        
        // Combine and rank recommendations
        return MessageCategorySelector.getContextualCategories(
            for: user,
            excluding: [],
            limit: 5
        )
    }
    
    /// Get suggested message based on recent patterns
    func getSuggestedMessage(for user: DomainUser) async throws -> ComprehensiveGeneratedMessage? {
        // Analyze recent history to suggest appropriate category
        let bestCategory = MessageCategorySelector.getBestCategory(for: user)
        
        return try await generateQuickMessage(for: user, category: bestCategory)
    }
    
    // MARK: - Batch Operations
    
    /// Generate messages for multiple categories efficiently
    func batchGenerateMessages(
        for user: DomainUser,
        categories: [MessageCategoryType]
    ) async throws -> [MessageCategoryType: [ComprehensiveGeneratedMessage]] {
        
        var results: [MessageCategoryType: [ComprehensiveGeneratedMessage]] = [:]
        
        // Use TaskGroup for concurrent generation
        try await withThrowingTaskGroup(of: (MessageCategoryType, [ComprehensiveGeneratedMessage]).self) { group in
            
            for category in categories {
                group.addTask {
                    let messages = try await self.generateMessageAlternatives(
                        for: user,
                        category: category,
                        count: 3
                    )
                    return (category, messages)
                }
            }
            
            for try await (category, messages) in group {
                results[category] = messages
            }
        }
        
        return results
    }
    
    // MARK: - Private Helpers
    
    private func applyGenerationOptions(
        _ request: ComprehensiveMessageRequest,
        options: MessageGenerationOptions
    ) -> ComprehensiveMessageRequest {
        
        return ComprehensiveMessageRequest(
            userId: request.userId,
            category: request.category,
            timeOfDay: request.timeOfDay,
            personalityType: request.personalityType,
            partnerName: request.partnerName,
            relationshipDuration: request.relationshipDuration,
            recentContext: request.recentContext,
            specialOccasion: request.specialOccasion,
            preferredTone: options.preferredTone ?? request.preferredTone,
            desiredImpact: options.desiredImpact ?? request.desiredImpact,
            maxWordCount: options.maxWordCount ?? request.maxWordCount,
            includePersonalization: options.includePersonalization,
            generateAlternatives: options.generateAlternatives
        )
    }
    
    private func postProcessResponse(
        _ response: ComprehensiveMessageResponse,
        for user: DomainUser
    ) async throws -> ComprehensiveMessageResponse {
        
        // Add any client-side enhancements
        var enhancedMessages = response.messages
        
        // Sort by estimated impact and personality match
        enhancedMessages.sort { message1, message2 in
            if message1.estimatedImpact.numericValue != message2.estimatedImpact.numericValue {
                return message1.estimatedImpact.numericValue > message2.estimatedImpact.numericValue
            }
            return message1.personalityMatch.lowercased() == user.personalityType?.lowercased()
        }
        
        return ComprehensiveMessageResponse(
            success: response.success,
            messages: enhancedMessages,
            context: response.context,
            error: response.error,
            metadata: response.metadata
        )
    }
    
    private func mapToMessagingError(_ error: Error) -> MessagingAPIError {
        if let messagingError = error as? MessagingAPIError {
            return messagingError
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
            case .forbidden:
                return .forbidden
            case .notFound:
                return .notFound
            case .badRequest(let message):
                return .invalidRequest(message)
            case .serverError(let message):
                return .serverError(message)
            case .networkUnavailable:
                return .networkError(error)
            case .timeout:
                return .networkError(error)
            case .decodingError(let decodingError):
                return .decodingError(decodingError)
            case .unknown:
                return .unknown
            }
        }
        
        return .networkError(error)
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity changes
        NotificationCenter.default
            .publisher(for: .networkConnectivityChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateConnectionState()
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionState() {
        // Update connection state based on network availability
        // This would integrate with your network monitoring
    }
    
    private func invalidateHistoryCache() async {
        // Invalidate message history related caches
        let keys = ["message_history_20_0", "message_history_50_0"]
        for key in keys {
            await cachedAPIClient.cache.remove(key: key)
        }
    }
}

// MARK: - Message Generation Options

struct MessageGenerationOptions {
    let maxWordCount: Int?
    let includePersonalization: Bool
    let generateAlternatives: Bool
    let preferredTone: MessageTone?
    let desiredImpact: MessageImpact?
    let alternativeCount: Int
    
    init(
        maxWordCount: Int? = nil,
        includePersonalization: Bool = true,
        generateAlternatives: Bool = true,
        preferredTone: MessageTone? = nil,
        desiredImpact: MessageImpact? = nil,
        alternativeCount: Int = 3
    ) {
        self.maxWordCount = maxWordCount
        self.includePersonalization = includePersonalization
        self.generateAlternatives = generateAlternatives
        self.preferredTone = preferredTone
        self.desiredImpact = desiredImpact
        self.alternativeCount = alternativeCount
    }
    
    static let `default` = MessageGenerationOptions()
    
    static let quick = MessageGenerationOptions(
        maxWordCount: 50,
        includePersonalization: true,
        generateAlternatives: false,
        alternativeCount: 1
    )
    
    static let comprehensive = MessageGenerationOptions(
        includePersonalization: true,
        generateAlternatives: true,
        alternativeCount: 5
    )
}

// MARK: - Cache Configuration Extensions

private extension CacheConfiguration {
    func with(cacheKey: String, maxAge: TimeInterval? = nil) -> CacheConfiguration {
        let newPolicy = maxAge.map { age in
            CachePolicy(maxAge: age, staleWhileRevalidate: policy.staleWhileRevalidate)
        } ?? policy
        
        return CacheConfiguration(
            strategy: strategy,
            cache: cache,
            cacheKey: cacheKey,
            policy: newPolicy
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
    static let messageGenerationCompleted = Notification.Name("messageGenerationCompleted")
    static let messageCategoriesUpdated = Notification.Name("messageCategoriesUpdated")
}
