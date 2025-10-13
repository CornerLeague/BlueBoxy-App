import Foundation
import SwiftUI

// MARK: - Cache Protocol

protocol CacheProvider {
    func save<T: Codable>(_ item: T, for key: String, expiration: TimeInterval?) async
    func load<T: Codable>(for key: String, type: T.Type) async -> T?
    func remove(for key: String) async
    func clear() async
    func isExpired(for key: String) async -> Bool
    func getCacheSize() async -> Int64
}

// MARK: - Cache Manager

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    private let fileCache = FileCache()
    private let memoryCache = MemoryCache()
    
    // Cache configuration
    private let defaultExpiration: TimeInterval = 3600 // 1 hour
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    
    @Published var cacheSize: Int64 = 0
    @Published var isClearing = false
    
    private init() {
        Task {
            await updateCacheSize()
        }
    }
    
    // MARK: - Public Methods
    
    func save<T: Codable>(_ item: T, for key: String, strategy: CacheStrategy = .hybrid()) async {
        let cacheItem = CacheItem(
            data: item,
            timestamp: Date(),
            expiration: strategy.expiration
        )
        
        switch strategy {
        case .memoryOnly:
            await memoryCache.save(cacheItem, for: key)
        case .diskOnly:
            await fileCache.save(cacheItem, for: key, expiration: strategy.expiration)
        case .hybrid:
            // Save to both memory and disk
            await memoryCache.save(cacheItem, for: key)
            await fileCache.save(cacheItem, for: key, expiration: strategy.expiration)
        }
        
        await updateCacheSize()
    }
    
    func load<T: Codable>(for key: String, type: T.Type, strategy: CacheStrategy = .hybrid()) async -> T? {
        switch strategy {
        case .memoryOnly:
            return await memoryCache.load(for: key, type: type)
        case .diskOnly:
            return await fileCache.load(for: key, type: type)
        case .hybrid:
            // Try memory first, then disk
            if let item = await memoryCache.load(for: key, type: type) {
                return item
            }
            
            if let item = await fileCache.load(for: key, type: type) {
                // Populate memory cache for faster future access
                let cacheItem = CacheItem(
                    data: item,
                    timestamp: Date(),
                    expiration: strategy.expiration
                )
                await memoryCache.save(cacheItem, for: key)
                return item
            }
            
            return nil
        }
    }
    
    func remove(for key: String) async {
        await memoryCache.remove(for: key)
        await fileCache.remove(for: key)
        await updateCacheSize()
    }
    
    func clear() async {
        isClearing = true
        
        await memoryCache.clear()
        await fileCache.clear()
        await updateCacheSize()
        
        isClearing = false
    }
    
    func isExpired(for key: String) async -> Bool {
        // Check memory first for speed
        if await memoryCache.isExpired(for: key) == false {
            return false
        }
        return await fileCache.isExpired(for: key)
    }
    
    private func updateCacheSize() async {
        let diskSize = await fileCache.getCacheSize()
        let memorySize = await memoryCache.getCacheSize()
        cacheSize = diskSize + memorySize
        
        // Cleanup if cache is too large
        if cacheSize > maxCacheSize {
            await performCacheCleanup()
        }
    }
    
    private func performCacheCleanup() async {
        await fileCache.cleanupExpired()
        await memoryCache.cleanupExpired()
        await updateCacheSize()
    }
}

// MARK: - Cache Strategy

enum CacheStrategy {
    case memoryOnly(expiration: TimeInterval? = nil)
    case diskOnly(expiration: TimeInterval? = nil)
    case hybrid(expiration: TimeInterval? = nil)
    
    var expiration: TimeInterval? {
        switch self {
        case .memoryOnly(let exp), .diskOnly(let exp), .hybrid(let exp):
            return exp ?? 3600 // Default 1 hour
        }
    }
}

// MARK: - Cache Item

struct CacheItem<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let expiration: TimeInterval?
    
    var isExpired: Bool {
        guard let expiration = expiration else { return false }
        return Date().timeIntervalSince(timestamp) > expiration
    }
}

// MARK: - File Cache Adapter
// Using FileResponseCache from Networking/ResponseCache.swift

class FileCache: CacheProvider {
    private let fileCache: FileResponseCache
    
    init() {
        self.fileCache = FileResponseCache(folderName: "CacheManager")
    }
    
    func save<T: Codable>(_ item: T, for key: String, expiration: TimeInterval?) async {
        do {
            let data = try JSONEncoder().encode(item)
            fileCache.save(data, for: key)
        } catch {
            print("Failed to save item to file cache: \(error)")
        }
    }
    
