//
//  EnhancedMessagingService.swift
//  BlueBoxy
//
//  Enhanced messaging service that provides comprehensive message generation,
//  smart recommendations, and advanced state management for the messaging feature.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Enhanced Messaging Service Protocol

@MainActor
protocol EnhancedMessagingServiceProtocol: ObservableObject {
    // State Properties
    var generationState: Loadable<ComprehensiveMessageResponse> { get }
    var categoriesState: Loadable<[DetailedMessageCategory]> { get }
    var historyState: Loadable<MessageHistoryResponse> { get }
    var recommendationsState: Loadable<[DetailedMessageCategory]> { get }
    
    // Configuration Properties
    var selectedCategory: MessageCategoryType? { get set }
    var recentContext: String { get set }
    var specialOccasion: String { get set }
    var selectedTimeOfDay: TimeOfDay { get set }
    var generationOptions: MessageGenerationOptions { get set }
    
    // Core Methods
    func loadCategories(forceRefresh: Bool) async
    func loadPersonalizedRecommendations(for user: DomainUser) async
    func generateMessages(for user: DomainUser) async
    func generateQuickMessage(for user: DomainUser, category: MessageCategoryType) async
    func loadHistory(limit: Int, offset: Int) async
    func clearGeneration()
    func resetForm()
    
    // Message Actions
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async throws
    func deleteMessage(_ messageId: String) async throws
    func favoriteMessage(_ messageId: String) async throws
    func shareMessage(_ message: ComprehensiveGeneratedMessage) -> String
    
    // Smart Features
    func getSuggestedMessage(for user: DomainUser) async
    func getContextualSuggestions(for user: DomainUser) -> [String]
    func getCategoryRecommendations(for user: DomainUser) -> [DetailedMessageCategory]
}

// MARK: - Enhanced Messaging Service Implementation

@MainActor
final class EnhancedMessagingService: EnhancedMessagingServiceProtocol {
    
    // MARK: - Published State
    
    @Published var generationState: Loadable<ComprehensiveMessageResponse> = .idle
    @Published var categoriesState: Loadable<[DetailedMessageCategory]> = .idle
    @Published var historyState: Loadable<MessageHistoryResponse> = .idle
    @Published var recommendationsState: Loadable<[DetailedMessageCategory]> = .idle
    
    // MARK: - Configuration Properties
    
    @Published var selectedCategory: MessageCategoryType? = nil
    @Published var recentContext: String = ""
    @Published var specialOccasion: String = ""
    @Published var selectedTimeOfDay: TimeOfDay = .current
    @Published var generationOptions: MessageGenerationOptions = .default
    
    // MARK: - Additional State
    
    @Published var lastGeneratedMessages: [ComprehensiveGeneratedMessage] = []
    @Published var favoriteCategories: [MessageCategoryType] = []
    @Published var recentGenerationHistory: [MessageGenerationRecord] = []
    
    // MARK: - Computed Properties
    
    /// Get today's recent messages from RecentMessagesManager
    var todaysRecentMessages: [RecentMessage] {
        recentMessagesManager.getRecentMessages()
    }
    
    /// Get count of today's generated messages
    var todayMessagesCount: Int {
        recentMessagesManager.todayMessagesCount
    }
    
    // MARK: - Dependencies
    
    private let messagingNetworkClient: MessagingNetworkClient
    private let categoryManager: MessageCategoryManager
    private let storageService: MessageStorageServiceProtocol?
    private let recentMessagesManager: RecentMessagesManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let maxHistoryItems = 100
    private let contextMaxLength = 200
    private let maxRecentGenerations = 20
    
    // MARK: - Initialization
    
    init(
        messagingNetworkClient: MessagingNetworkClient,
        categoryManager: MessageCategoryManager = .shared,
        storageService: MessageStorageServiceProtocol? = nil,
        recentMessagesManager: RecentMessagesManager = .shared
    ) {
        self.messagingNetworkClient = messagingNetworkClient
        self.categoryManager = categoryManager
        self.storageService = storageService
        self.recentMessagesManager = recentMessagesManager
        
        setupInitialState()
        observeNetworkClient()
        observeAuthenticationChanges()
    }
    
