//
//  RetryableMessagingService.swift
//  BlueBoxy
//
//  Enhanced messaging service with intelligent retry logic, error recovery, and fallback mechanisms
//  Builds on the existing RetryStrategy and MessagingAPIService infrastructure
//

import Foundation
import Combine
import SwiftUI

// MARK: - Retryable Messaging Service Protocol

protocol RetryableMessagingServiceProtocol {
    func generateMessage(
        request: MessageGenerateRequest,
        retryPolicy: BackoffPolicy?
    ) async -> Result<MessageGenerationResponse, NetworkError>
    
    func loadCategories(
        retryPolicy: BackoffPolicy?
    ) async -> Result<[MessageCategory], NetworkError>
    
    func saveMessage(
        _ message: ComprehensiveGeneratedMessage,
        retryPolicy: BackoffPolicy?
    ) async -> Result<Void, NetworkError>
    
    func loadMessageHistory(
        retryPolicy: BackoffPolicy?
    ) async -> Result<[ComprehensiveGeneratedMessage], NetworkError>
    
    // Reactive versions with retry
    func generateMessagePublisher(
        request: MessageGenerateRequest,
        retryPolicy: BackoffPolicy?
    ) -> AnyPublisher<MessageGenerationResponse, NetworkError>
    
    func loadCategoriesPublisher(
        retryPolicy: BackoffPolicy?
    ) -> AnyPublisher<[MessageCategory], NetworkError>
}

// MARK: - Retryable Messaging Service Implementation

final class RetryableMessagingService: RetryableMessagingServiceProtocol, ObservableObject {
    
    // MARK: - Dependencies
    
    private let apiService: MessagingAPIServiceProtocol
    private let networkClient: MessagingNetworkClient
    private let fallbackProvider: MessagingFallbackProvider
    
    // MARK: - Published State
    
    @Published private(set) var connectionQuality: ConnectionQuality = .excellent
    @Published private(set) var retryStats: MessagingRetryStatistics = .init()
    @Published private(set) var isOfflineMode: Bool = false
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = OperationQueue()
    
    // MARK: - Initialization
    
    init(
        apiService: MessagingAPIServiceProtocol,
        networkClient: MessagingNetworkClient,
        fallbackProvider: MessagingFallbackProvider = DefaultFallbackProvider()
    ) {
        self.apiService = apiService
        self.networkClient = networkClient
        self.fallbackProvider = fallbackProvider
        
        setupOperationQueue()
        monitorConnectionQuality()
    }
    
    // MARK: - Public API (Async/Await)
    
