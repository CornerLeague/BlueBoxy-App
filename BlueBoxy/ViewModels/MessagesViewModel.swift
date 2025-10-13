//
//  MessagesViewModel.swift
//  BlueBoxy
//
//  Messages and AI-generated content state management
//  Handles message generation, categories, history, and personalization
//

import Foundation
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var generationState: Loadable<MessageGenerationResponse> = .idle
    @Published var categories: Loadable<[MessageCategory]> = .idle
    @Published var history: Loadable<MessageHistoryResponse> = .idle
    @Published var selectedCategory: String = ""
    @Published var recentContext: String = ""
    @Published var specialOccasion: String = ""
    @Published var selectedTimeOfDay: TimeOfDay? = nil
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let cache = FileResponseCache()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let maxHistoryItems = 100
    private let contextMaxLength = 200
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        setupInitialData()
        observeAuthenticationChanges()
    }
    
    // MARK: - Data Loading
    
    /// Load message categories from API
    func loadCategories() async {
        categories = .loading()
        
        // Try cache first, then network
        let result: Result<MessageCategoriesResponse, NetworkError> = await apiClient.requestWithRetryResult(
            Endpoint(path: "/api/messages/categories", method: .GET),
            policy: .default
        )
        
        switch result {
        case .success(let response):
            categories = .loaded(response.categories)
            
            // Set default category if none selected
            if selectedCategory.isEmpty, let firstCategory = response.categories.first {
                selectedCategory = firstCategory.id
            }
            
        case .failure(let error):
            categories = .failed(error)
        }
    }
    
    /// Load message history
    func loadHistory(limit: Int = 50, offset: Int = 0) async {
        history = .loading()
        
        let result: Result<MessageHistoryResponse, NetworkError> = await apiClient.requestWithRetryResult(
            .messagesHistory(limit: limit, offset: offset),
            policy: .default
        )
        
        switch result {
        case .success(let response):
            history = .loaded(response)
        case .failure(let error):
            history = .failed(error)
        }
    }
    
    // MARK: - Message Generation
    
    /// Generate personalized messages with current settings
    func generateMessages() async {
        guard !selectedCategory.isEmpty else {
            generationState = .failed(.badRequest(message: "Please select a message category"))
            return
        }
        
        generationState = .loading()
        
        let request = MessageGenerateRequest(
            category: selectedCategory,
            timeOfDay: selectedTimeOfDay,
            recentContext: recentContext.isEmpty ? nil : String(recentContext.prefix(contextMaxLength)),
            specialOccasion: specialOccasion.isEmpty ? nil : specialOccasion
        )
        
        let result: Result<MessageGenerationResponse, NetworkError> = await apiClient.requestWithRetryResult(
            .messagesGenerate(request),
            policy: .default
        )
        
        switch result {
        case .success(let response):
            generationState = .loaded(response)
            
            // Add to history if we have it loaded
            if case .loaded(let historyResponse) = history {
                // Create new message history items from generation response
                let newMessages = response.messages.map { message in
                    let enhancedMessage = EnhancedGeneratedMessage(from: message)
                    
                    return MessageHistoryItem(
                        message: enhancedMessage,
                        context: MessageGenerationContext(
                            category: selectedCategory,
                            personalityType: "default",
                            partnerName: "Partner",
                            timeOfDay: selectedTimeOfDay,
                            specialOccasion: specialOccasion.isEmpty ? nil : specialOccasion
                        )
                    )
                }
                
                // Create updated history response
                var updatedMessages = newMessages + historyResponse.messages
                
                // Trim history to max items
                if updatedMessages.count > maxHistoryItems {
                    updatedMessages = Array(updatedMessages.prefix(maxHistoryItems))
                }
                
                let updatedResponse = MessageHistoryResponse(
                    messages: updatedMessages,
                    total: historyResponse.total + newMessages.count,
                    page: historyResponse.page,
                    hasMore: historyResponse.hasMore
                )
                
                history = .loaded(updatedResponse)
            }
            
        case .failure(let error):
            generationState = .failed(error)
        }
    }
    
    /// Generate messages for specific category (convenience method)
    func generateMessages(for category: String, 
                         timeOfDay: TimeOfDay? = nil,
                         context: String? = nil,
                         occasion: String? = nil) async {
        selectedCategory = category
        selectedTimeOfDay = timeOfDay
        recentContext = context ?? ""
        specialOccasion = occasion ?? ""
        
        await generateMessages()
    }
    
    // MARK: - Message Actions
    
    /// Save a generated message to favorites/history
    func saveMessage(_ messageId: String) async -> Bool {
        do {
            try await apiClient.requestEmpty(.messagesSave(messageId: messageId))
            return true
        } catch {
            print("⚠️ Failed to save message: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Share a message (returns shareable text)
    func shareMessage(_ message: Message) -> String {
        var shareText = message.content
        
        // Add context if available
        if !recentContext.isEmpty {
            shareText += "\n\n💕 Sent with love from BlueBoxy"
        }
        
        return shareText
    }
    
    /// Clear current generation state
    func clearGeneration() {
        generationState = .idle
    }
    
    /// Reset message form
    func resetForm() {
        selectedCategory = categories.value?.first?.id ?? ""
        recentContext = ""
        specialOccasion = ""
        selectedTimeOfDay = nil
        generationState = .idle
    }
    
    // MARK: - Computed Properties
    
    /// Whether message generation is in progress
    var isGenerating: Bool {
        return generationState.isLoading
    }
    
    /// Whether form is valid for generation
    var canGenerate: Bool {
        return !selectedCategory.isEmpty && !isGenerating
    }
    
    /// Get current category details
    var currentCategory: MessageCategory? {
        guard let categoriesData = categories.value else { return nil }
        return categoriesData.first { $0.id == selectedCategory }
    }
    
    /// Get generated messages from current state
    var generatedMessages: [Message] {
        return generationState.value?.messages ?? []
    }
    
    /// Get message generation context info
    var generationContext: [String: String] {
        return generationState.value?.context ?? [:]
    }
    
    /// Get recent message history (last 10 items)
    var recentMessages: [MessageHistoryItem] {
        guard let historyData = history.value else { return [] }
        return Array(historyData.messages.prefix(10))
    }
    
    /// Statistics about message usage
    var messageStats: MessageStats? {
        guard let historyData = history.value else { return nil }
        
        let totalMessages = historyData.total
        let recentCount = historyData.messages.count
        
        // Count by category
        var categoryCount: [String: Int] = [:]
        for message in historyData.messages {
            categoryCount[message.message.category, default: 0] += 1
        }
        
        let favoriteCategory = categoryCount.max { $0.value < $1.value }?.key
        
        return MessageStats(
            totalGenerated: totalMessages,
            recentCount: recentCount,
            favoriteCategory: favoriteCategory,
            categoryBreakdown: categoryCount
        )
    }
    
    // MARK: - Smart Suggestions
    
    /// Get time of day suggestion based on current time
    var suggestedTimeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    /// Get context suggestions based on recent usage
    var contextSuggestions: [String] {
        guard let historyData = history.value else { return [] }
        
        // Extract common context patterns from recent messages
        let recentContexts = historyData.messages
            .compactMap { extractContextFromMessage($0) }
            .filter { !$0.isEmpty }
        
        // Return unique suggestions
        return Array(Set(recentContexts)).prefix(5).map { String($0) }
    }
    
    /// Get category suggestions based on usage patterns
    var suggestedCategories: [MessageCategory] {
        guard let categoriesData = categories.value,
              let stats = messageStats else { return [] }
        
        // Sort categories by usage frequency
        return categoriesData.sorted { cat1, cat2 in
            let count1 = stats.categoryBreakdown[cat1.id] ?? 0
            let count2 = stats.categoryBreakdown[cat2.id] ?? 0
            return count1 > count2
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupInitialData() {
        // Set smart defaults
        selectedTimeOfDay = suggestedTimeOfDay
        
        // Load initial data
        Task {
            await loadCategories()
        }
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
                    await self?.loadHistory()
                }
            }
            .store(in: &cancellables)
    }
    
    private func clearAllData() {
        generationState = .idle
        categories = .idle
        history = .idle
        resetForm()
    }
    
    private func extractContextFromMessage(_ message: MessageHistoryItem) -> String {
        // Simple heuristic to extract context patterns
        // In a real implementation, this could be more sophisticated
        let words = message.message.content.components(separatedBy: .whitespacesAndNewlines)
        
        // Look for context indicators
        for (index, word) in words.enumerated() {
            if word.lowercased().contains("after") && index + 1 < words.count {
                return words[index + 1]
            }
            if word.lowercased().contains("during") && index + 1 < words.count {
                return words[index + 1]
            }
        }
        
        return ""
    }
}

// MARK: - Message Category Model

struct MessageCategory: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String?
    let tags: [String]?
    
    var displayName: String {
        if let emoji = emoji {
            return "\(emoji) \(name)"
        }
        return name
    }
}

struct MessageCategoriesResponse: Codable {
    let categories: [MessageCategory]
    let success: Bool
}

// MARK: - Message Stats

struct MessageStats {
    let totalGenerated: Int
    let recentCount: Int
    let favoriteCategory: String?
    let categoryBreakdown: [String: Int]
    
    var averagePerCategory: Double {
        guard !categoryBreakdown.isEmpty else { return 0 }
        let total = categoryBreakdown.values.reduce(0, +)
        return Double(total) / Double(categoryBreakdown.count)
    }
    
    var mostUsedCategories: [(category: String, count: Int)] {
        return categoryBreakdown
            .sorted { $0.value > $1.value }
            .map { (category: $0.key, count: $0.value) }
    }
}

// MARK: - Cache Configuration Extension

private extension CacheConfiguration {
    func with(cacheKey: String) -> CacheConfiguration {
        return CacheConfiguration(
            strategy: self.strategy,
            cache: self.cache,
            cacheKey: cacheKey,
            policy: self.policy
        )
    }
}