    // MARK: - Data Loading
    
    func loadCategories(forceRefresh: Bool = false) async {
        print("🔄 LoadCategories called with forceRefresh: \(forceRefresh)")
        categoriesState = .loading(message: "Loading message categories...")
        
        do {
            let categories = try await messagingNetworkClient.fetchMessageCategories(forceRefresh: forceRefresh)
            print("✅ Categories loaded successfully: \(categories.count) categories")
            categoriesState = .loaded(categories)
            
            // Set default category if none selected
            if selectedCategory == nil, let firstCategory = categories.first {
                selectedCategory = firstCategory.type
                print("📌 Selected default category: \(firstCategory.type.rawValue)")
            }
            
            // Update favorite categories based on usage patterns
            updateFavoriteCategories(from: categories)
            
        } catch {
            print("❌ Categories loading failed: \(error.localizedDescription)")
            categoriesState = .failed(NetworkError.from(error))
        }
    }
    
    func loadPersonalizedRecommendations(for user: DomainUser) async {
        recommendationsState = .loading(message: "Getting personalized recommendations...")
        
        do {
            let recommendations = try await messagingNetworkClient.getSmartCategoryRecommendations(for: user)
            recommendationsState = .loaded(recommendations)
        } catch {
            recommendationsState = .failed(NetworkError.from(error))
        }
    }
    
    func loadHistory(limit: Int = 50, offset: Int = 0) async {
        historyState = .loading(message: "Loading message history...")
        
        do {
            let history = try await messagingNetworkClient.fetchMessageHistory(
                limit: limit,
                offset: offset,
                useCache: offset == 0 // Only use cache for first page
            )
            historyState = .loaded(history)
        } catch {
            historyState = .failed(NetworkError.from(error))
        }
    }
    
    // MARK: - Message Generation
    
    func generateMessages(for user: DomainUser) async {
        guard let category = selectedCategory else {
            generationState = .failed(.badRequest(message: "Please select a message category"))
            return
        }
        
        generationState = .loading(message: "Generating personalized messages...")
        
        let contextText = recentContext.isEmpty ? nil : String(recentContext.prefix(contextMaxLength))
        let occasionText = specialOccasion.isEmpty ? nil : specialOccasion
        
        do {
            let response = try await messagingNetworkClient.generateMessages(
                for: user,
                category: category,
                recentContext: contextText,
                specialOccasion: occasionText,
                options: generationOptions
            )
            
            generationState = .loaded(response)
            lastGeneratedMessages = response.messages
            
            // Save generated messages to recent messages storage
            for message in response.messages {
                recentMessagesManager.addRecentMessage(message)
            }
            
            // Record this generation for analytics and suggestions
            recordGeneration(category: category, user: user, response: response)
            
            // Update history if it's currently loaded
            await updateHistoryWithNewMessages(response.messages)
            
            // Save to local storage if available
            await saveGeneratedMessages(response.messages, context: response.context)
            
        } catch {
            generationState = .failed(NetworkError.from(error))
        }
    }
    
    func generateQuickMessage(for user: DomainUser, category: MessageCategoryType) async {
        // Temporarily set category and generate
        let originalCategory = selectedCategory
        let originalOptions = generationOptions
        
        selectedCategory = category
        generationOptions = .quick
        
        await generateMessages(for: user)
        
        // Restore original settings
        selectedCategory = originalCategory
        generationOptions = originalOptions
    }
    
    // MARK: - Smart Features
    