    func load<T: Codable>(for key: String, type: T.Type) async -> T? {
        guard let data = fileCache.load(for: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode item from file cache: \(error)")
            return nil
        }
    }
    
    func remove(for key: String) async {
        fileCache.remove(for: key)
    }
    
    func clear() async {
        fileCache.clearAll()
    }
    
    func isExpired(for key: String) async -> Bool {
        guard let metadata = fileCache.metadata(for: key) else { return true }
        // Default 1 hour expiration
        return metadata.age > 3600
    }
    
    func getCacheSize() async -> Int64 {
        // This would require extending FileResponseCache to provide size info
        return 0 // Placeholder
    }
    
    func cleanupExpired() async {
        // This method performs cleanup of expired files
        // The FileResponseCache already handles cleanup internally through its performCleanup method
        // For explicit expired item cleanup, we would need to extend FileResponseCache
        // For now, this is a placeholder that could trigger the underlying cache cleanup
        
        // Note: FileResponseCache uses file modification time and size-based cleanup
        // rather than explicit expiration checking. This is sufficient for most use cases.
    }
}

// MARK: - Memory Cache

actor MemoryCache: CacheProvider {
    private var cache: [String: Any] = [:]
    private let maxItems = 100
    
    func save<T: Codable>(_ item: T, for key: String, expiration: TimeInterval? = nil) async {
        let cacheItem = CacheItem(
            data: item,
            timestamp: Date(),
            expiration: expiration
        )
        
        cache[key] = cacheItem
        
        // Cleanup if too many items
        if cache.count > maxItems {
            await cleanupOldest()
        }
    }
    
    func load<T: Codable>(for key: String, type: T.Type) async -> T? {
        guard let item = cache[key] as? CacheItem<T> else { return nil }
        
        if item.isExpired {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return item.data
    }
    
    func remove(for key: String) async {
        cache.removeValue(forKey: key)
    }
    
    func clear() async {
        cache.removeAll()
    }
    
    func isExpired(for key: String) async -> Bool {
        guard let item = cache[key] else { return true }
        
        // Use reflection to check if the item has isExpired property
        let mirror = Mirror(reflecting: item)
        for (label, value) in mirror.children {
            if label == "isExpired", let isExpired = value as? Bool {
                return isExpired
            }
        }
        
        return false
    }
    
    func getCacheSize() async -> Int64 {
        // Rough estimation of memory usage
        return Int64(cache.count * 1024) // Assume ~1KB per item
    }
    
    func cleanupExpired() async {
        var keysToRemove: [String] = []
        
        for (key, value) in cache {
            // Use reflection to check if the item has isExpired property
            let mirror = Mirror(reflecting: value)
            for (label, mirrorValue) in mirror.children {
                if label == "isExpired", let isExpired = mirrorValue as? Bool, isExpired {
                    keysToRemove.append(key)
                    break
                }
            }
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private func cleanupOldest() async {
        // Remove oldest 20% of items
        let itemsToRemove = maxItems / 5
        let sortedKeys = cache.keys.sorted()
        
        for i in 0..<min(itemsToRemove, sortedKeys.count) {
            cache.removeValue(forKey: sortedKeys[i])
        }
    }
}

// MARK: - Cache Keys

enum CacheKey {
    static let dashboardActivities = "dashboard_activities"
    static let dashboardStats = "dashboard_stats"
    static let dashboardEvents = "dashboard_events"
    static let userProfile = "user_profile"
    static let aiInsights = "ai_insights"
    static let recommendations = "recommendations"
    
    // Dynamic keys
    static func activityDetails(_ id: String) -> String {
        "activity_details_\(id)"
    }
    
    static func userPreferences(_ userId: String) -> String {
        "user_preferences_\(userId)"
    }
}

// MARK: - Cacheable Protocol

protocol Cacheable {
    var cacheKey: String { get }
    var cacheExpiration: TimeInterval { get }
    var cacheStrategy: CacheStrategy { get }
}

extension Array: Cacheable where Element == Activity {
    var cacheKey: String { CacheKey.dashboardActivities }
    var cacheExpiration: TimeInterval { 1800 } // 30 minutes
    var cacheStrategy: CacheStrategy { .hybrid(expiration: cacheExpiration) }
}

extension UserStatsResponse: Cacheable {
    var cacheKey: String { CacheKey.dashboardStats }
    var cacheExpiration: TimeInterval { 3600 } // 1 hour
    var cacheStrategy: CacheStrategy { .hybrid(expiration: cacheExpiration) }
}

// Additional Array extensions can be created with different conditional constraints
// if needed, but must have unique Element types to avoid conflicts
