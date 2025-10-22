//
//  RecentMessagesManager.swift
//  BlueBoxy
//
//  Service for managing recent messages with automatic 24-hour cleanup.
//  Stores generated messages locally and removes them after 24 hours.
//

import Foundation
import Combine
import UIKit

// MARK: - Recent Message Model

struct RecentMessage: Codable, Identifiable {
    let id: String
    let content: String
    let category: String
    let categoryName: String
    let generatedAt: Date
    let savedAt: Date
    let isFavorite: Bool
    let metadata: MessageMetadata
    
    struct MessageMetadata: Codable {
        let wordCount: Int
        let tone: String
        let personalityMatch: String
        let estimatedImpact: String
    }
    
    init(id: String, content: String, category: String, categoryName: String, generatedAt: Date, savedAt: Date, isFavorite: Bool, metadata: MessageMetadata) {
        self.id = id
        self.content = content
        self.category = category
        self.categoryName = categoryName
        self.generatedAt = generatedAt
        self.savedAt = savedAt
        self.isFavorite = isFavorite
        self.metadata = metadata
    }
    
    init(from message: ComprehensiveGeneratedMessage) {
        self.id = message.id
        self.content = message.content
        self.category = message.category.rawValue
        self.categoryName = message.category.displayName
        self.generatedAt = message.generatedAt
        self.savedAt = Date()
        self.isFavorite = false
        self.metadata = MessageMetadata(
            wordCount: message.content.split(separator: " ").count,
            tone: message.tone.rawValue,
            personalityMatch: message.personalityMatch,
            estimatedImpact: message.estimatedImpact.rawValue
        )
    }
    
    /// Check if this message is older than 24 hours
    var isExpired: Bool {
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return generatedAt < twentyFourHoursAgo
    }
    
    /// Time remaining until expiration
    var timeUntilExpiration: TimeInterval {
        let expirationDate = generatedAt.addingTimeInterval(24 * 60 * 60)
        return expirationDate.timeIntervalSince(Date())
    }
    
    /// Display time ago string
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: generatedAt, relativeTo: Date())
    }
}

// MARK: - Recent Messages Manager

@MainActor
final class RecentMessagesManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var recentMessages: [RecentMessage] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Configuration
    
    static let shared = RecentMessagesManager()
    private let storageKey = "BlueBoxy_RecentMessages"
    private let maxStorageSize = 100 // Maximum messages to keep in storage
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Private Properties
    
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupCleanupTimer()
        loadRecentMessages()
        observeAppLifecycle()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Add a newly generated message to recent messages
    func addRecentMessage(_ message: ComprehensiveGeneratedMessage) {
        let recentMessage = RecentMessage(from: message)
        
        // Add to the beginning of the array
        recentMessages.insert(recentMessage, at: 0)
        
        // Remove duplicates (same content)
        recentMessages = recentMessages.removingDuplicates { $0.content == $1.content }
        
        // Limit storage size
        if recentMessages.count > maxStorageSize {
            recentMessages = Array(recentMessages.prefix(maxStorageSize))
        }
        
        // Save to persistent storage
        saveRecentMessages()
        
        print("✅ Added recent message: \(message.category.displayName) - \(message.content.prefix(50))...")
    }
    
    /// Get recent messages for today only
    func getRecentMessages() -> [RecentMessage] {
        let today = Calendar.current.startOfDay(for: Date())
        return recentMessages.filter { message in
            Calendar.current.isDate(message.generatedAt, inSameDayAs: today)
        }
    }
    
    /// Get recent messages count for today
    var todayMessagesCount: Int {
        getRecentMessages().count
    }
    
    /// Toggle favorite status for a message
    func toggleFavorite(messageId: String) {
        if let index = recentMessages.firstIndex(where: { $0.id == messageId }) {
            let originalMessage = recentMessages[index]
            recentMessages[index] = RecentMessage(
                id: originalMessage.id,
                content: originalMessage.content,
                category: originalMessage.category,
                categoryName: originalMessage.categoryName,
                generatedAt: originalMessage.generatedAt,
                savedAt: originalMessage.savedAt,
                isFavorite: !originalMessage.isFavorite,
                metadata: originalMessage.metadata
            )
            saveRecentMessages()
        }
    }
    
    /// Clear all recent messages
    func clearAllRecentMessages() {
        recentMessages.removeAll()
        saveRecentMessages()
        print("🗑️ Cleared all recent messages")
    }
    
    /// Manually trigger cleanup
    func performCleanup() {
        let originalCount = recentMessages.count
        recentMessages = recentMessages.filter { !$0.isExpired }
        
        if recentMessages.count != originalCount {
            saveRecentMessages()
            print("🧹 Cleaned up \(originalCount - recentMessages.count) expired messages")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performCleanup()
            }
        }
    }
    
    private func observeAppLifecycle() {
        // Perform cleanup when app becomes active
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performCleanup()
            }
            .store(in: &cancellables)
        
        // Save messages when app enters background
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveRecentMessages()
            }
            .store(in: &cancellables)
    }
    
    private func loadRecentMessages() {
        isLoading = true
        defer { isLoading = false }
        
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("ℹ️ No recent messages found in storage")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            recentMessages = try decoder.decode([RecentMessage].self, from: data)
            
            // Immediately clean up expired messages on load
            performCleanup()
            
            print("✅ Loaded \(recentMessages.count) recent messages from storage")
        } catch {
            print("❌ Failed to load recent messages: \(error.localizedDescription)")
            recentMessages = []
        }
    }
    
    private func saveRecentMessages() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recentMessages)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("✅ Saved \(recentMessages.count) recent messages to storage")
        } catch {
            print("❌ Failed to save recent messages: \(error.localizedDescription)")
        }
    }
}

// MARK: - Array Extension for Removing Duplicates

private extension Array {
    func removingDuplicates<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return self.filter { element in
            let key = element[keyPath: keyPath]
            return seen.insert(key).inserted
        }
    }
    
    func removingDuplicates(by predicate: (Element, Element) -> Bool) -> [Element] {
        var result = [Element]()
        for element in self {
            if !result.contains(where: { predicate(element, $0) }) {
                result.append(element)
            }
        }
        return result
    }
}

// MARK: - RecentMessage Extensions for UI

extension RecentMessage {
    /// Get category color for UI display
    var categoryColor: MessageCategoryType? {
        return MessageCategoryType(rawValue: category)
    }
    
    /// Get display format for the message preview
    var previewText: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    /// Get formatted time for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: generatedAt)
    }
}