    func getSuggestedMessage(for user: DomainUser) async {
        do {
            if let suggestedMessage = try await messagingNetworkClient.getSuggestedMessage(for: user) {
                // Create a temporary response with the suggested message
                let context = ComprehensiveMessageResponse.MessageGenerationContext(
                    category: suggestedMessage.category.rawValue,
                    personalityType: user.personalityType ?? "unknown",
                    partnerName: user.partnerName ?? "partner",
                    timeOfDay: .current,
                    relationshipStage: user.relationshipDuration,
                    contextualFactors: [:]
                )
                
                let metadata = ComprehensiveMessageResponse.ResponseMetadata(
                    generatedAt: Date(),
                    processingTimeMs: nil,
                    totalAlternatives: 1,
                    personalityMatchConfidence: nil,
                    canGenerateMore: true,
                    generationsRemaining: nil,
                    suggestedCategory: nil
                )
                
                let response = ComprehensiveMessageResponse(
                    success: true,
                    messages: [suggestedMessage],
                    context: context,
                    error: nil,
                    metadata: metadata
                )
                
                generationState = .loaded(response)
                lastGeneratedMessages = [suggestedMessage]
            }
        } catch {
            // Don't update generation state for suggested message failures
            print("Failed to get suggested message: \(error)")
        }
    }
    
    func getContextualSuggestions(for user: DomainUser) -> [String] {
        guard let category = selectedCategory else {
            return []
        }
        
        return categoryManager.getContextualSuggestions(for: category, personalityType: user.personalityType)
    }
    
    func getCategoryRecommendations(for user: DomainUser) -> [DetailedMessageCategory] {
        return MessageCategorySelector.getContextualCategories(for: user, limit: 6)
    }
    
    // MARK: - Message Actions
    
    func saveMessage(_ message: ComprehensiveGeneratedMessage) async throws {
        try await messagingNetworkClient.saveMessage(message)
        
        // Update local state
        await storageService?.saveMessage(message)
    }
    
    func deleteMessage(_ messageId: String) async throws {
        try await messagingNetworkClient.deleteMessage(messageId)
        
        // Update local state
        await storageService?.deleteMessage(messageId)
        
        // Remove from current generation if present
        lastGeneratedMessages.removeAll { $0.id == messageId }
        
        // Update generation state if needed
        if case .loaded(let response) = generationState {
            var updatedResponse = response
            var updatedMessages = updatedResponse.messages
            updatedMessages.removeAll { $0.id == messageId }
            updatedResponse = ComprehensiveMessageResponse(
                success: updatedResponse.success,
                messages: updatedMessages,
                context: updatedResponse.context,
                error: updatedResponse.error,
                metadata: updatedResponse.metadata
            )
            generationState = .loaded(updatedResponse)
        }
    }
    
    func favoriteMessage(_ messageId: String) async throws {
        try await messagingNetworkClient.favoriteMessage(messageId)
        
        // Update local state
        await storageService?.favoriteMessage(messageId)
    }
    
    func shareMessage(_ message: ComprehensiveGeneratedMessage) -> String {
        var shareText = message.content
        
        // Add context if available
        if !recentContext.isEmpty {
            shareText += "\n\n💕 Sent with love from BlueBoxy"
        }
        
        // Add category tag for analytics
        shareText += "\n\n#\(message.category.rawValue)"
        
        return shareText
    }
    
    // MARK: - State Management
    
    func clearGeneration() {
        generationState = .idle
        lastGeneratedMessages = []
    }
    
    func resetForm() {
        selectedCategory = categoriesState.value?.first?.type
        recentContext = ""
        specialOccasion = ""
        selectedTimeOfDay = .current
        generationOptions = .default
        clearGeneration()
    }
    
    // MARK: - Computed Properties
    
    var isGenerating: Bool {
        return generationState.isLoading
    }
    
    var canGenerate: Bool {
        return selectedCategory != nil && !isGenerating
    }
    
    var currentCategories: [DetailedMessageCategory] {
        return categoriesState.value ?? []
    }
    
    var currentRecommendations: [DetailedMessageCategory] {
        return recommendationsState.value ?? []
    }
    
    var generatedMessages: [ComprehensiveGeneratedMessage] {
        return generationState.value?.messages ?? []
    }
    
    var generationContext: ComprehensiveMessageResponse.MessageGenerationContext? {
        return generationState.value?.context
    }
    
    var generationMetadata: ComprehensiveMessageResponse.ResponseMetadata? {
        return generationState.value?.metadata
    }
    
    // MARK: - Analytics and Insights
    
    var messageStatistics: MessageStatistics? {
        return lastGeneratedMessages.messageStatistics
    }
    
