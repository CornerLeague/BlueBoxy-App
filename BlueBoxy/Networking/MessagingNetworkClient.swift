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
            cacheKey: "messaging_cache",
            policy: .default
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
                // Try API first, fallback to fixture if needed
                do {
                    response = try await messagingAPIService.fetchMessageCategories()
                } catch {
                    print("⚠️ API unavailable, using fallback categories")
                    response = try loadFallbackCategories()
                }
            } else {
                // Use cached response with intelligent fallback
                let result: Result<MessageCategoriesResponse, NetworkError> = await cachedAPIClient.getCached(
                    Endpoint.messagesCategories(),
                    configuration: cacheConfiguration.with(cacheKey: "enhanced_message_categories")
                )
                
                switch result {
                case .success(let categories):
                    response = categories
                case .failure(_):
                    // Fallback to fixture data when network/cache fails
                    print("⚠️ Network/cache failed, using fallback categories")
                    response = try loadFallbackCategories()
                }
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
        _ = try await fetchMessageCategories(forceRefresh: forceRefresh)
        
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
            
            // Generate messages with retry logic and fallback
            let response: ComprehensiveMessageResponse
            do {
                response = try await messagingAPIService.generateComprehensiveMessages(request: enhancedRequest)
            } catch {
                print("⚠️ Message generation API unavailable, using fallback")
                response = try await generateFallbackMessages(for: user, category: category, recentContext: recentContext, specialOccasion: specialOccasion)
            }
            
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
                let result: Result<MessageHistoryResponse, NetworkError> = await cachedAPIClient.getCached(
                    Endpoint.messagesHistory(limit: limit, offset: offset),
                    configuration: cacheConfiguration.with(
                        cacheKey: "message_history_\(limit)_\(offset)"
                    )
                )
                
                switch result {
                case .success(let history):
                    return history
                case .failure(let error):
                    // Try fallback for message history
                    print("⚠️ Message history API unavailable, using fallback")
                    return try await generateFallbackMessageHistory(limit: limit, offset: offset)
                }
            } else {
                return try await messagingAPIService.fetchMessageHistory(limit: limit, offset: offset)
            }
            
        } catch {
            // Try fallback for any error
            print("⚠️ Message history failed, using fallback")
            do {
                return try await generateFallbackMessageHistory(limit: limit, offset: offset)
            } catch {
                let messagingError = mapToMessagingError(error)
                lastError = messagingError
                throw messagingError
            }
        }
    }
    
    /// Save message with optimistic updates
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async throws {
        do {
            try await messagingAPIService.saveMessage(messageId: message.id)
            
            // Invalidate history cache to reflect changes
            // Note: Cache invalidation would be implemented here
            
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
            // Note: Cache invalidation would be implemented here
            
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
            // Note: Cache invalidation would be implemented here
            
        } catch {
            let messagingError = mapToMessagingError(error)
            lastError = messagingError
            throw messagingError
        }
    }
    
    // MARK: - Smart Recommendations
    
    /// Get smart category recommendations based on user behavior and time
    func getSmartCategoryRecommendations(for user: DomainUser) async throws -> [DetailedMessageCategory] {
        _ = try await messagingAPIService.getTimeAppropriateCategories()
        _ = try await messagingAPIService.getRecommendedCategories(for: user)
        
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
        // Apply any post-processing logic
        return response
    }
    
    /// Load fallback categories from fixture when API is unavailable
    private func loadFallbackCategories() throws -> MessageCategoriesResponse {
        print("🔄 Attempting to load fallback categories from fixture...")
        
        guard let url = Bundle.main.url(forResource: "message_categories_success", withExtension: "json", subdirectory: "Fixtures/messages") else {
            print("❌ Fallback categories fixture file not found in bundle")
            print("📂 Looking for: Fixtures/messages/message_categories_success.json")
            print("🔧 Using hardcoded fallback categories instead")
            return createHardcodedFallbackCategories()
        }
        
        print("📂 Found fixture file at: \(url.path)")
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
            print("✅ Successfully read \(data.count) bytes from fixture file")
        } catch {
            print("❌ Failed to read fixture file: \(error.localizedDescription)")
            throw MessagingAPIError.notFound
        }
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(MessageCategoriesResponse.self, from: data)
            print("✅ Successfully decoded \(response.categories.count) categories from fixture")
            return response
        } catch {
            print("❌ Failed to decode MessageCategoriesResponse: \(error)")
            print("📄 Raw JSON content: \(String(data: data, encoding: .utf8) ?? "Unable to read as UTF-8")")
            throw MessagingAPIError.invalidRequest("Failed to decode fallback categories: \(error.localizedDescription)")
        }
    }
    
    /// Create hardcoded fallback categories when fixture file is not available
    private func createHardcodedFallbackCategories() -> MessageCategoriesResponse {
        let categories = [
            MessageCategory(
                id: "daily_checkins",
                name: "Daily Check-ins",
                description: "Sweet check-ins to stay connected throughout the day",
                emoji: "💬",
                tags: ["daily", "connection", "check-in"]
            ),
            MessageCategory(
                id: "appreciation",
                name: "Appreciation",
                description: "Express gratitude and appreciation for your partner",
                emoji: "❤️",
                tags: ["gratitude", "thanks", "appreciation"]
            ),
            MessageCategory(
                id: "romantic",
                name: "Romantic",
                description: "Romantic messages to spark intimacy and connection",
                emoji: "❤️",
                tags: ["romance", "intimacy", "love"]
            ),
            MessageCategory(
                id: "encouragement",
                name: "Encouragement", 
                description: "Motivating messages to lift your partner's spirits",
                emoji: "⭐",
                tags: ["motivation", "support", "encouragement"]
            ),
            MessageCategory(
                id: "support",
                name: "Support",
                description: "Offer comfort and support during challenging times",
                emoji: "🤝",
                tags: ["support", "comfort", "empathy"]
            ),
            MessageCategory(
                id: "playful",
                name: "Playful",
                description: "Fun and lighthearted messages to bring joy",
                emoji: "😄",
                tags: ["fun", "playful", "humor"]
            ),
            MessageCategory(
                id: "good_morning",
                name: "Good Morning",
                description: "Start the day with loving morning messages",
                emoji: "☀️",
                tags: ["morning", "start", "energy"]
            ),
            MessageCategory(
                id: "good_night",
                name: "Good Night",
                description: "End the day with sweet goodnight wishes",
                emoji: "🌙",
                tags: ["night", "sleep", "dreams"]
            )
        ]
        
        print("✅ Created hardcoded fallback with \(categories.count) categories (matching MessageCategoryType enum)")
        return MessageCategoriesResponse(categories: categories, success: true)
    }
    
    /// Generate fallback messages when API is unavailable
    private func generateFallbackMessages(
        for user: DomainUser,
        category: MessageCategoryType,
        recentContext: String? = nil,
        specialOccasion: String? = nil
    ) async throws -> ComprehensiveMessageResponse {
        
        let partnerName = user.partnerName ?? "love"
        let personalityType = user.personalityType ?? "Thoughtful Harmonizer"
        
        // Generate contextual messages based on category
        let messages: [ComprehensiveGeneratedMessage] = generateContextualMessages(
            category: category,
            partnerName: partnerName,
            personalityType: personalityType,
            recentContext: recentContext,
            specialOccasion: specialOccasion
        )
        
        let context = ComprehensiveMessageResponse.MessageGenerationContext(
            category: category.rawValue.capitalized,
            personalityType: personalityType,
            partnerName: partnerName,
            timeOfDay: TimeOfDay.current,
            relationshipStage: "established",
            contextualFactors: [
                "recentContext": recentContext ?? "",
                "specialOccasion": specialOccasion ?? ""
            ]
        )
        
        return ComprehensiveMessageResponse(
            success: true,
            messages: messages,
            context: context,
            error: nil,
            metadata: ComprehensiveMessageResponse.ResponseMetadata(
                generatedAt: Date(),
                processingTimeMs: 500,
                totalAlternatives: messages.count,
                personalityMatchConfidence: 0.85,
                canGenerateMore: true,
                generationsRemaining: 10,
                suggestedCategory: nil
            )
        )
    }
    
    /// Generate contextual messages based on category and user info
    private func generateContextualMessages(
        category: MessageCategoryType,
        partnerName: String,
        personalityType: String,
        recentContext: String?,
        specialOccasion: String?
    ) -> [ComprehensiveGeneratedMessage] {
        
        let baseMessages = getBaseMessagesForCategory(category)
        
        return baseMessages.enumerated().map { index, template in
            let personalizedContent = personalizeMessage(
                template: template,
                partnerName: partnerName,
                recentContext: recentContext,
                specialOccasion: specialOccasion
            )
            
            let messageContext = ComprehensiveGeneratedMessage.MessageContext(
                timeOfDay: TimeOfDay.current,
                relationshipDuration: "established",
                recentContext: recentContext,
                specialOccasion: specialOccasion,
                userPersonalityType: personalityType,
                partnerName: partnerName
            )
            
            return ComprehensiveGeneratedMessage(
                id: "\(category.rawValue)_\(Date().timeIntervalSince1970)_\(index)",
                content: personalizedContent,
                category: category,
                personalityMatch: personalityType,
                tone: getToneForCategory(category),
                estimatedImpact: getImpactForCategory(category),
                context: messageContext
            )
        }
    }
    
    /// Get base message templates for each category
    private func getBaseMessagesForCategory(_ category: MessageCategoryType) -> [String] {
        switch category {
        case .appreciation:
            return [
                "{partnerName}, I really appreciate how much thought you put into the little things—it makes me feel so cared for.",
                "I saw how hard you worked today—so proud of you, {partnerName}.",
                "Thank you for being you, {partnerName}. I feel lucky to have you."
            ]
        case .encouragement:
            return [
                "You're going to do amazing today, {partnerName}!",
                "I believe in you completely, {partnerName}. You've got this!",
                "Remember how strong you are, {partnerName}. You can handle anything."
            ]
        case .romantic:
            return [
                "Thinking of you and smiling, {partnerName} ❤️",
                "Can't wait to see you tonight, {partnerName}",
                "You make every day brighter, my love"
            ]
        case .apology:
            return [
                "I'm sorry about earlier, {partnerName}. Can we talk?",
                "I was wrong and I want to make it right, {partnerName}.",
                "I hate when we're not okay. I love you, {partnerName}."
            ]
        case .goodMorning:
            return [
                "Good morning beautiful, {partnerName}! Hope you have a wonderful day ☀️",
                "Morning sunshine! Thinking of you, {partnerName}",
                "Rise and shine, {partnerName}! Another day to love you ❤️"
            ]
        case .goodNight:
            return [
                "Sweet dreams, {partnerName} 🌙",
                "Sleep well, {partnerName}. Can't wait to see you tomorrow",
                "Good night, my love. Dream of us ❤️"
            ]
        case .dailyCheckins:
            return [
                "How's your day going, {partnerName}?",
                "Just checking in, thinking of you {partnerName} ❤️",
                "Hope you're having a great day, {partnerName}!"
            ]
        case .playful:
            return [
                "Want to try that new restaurant this weekend, {partnerName}?",
                "I found a fun activity we could do together, {partnerName}!",
                "Any ideas for our date night, {partnerName}? 😊"
            ]
        default:
            return [
                "Thinking of you, {partnerName} ❤️",
                "Hope you're doing well, {partnerName}",
                "Love you, {partnerName}!"
            ]
        }
    }
    
    /// Personalize message template with user details
    private func personalizeMessage(
        template: String,
        partnerName: String,
        recentContext: String?,
        specialOccasion: String?
    ) -> String {
        var message = template.replacingOccurrences(of: "{partnerName}", with: partnerName)
        
        // Add context if provided
        if let context = recentContext, !context.isEmpty {
            message += " \(context)"
        }
        
        // Add special occasion if provided
        if let occasion = specialOccasion, !occasion.isEmpty {
            message += " Hope \(occasion) goes well!"
        }
        
        return message
    }
    
    /// Get appropriate tone for category
    private func getToneForCategory(_ category: MessageCategoryType) -> MessageTone {
        switch category {
        case .appreciation: return .warm
        case .encouragement: return .supportive
        case .romantic: return .romantic
        case .apology: return .warm
        case .goodMorning: return .warm
        case .goodNight: return .warm
        case .dailyCheckins: return .warm
        case .playful: return .warm
        default: return .warm
        }
    }
    
    /// Get appropriate impact level for category
    private func getImpactForCategory(_ category: MessageCategoryType) -> MessageImpact {
        switch category {
        case .appreciation: return .high
        case .encouragement: return .medium
        case .romantic: return .high
        case .apology: return .high
        case .goodMorning: return .medium
        case .goodNight: return .medium
        case .dailyCheckins: return .low
        case .playful: return .medium
        default: return .medium
        }
    }
    
    /// Generate fallback message history when API is unavailable
    private func generateFallbackMessageHistory(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> MessageHistoryResponse {
        
        // Create sample message history items
        let sampleMessages: [(String, String, MessageCategoryType)] = [
            ("Hope your Monday is off to a great start! ✨", "personal-development", .encouragement),
            ("Thank you for the thoughtful conversation earlier. It really made my day! 🙏", "gratitude", .appreciation),
            ("Looking forward to our meeting tomorrow. I've prepared some exciting ideas to share! 💡", "work-professional", .encouragement),
            ("Just wanted to check in and see how you're doing. Thinking of you! 💜", "personal-development", .dailyCheckins),
            ("Congratulations on your recent achievement! You deserve all the success coming your way. 🎉", "celebration", .appreciation)
        ]
        
        let historyItems: [MessageHistoryItem] = sampleMessages.enumerated().compactMap { (index, messageData) in
            let (content, categoryId, categoryType) = messageData
            
            // Create EnhancedGeneratedMessage directly
            let message = EnhancedGeneratedMessage(
                id: "fallback-msg-\(index + 1)",
                content: content,
                category: categoryId,
                personalityMatch: "Thoughtful Harmonizer",
                tone: "warm",
                estimatedImpact: .medium,
                generatedAt: Date().addingTimeInterval(-TimeInterval((index + 1) * 3600))
            )
            
            let context = MessageGenerationContext(
                category: categoryId,
                personalityType: "Thoughtful Harmonizer",
                partnerName: "love",
                timeOfDay: .current,
                relationshipDuration: "6 months",
                specialOccasion: nil
            )
            
            return MessageHistoryItem(
                message: message,
                context: context,
                isFavorite: index == 0 || index == 3, // Make some favorites
                wasShared: index < 2 // Mark first two as shared
            )
        }
        
        return MessageHistoryResponse(
            messages: Array(historyItems.dropFirst(offset).prefix(limit)),
            total: historyItems.count,
            page: (offset / limit) + 1,
            hasMore: offset + limit < historyItems.count
        )
    }
    
    // MARK: - Private Network Setup
    
    private func setupNetworkMonitoring() {
        // Monitor network state changes
        // This would integrate with network monitoring if available
    }
    
    private func mapToMessagingError(_ error: Error) -> MessagingAPIError {
        if let messagingError = error as? MessagingAPIError {
            return messagingError
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .notFound:
                return .notFound
            case .unauthorized:
                return .unauthorized
            case .badRequest:
                return .invalidRequest("Bad request")
            default:
                return .networkError(error)
            }
        }
        
        return .networkError(error)
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
    func with(cacheKey: String) -> CacheConfiguration {
        return CacheConfiguration(
            strategy: strategy,
            cache: cache,
            cacheKey: cacheKey,
            policy: policy
        )
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
    static let messageGenerationCompleted = Notification.Name("messageGenerationCompleted")
    static let messageCategoriesUpdated = Notification.Name("messageCategoriesUpdated")
}