    func generateMessage(
        request: MessageGenerateRequest,
        retryPolicy: BackoffPolicy? = nil
    ) async -> Result<MessageGenerationResponse, NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .messageGeneration)
        
        return await withRetryAndFallback(
            operation: {
                try await self.apiService.generateMessage(request: request)
            },
            policy: policy,
            operationType: .messageGeneration,
            fallback: {
                // Provide fallback message generation
                await self.fallbackProvider.generateFallbackMessage(request: request)
            }
        )
    }
    
    func loadCategories(
        retryPolicy: BackoffPolicy? = nil
    ) async -> Result<[MessageCategory], NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .categoryLoading)
        
        return await withRetryAndFallback(
            operation: {
                try await self.apiService.fetchCategories()
            },
            policy: policy,
            operationType: .categoryLoading,
            fallback: {
                // Provide cached/default categories
                self.fallbackProvider.getDefaultCategories()
            }
        )
    }
    
    func saveMessage(
        _ message: ComprehensiveGeneratedMessage,
        retryPolicy: BackoffPolicy? = nil
    ) async -> Result<Void, NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .messageSaving)
        
        // For saving, we use a different strategy - queue locally if network fails
        let result = await withRetryAndFallback(
            operation: {
                try await self.apiService.saveMessage(message)
            },
            policy: policy,
            operationType: .messageSaving,
            fallback: {
                // Queue for later sync
                await self.fallbackProvider.queueMessageForSync(message)
            }
        )
        
        return result
    }
    
    func loadMessageHistory(
        retryPolicy: BackoffPolicy? = nil
    ) async -> Result<[ComprehensiveGeneratedMessage], NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .historyLoading)
        
        return await withRetryAndFallback(
            operation: {
                try await self.apiService.fetchMessageHistory()
            },
            policy: policy,
            operationType: .historyLoading,
            fallback: {
                // Provide locally cached history
                await self.fallbackProvider.getCachedHistory()
            }
        )
    }
    
    // MARK: - Public API (Combine)
    
    func generateMessagePublisher(
        request: MessageGenerateRequest,
        retryPolicy: BackoffPolicy? = nil
    ) -> AnyPublisher<MessageGenerationResponse, NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .messageGeneration)
        
        return createRetryablePublisher(
            operation: { [weak self] in
                guard let self = self else {
                    throw NetworkError.unknown(status: nil)
                }
                return try await self.apiService.generateMessage(request: request)
            },
            policy: policy,
            operationType: .messageGeneration
        )
    }
    
    func loadCategoriesPublisher(
        retryPolicy: BackoffPolicy? = nil
    ) -> AnyPublisher<[MessageCategory], NetworkError> {
        
        let policy = retryPolicy ?? smartRetryPolicy(for: .categoryLoading)
        
        return createRetryablePublisher(
            operation: { [weak self] in
                guard let self = self else {
                    throw NetworkError.unknown(status: nil)
                }
                return try await self.apiService.fetchCategories()
            },
            policy: policy,
            operationType: .categoryLoading
        )
    }
    
    // MARK: - Smart Retry Logic
    
    private func smartRetryPolicy(for operation: MessagingOperationType) -> BackoffPolicy {
        
        // Adjust retry policy based on connection quality and operation type
        switch (connectionQuality, operation) {
        case (.excellent, .messageGeneration):
            return .default
            
        case (.good, .messageGeneration):
            return .conservative
            
        case (.poor, .messageGeneration):
            return BackoffPolicy.custom(
                maxAttempts: 2,
                baseDelay: 1.0,
                maxDelay: 5.0
            )
            
        case (.poor, _), (.disconnected, _):
            return .failFast
            
        case (_, .categoryLoading), (_, .historyLoading):
            return .conservative
            
        case (_, .messageSaving):
            // More aggressive for saving (user expects it to work)
            return .aggressive
            
        default:
            return .default
        }
    }
    
    // MARK: - Retry with Fallback Implementation
    
    private func withRetryAndFallback<T>(
        operation: @escaping () async throws -> T,
        policy: BackoffPolicy,
        operationType: MessagingOperationType,
        fallback: @escaping () async -> Result<T, NetworkError>
    ) async -> Result<T, NetworkError> {
        
        // Record attempt
        await recordRetryAttempt(type: operationType, attempt: 1)
        
        var lastError: NetworkError = .unknown(status: nil)
        
        for attempt in 1...policy.maxAttempts {
            do {
                let result = try await operation()
                
                // Record success
                await recordRetrySuccess(type: operationType, attempt: attempt)
                
                return .success(result)
                
            } catch {
                lastError = ErrorMapper.map(error)
                
                // Check if we should retry
                if !shouldRetry(error: lastError, attempt: attempt, policy: policy, operationType: operationType) {
                    break
                }
                
                // Delay before retry
                if attempt < policy.maxAttempts {
                    let delay = policy.delay(for: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed, try fallback
        await recordRetryFailure(type: operationType, error: lastError)
        
        if lastError.isRetryable || connectionQuality == .poor || connectionQuality == .disconnected {
            return await fallback()
        } else {
            return .failure(lastError)
        }
    }
    
    // MARK: - Combine Publisher with Retry
    
    private func createRetryablePublisher<T>(
        operation: @escaping () async throws -> T,
        policy: BackoffPolicy,
        operationType: MessagingOperationType
    ) -> AnyPublisher<T, NetworkError> {
        
        return Future { [weak self] promise in
            Task { [weak self] in
                guard let self = self else {
                    promise(.failure(.unknown(status: nil)))
                    return
                }
                
                let result = await self.withRetryAndFallback(
                    operation: operation,
                    policy: policy,
                    operationType: operationType,
                    fallback: {
                        // For publishers, we don't provide fallback, just fail
                        return .failure(.connectivity("Fallback not available for reactive operations"))
                    }
                )
                
                switch result {
                case .success(let value):
                    promise(.success(value))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Retry Decision Logic
    
    private func shouldRetry(
        error: NetworkError,
        attempt: Int,
        policy: BackoffPolicy,
        operationType: MessagingOperationType
    ) -> Bool {
        
        // Don't retry on last attempt
        guard attempt < policy.maxAttempts else { return false }
        
        // Check base retryability
        guard error.isRetryable else { return false }
        
        // Consider connection quality
        switch connectionQuality {
        case .disconnected:
            return false
        case .poor:
            // Only retry connectivity errors when connection is poor
            return error.isConnectivityError
        case .good, .excellent:
            return true
        }
    }
    
    // MARK: - Connection Quality Monitoring
    
    private func monitorConnectionQuality() {
        // Monitor network conditions and adjust connection quality
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updateConnectionQuality()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionQuality() async {
        // Simple implementation - in production, you'd measure actual network performance
        let isConnected = await checkNetworkConnectivity()
        
        await MainActor.run {
            if !isConnected {
                self.connectionQuality = .disconnected
                self.isOfflineMode = true
            } else {
                self.connectionQuality = .excellent
                self.isOfflineMode = false
            }
        }
    }
    
    private func checkNetworkConnectivity() async -> Bool {
        // Placeholder implementation
        return true
    }
    
    // MARK: - Setup
    
    private func setupOperationQueue() {
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Statistics
    
    private func recordRetryAttempt(type: MessagingOperationType, attempt: Int) async {
        await MainActor.run {
            self.retryStats.recordAttempt(operation: type, attempt: attempt, success: false)
        }
    }
    
    private func recordRetrySuccess(type: MessagingOperationType, attempt: Int) async {
        await MainActor.run {
            self.retryStats.recordAttempt(operation: type, attempt: attempt, success: true)
        }
    }
    
    private func recordRetryFailure(type: MessagingOperationType, error: NetworkError) async {
        await MainActor.run {
            self.retryStats.recordFailure(operation: type, error: error)
        }
    }
}

// MARK: - Supporting Types

enum ConnectionQuality: CaseIterable, CustomStringConvertible {
    case excellent, good, poor, disconnected
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .poor: return "Poor"
        case .disconnected: return "Disconnected"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .poor: return .orange
        case .disconnected: return .red
        }
    }
}

enum MessagingOperationType: String, CaseIterable {
    case messageGeneration = "Message Generation"
    case categoryLoading = "Category Loading"
    case messageSaving = "Message Saving"
    case historyLoading = "History Loading"
    
    var icon: String {
        switch self {
        case .messageGeneration: return "brain.head.profile"
        case .categoryLoading: return "folder.circle"
        case .messageSaving: return "square.and.arrow.down"
        case .historyLoading: return "clock.arrow.circlepath"
        }
    }
}

struct MessagingRetryStatistics {
    private var operationStats: [MessagingOperationType: OperationStats] = [:]
    
    mutating func recordAttempt(operation: MessagingOperationType, attempt: Int, success: Bool) {
        var stats = operationStats[operation] ?? OperationStats()
        stats.recordAttempt(attempt: attempt, success: success)
        operationStats[operation] = stats
    }
    
    mutating func recordFailure(operation: MessagingOperationType, error: NetworkError) {
        var stats = operationStats[operation] ?? OperationStats()
        stats.recordFailure(error: error)
        operationStats[operation] = stats
    }
    
    func getStats(for operation: MessagingOperationType) -> OperationStats? {
        return operationStats[operation]
    }
    
    var allStats: [MessagingOperationType: OperationStats] {
        return operationStats
    }
}

struct OperationStats {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var totalAttempts: Int = 0
    var errorCounts: [String: Int] = [:]
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var averageAttempts: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalAttempts) / Double(totalRequests)
    }
    
    mutating func recordAttempt(attempt: Int, success: Bool) {
        if attempt == 1 {
            totalRequests += 1
        }
        totalAttempts += 1
        
        if success {
            successfulRequests += 1
        } else if attempt == 1 {
            failedRequests += 1
        }
    }
    
    mutating func recordFailure(error: NetworkError) {
        let errorKey = error.title
        errorCounts[errorKey, default: 0] += 1
    }
}

// MARK: - NetworkError Extensions

extension NetworkError {
    var isConnectivityError: Bool {
        switch self {
        case .connectivity:
            return true
        default:
            return false
        }
    }
}

// MARK: - Fallback Provider Protocol

protocol MessagingFallbackProvider {
    func generateFallbackMessage(request: MessageGenerateRequest) async -> Result<MessageGenerationResponse, NetworkError>
    func getDefaultCategories() -> Result<[MessageCategory], NetworkError>
    func queueMessageForSync(_ message: ComprehensiveGeneratedMessage) async -> Result<Void, NetworkError>
    func getCachedHistory() async -> Result<[ComprehensiveGeneratedMessage], NetworkError>
}

// MARK: - Default Fallback Provider

final class DefaultFallbackProvider: MessagingFallbackProvider {
    
    func generateFallbackMessage(request: MessageGenerateRequest) async -> Result<MessageGenerationResponse, NetworkError> {
        // Provide simple fallback message generation
        let context = ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: request.timeOfDay ?? .current,
            relationshipDuration: request.relationshipDuration,
            recentContext: request.recentContext,
            specialOccasion: request.specialOccasion,
            userPersonalityType: request.personalityType,
            partnerName: request.partnerName
        )
        
        let categoryType = MessageCategoryType(rawValue: request.category) ?? .dailyCheckins
        
        let fallbackMessage = ComprehensiveGeneratedMessage(
            id: UUID().uuidString,
            content: "Thank you for reaching out. I'll get back to you soon!",
            category: categoryType,
            personalityMatch: "offline-generated",
            tone: request.preferredTone.flatMap { MessageTone(rawValue: $0) } ?? .warm,
            estimatedImpact: .medium,
            context: context
        )
        
        // Convert ComprehensiveGeneratedMessage back to MessageItem format for response
        let messageItem = MessageItem(
            id: fallbackMessage.id,
            content: fallbackMessage.content,
            category: fallbackMessage.category.rawValue,
            personalityMatch: fallbackMessage.personalityMatch,
            tone: fallbackMessage.tone.rawValue,
            estimatedImpact: fallbackMessage.estimatedImpact.rawValue
        )
        
        let response = MessageGenerationResponse(
            success: true,
            messages: [messageItem],
            context: ["generation_mode": "offline_fallback"],
            error: nil
        )
        
        return .success(response)
    }
    
    func getDefaultCategories() -> Result<[MessageCategory], NetworkError> {
        let defaultCategories: [MessageCategory] = [
            MessageCategory(
                id: "general",
                name: "General",
                description: "General purpose messages",
                icon: "message.circle",
                color: .blue,
                priority: 1,
                personalityTags: ["professional", "friendly"],
                contextualHints: ["Always available offline"]
            ),
            MessageCategory(
                id: "followup",
                name: "Follow-up",
                description: "Following up on previous conversations",
                icon: "arrow.clockwise.circle",
                color: .green,
                priority: 2,
                personalityTags: ["persistent", "polite"],
                contextualHints: ["Reference previous interaction"]
            )
        ]
        
        return .success(defaultCategories)
    }
    
    func queueMessageForSync(_ message: ComprehensiveGeneratedMessage) async -> Result<Void, NetworkError> {
        // In a real implementation, you'd save to local storage for later sync
        // For now, just simulate success
        return .success(())
    }
    
    func getCachedHistory() async -> Result<[ComprehensiveGeneratedMessage], NetworkError> {
        // Return empty array as cached history
        return .success([])
    }
}

// MARK: - Preview Extensions

#if DEBUG
extension RetryableMessagingService {
    @MainActor
    static var preview: RetryableMessagingService {
        RetryableMessagingService(
            apiService: MockMessagingAPIService(),
            networkClient: MessagingNetworkClient(),
            fallbackProvider: DefaultFallbackProvider()
        )
    }
}

// Mock implementations for previews
class MockMessagingAPIService: MessagingAPIServiceProtocol {
    func fetchMessageCategories() async throws -> MessageCategoriesResponse {
        throw NetworkError.server("Mock server error")
    }
    
    func fetchEnhancedMessageCategories() async throws -> EnhancedMessageCategoriesResponse {
        throw NetworkError.server("Mock server error")
    }
    
    func generateMessages(request: MessageGenerateRequest) async throws -> MessageGenerationResponse {
        throw NetworkError.connectivity("Mock error")
    }
    
    func generateComprehensiveMessages(request: ComprehensiveMessageRequest) async throws -> ComprehensiveMessageResponse {
        throw NetworkError.connectivity("Mock error")
    }
    
    func fetchMessageHistory(limit: Int, offset: Int) async throws -> MessageHistoryResponse {
        return MessageHistoryResponse(messages: [], total: 0, page: 0, hasMore: false)
    }
    
    func saveMessage(messageId: String) async throws {
        // Mock save
    }
    
    func deleteMessage(messageId: String) async throws {
        // Mock delete
    }
    
    func favoriteMessage(messageId: String) async throws {
        // Mock favorite
    }
}

class MockRetryableAPIClient {
    // Mock implementation - use composition instead of inheritance
    let apiClient = APIClient.shared
}
#endif