    var recentGenerations: [MessageGenerationRecord] {
        return recentGenerationHistory.prefix(10).map { $0 }
    }
    
    func getUsageInsights() -> MessageUsageInsights {
        return MessageUsageInsights(
            totalGenerations: recentGenerationHistory.count,
            favoriteCategory: favoriteCategories.first,
            averageGenerationsPerDay: calculateAverageGenerationsPerDay(),
            personalityMatchScore: calculatePersonalityMatchScore(),
            mostUsedTimeOfDay: calculateMostUsedTimeOfDay(),
            contextUsageFrequency: calculateContextUsageFrequency()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        selectedTimeOfDay = .current
        
        // Load cached data if available
        Task {
            await loadCachedData()
        }
    }
    
    private func observeNetworkClient() {
        // Observe network client state changes
        messagingNetworkClient.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionState in
                self?.handleNetworkStateChange(connectionState)
            }
            .store(in: &cancellables)
        
        messagingNetworkClient.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleNetworkError(error)
            }
            .store(in: &cancellables)
    }
    
    private func observeAuthenticationChanges() {
        // Clear data when user logs out
        NotificationCenter.default
            .publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearAllData()
            }
            .store(in: &cancellables)
        
        // Load data when user logs in
        NotificationCenter.default
            .publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadCategories()
                }
            }
            .store(in: &cancellables)
    }
    
    private func recordGeneration(
        category: MessageCategoryType,
        user: DomainUser,
        response: ComprehensiveMessageResponse
    ) {
        let record = MessageGenerationRecord(
            id: UUID(),
            category: category,
            userId: user.id,
            timestamp: Date(),
            messagesGenerated: response.messages.count,
            personalityType: user.personalityType,
            timeOfDay: selectedTimeOfDay,
            hadContext: !recentContext.isEmpty,
            hadSpecialOccasion: !specialOccasion.isEmpty,
            averageImpact: response.messages.map { $0.estimatedImpact.numericValue }.reduce(0, +) / response.messages.count
        )
        
        recentGenerationHistory.insert(record, at: 0)
        
        // Keep only recent generations
        if recentGenerationHistory.count > maxRecentGenerations {
            recentGenerationHistory = Array(recentGenerationHistory.prefix(maxRecentGenerations))
        }
    }
    
    private func updateFavoriteCategories(from categories: [DetailedMessageCategory]) {
        // Update favorite categories based on usage patterns and priority
        favoriteCategories = categories
            .filter { $0.isSuitableForCurrentTime }
            .sorted { $0.priority > $1.priority }
            .prefix(5)
            .map { $0.type }
    }
    
    private func updateHistoryWithNewMessages(_ messages: [ComprehensiveGeneratedMessage]) async {
        guard case .loaded(let historyResponse) = historyState else { return }
        
        // Convert comprehensive messages to enhanced messages
        let historyItems = messages.compactMap { message -> MessageHistoryItem? in
            // Convert ComprehensiveGeneratedMessage to MessageItem first, then to EnhancedGeneratedMessage
            let messageItem = MessageItem(
                id: message.id,
                content: message.content,
                category: message.category.rawValue,
                personalityMatch: message.personalityMatch,
                tone: message.tone.rawValue,
                estimatedImpact: message.estimatedImpact.rawValue,
                createdAt: Date()
            )
            let enhancedMessage = EnhancedGeneratedMessage(from: messageItem)
            
            return MessageHistoryItem(
                message: enhancedMessage,
                context: MessageGenerationContext(
                    category: message.category.rawValue,
                    personalityType: message.personalityMatch,
                    partnerName: message.contextualFactors.partnerName ?? "partner"
                ),
                isFavorite: false,
                wasShared: false
            )
        }
        
        // Create updated history with new items at the beginning
        var updatedMessages = historyItems + historyResponse.messages
        
        // Trim to max items
        if updatedMessages.count > maxHistoryItems {
            updatedMessages = Array(updatedMessages.prefix(maxHistoryItems))
        }
        
        // Check which MessageHistoryResponse structure is being used
        // From MessagingModels.swift, the struct has: messages, total, page, hasMore
        let updatedResponse = MessageHistoryResponse(
            messages: updatedMessages,
            total: historyResponse.total,
            page: historyResponse.page,
            hasMore: historyResponse.hasMore
        )
        
        historyState = .loaded(updatedResponse)
    }
    
    private func saveGeneratedMessages(
        _ messages: [ComprehensiveGeneratedMessage],
        context: ComprehensiveMessageResponse.MessageGenerationContext
    ) async {
        await storageService?.saveGeneratedMessages(messages, context: context)
    }
    
    private func loadCachedData() async {
        if let cachedMessages = await storageService?.loadRecentMessages() {
            lastGeneratedMessages = cachedMessages
        }
    }
    
    private func handleNetworkStateChange(_ state: MessagingNetworkClient.ConnectionState) {
        // Update UI state based on network connectivity
        switch state {
        case .error(let error):
            // Handle persistent network errors
            if case .loading = generationState {
                generationState = .failed(ErrorMapper.map(error))
            }
        default:
            break
        }
    }
    
    private func handleNetworkError(_ error: MessagingAPIError) {
        // Log error for analytics
        print("💥 Messaging Error: \(error.localizedDescription)")
    }
    
    private func clearAllData() {
        generationState = .idle
        categoriesState = .idle
        historyState = .idle
        recommendationsState = .idle
        lastGeneratedMessages = []
        recentGenerationHistory = []
        resetForm()
    }
    
    // MARK: - Analytics Calculations
    
    private func calculateAverageGenerationsPerDay() -> Double {
        let recentGenerations = recentGenerationHistory.filter { 
            $0.timestamp.timeIntervalSinceNow > -7 * 24 * 60 * 60 // Last 7 days
        }
        return Double(recentGenerations.count) / 7.0
    }
    
    private func calculatePersonalityMatchScore() -> Double {
        let scores = lastGeneratedMessages.compactMap { message in
            // Simple heuristic based on personality match confidence
            return message.personalityMatch.lowercased().contains("high") ? 1.0 : 
                   message.personalityMatch.lowercased().contains("medium") ? 0.7 : 0.5
        }
        return scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)
    }
    
    private func calculateMostUsedTimeOfDay() -> TimeOfDay {
        let timeUsage = Dictionary(grouping: recentGenerationHistory, by: { $0.timeOfDay })
        return timeUsage.max { $0.value.count < $1.value.count }?.key ?? .current
    }
    
    private func calculateContextUsageFrequency() -> Double {
        let withContext = recentGenerationHistory.filter { $0.hadContext }.count
        return recentGenerationHistory.isEmpty ? 0.0 : Double(withContext) / Double(recentGenerationHistory.count)
    }
}

