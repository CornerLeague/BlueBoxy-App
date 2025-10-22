//
//  GenerationTracker.swift
//  BlueBoxy
//
//  Generation limit tracking system for activity recommendations
//  Enforces 3 generations per category per user
//

import Foundation
import SwiftUI

class GenerationTracker: ObservableObject {
    
    // MARK: - Constants
    
    private let maxGenerations = 3
    private let storageKey = "generation_tracker_data"
    private let resetIntervalHours: TimeInterval = 24 // 24 hours auto-reset
    
    // MARK: - Published Properties
    
    @Published private(set) var generationData: [String: GenerationInfo] = [:]
    
    // MARK: - Initialization
    
    init() {
        loadFromStorage()
        cleanupExpiredData()
    }
    
    // MARK: - Public Methods
    
    /// Get the tracking key for a user and category
    func trackingKey(userId: Int, category: ActivityCategory) -> String {
        return "\(userId)_\(category.rawValue)"
    }
    
    /// Increment generation count for a category
    func incrementGeneration(for key: String) {
        var info = generationData[key] ?? GenerationInfo()
        info.count += 1
        info.lastGenerationDate = Date()
        generationData[key] = info
        saveToStorage()
        
        print("📈 Generation \(info.count) of \(maxGenerations) for key: \(key)")
    }
    
    /// Get remaining generations for a category
    func getGenerationsRemaining(for key: String) -> Int {
        let count = generationData[key]?.count ?? 0
        return max(0, maxGenerations - count)
    }
    
    /// Check if more generations are allowed
    func canGenerateMore(for key: String) -> Bool {
        let info = generationData[key]
        
        // Check if auto-reset period has passed
        if let lastDate = info?.lastGenerationDate {
            let hoursSinceLastGeneration = Date().timeIntervalSince(lastDate) / 3600
            if hoursSinceLastGeneration >= resetIntervalHours {
                resetGeneration(for: key)
                return true
            }
        }
        
        let count = info?.count ?? 0
        return count < maxGenerations
    }
    
    /// Reset generation count for a category
    func resetGeneration(for key: String) {
        generationData[key] = GenerationInfo()
        saveToStorage()
        print("🔄 Reset generation tracking for key: \(key)")
    }
    
    /// Add recommendation IDs to exclusion list
    func addPreviousRecommendations(for key: String, ids: [String]) {
        var info = generationData[key] ?? GenerationInfo()
        info.previousRecommendationIds.append(contentsOf: ids)
        generationData[key] = info
        saveToStorage()
        
        print("📝 Added \(ids.count) recommendations to exclusion list for key: \(key)")
    }
    
    /// Get list of previously recommended IDs to exclude
    func getPreviousRecommendations(for key: String) -> [String] {
        return generationData[key]?.previousRecommendationIds ?? []
    }
    
    /// Get current generation count
    func getCurrentGenerationCount(for key: String) -> Int {
        return generationData[key]?.count ?? 0
    }
    
    /// Get generation info for display
    func getGenerationInfo(for key: String) -> GenerationDisplayInfo {
        let count = getCurrentGenerationCount(for: key)
        let remaining = getGenerationsRemaining(for: key)
        let canGenerate = canGenerateMore(for: key)
        let isAtLimit = count >= maxGenerations
        
        return GenerationDisplayInfo(
            currentCount: count,
            maxCount: maxGenerations,
            remaining: remaining,
            canGenerateMore: canGenerate,
            isAtLimit: isAtLimit,
            message: generateMessage(count: count, remaining: remaining, isAtLimit: isAtLimit)
        )
    }
    
    /// Reset all generation tracking (for testing or user request)
    func resetAllGenerations() {
        generationData.removeAll()
        saveToStorage()
        print("🔄 Reset all generation tracking")
    }
    
    // MARK: - Private Methods
    
    private func generateMessage(count: Int, remaining: Int, isAtLimit: Bool) -> String {
        if count == 0 {
            return "Get fresh recommendations tailored to your preferences"
        } else if isAtLimit {
            return "You've reached the generation limit. Reset to get new recommendations."
        } else if remaining == 1 {
            return "Last generation available! Make it count."
        } else {
            return "\(remaining) more generations available"
        }
    }
    
    private func cleanupExpiredData() {
        let now = Date()
        var hasChanges = false
        
        for (key, info) in generationData {
            if let lastDate = info.lastGenerationDate {
                let hoursSince = now.timeIntervalSince(lastDate) / 3600
                if hoursSince >= resetIntervalHours {
                    generationData[key] = GenerationInfo()
                    hasChanges = true
                    print("🧹 Auto-reset expired data for key: \(key)")
                }
            }
        }
        
        if hasChanges {
            saveToStorage()
        }
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(generationData) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: GenerationInfo].self, from: data) else {
            return
        }
        generationData = decoded
    }
}

// MARK: - Supporting Types

struct GenerationInfo: Codable {
    var count: Int = 0
    var lastGenerationDate: Date?
    var previousRecommendationIds: [String] = []
}

struct GenerationDisplayInfo {
    let currentCount: Int
    let maxCount: Int
    let remaining: Int
    let canGenerateMore: Bool
    let isAtLimit: Bool
    let message: String
    
    var progressPercentage: Double {
        return Double(currentCount) / Double(maxCount)
    }
    
    var buttonTitle: String {
        if currentCount == 0 {
            return "Get Recommendations"
        } else if isAtLimit {
            return "Reset & Generate"
        } else {
            return "Generate More"
        }
    }
    
    var buttonIcon: String {
        if currentCount == 0 {
            return "wand.and.stars"
        } else if isAtLimit {
            return "arrow.clockwise"
        } else {
            return "sparkles"
        }
    }
}

// MARK: - Extensions

extension GenerationTracker {
    /// Convenience method for tracking with user and category
    func trackingKey(userId: Int, category: String) -> String {
        return "\(userId)_\(category)"
    }
    
    /// Check if should show reset option
    func shouldShowResetOption(for key: String) -> Bool {
        return !canGenerateMore(for: key)
    }
    
    /// Get status emoji for display
    func getStatusEmoji(for key: String) -> String {
        let count = getCurrentGenerationCount(for: key)
        switch count {
        case 0:
            return "✨"
        case 1:
            return "🎯"
        case 2:
            return "⚡"
        case 3...:
            return "🔒"
        default:
            return "✨"
        }
    }
}