// MARK: - Supporting Models

struct MessageGenerationRecord: Codable, Identifiable {
    let id: UUID
    let category: MessageCategoryType
    let userId: Int
    let timestamp: Date
    let messagesGenerated: Int
    let personalityType: String?
    let timeOfDay: TimeOfDay
    let hadContext: Bool
    let hadSpecialOccasion: Bool
    let averageImpact: Int
}

struct MessageUsageInsights {
    let totalGenerations: Int
    let favoriteCategory: MessageCategoryType?
    let averageGenerationsPerDay: Double
    let personalityMatchScore: Double
    let mostUsedTimeOfDay: TimeOfDay
    let contextUsageFrequency: Double
}

// MARK: - Network Error Extension

extension NetworkError {
    static func from(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        if let messagingError = error as? MessagingAPIError {
            switch messagingError {
            case .unauthorized:
                return .unauthorized
            case .forbidden:
                return .forbidden
            case .notFound:
                return .notFound
            case .invalidRequest(let message):
                return .badRequest(message: message)
            case .serverError(let message):
                return .serverError(message)
            case .networkError(let networkError):
                return ErrorMapper.map(networkError)
            case .decodingError(let decodingError):
                return .decoding(decodingError.localizedDescription)
            default:
                return .unknown(status: nil)
            }
        }
        
        return .unknown(status: nil)
    }
}