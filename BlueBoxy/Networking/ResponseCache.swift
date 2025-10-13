//
//  ResponseCache.swift
//  BlueBoxy
//
//  Response caching system for offline support
//  Provides file-based storage for last-known-good responses
//

import Foundation

// MARK: - Response Cache Protocol

/// Protocol for caching API responses for offline access
protocol ResponseCache {
    /// Load cached data for the given key
    func load(for key: String) -> Data?
    
    /// Save data to cache with the given key
    func save(_ data: Data, for key: String)
    
    /// Remove cached data for the given key
    func remove(for key: String)
    
    /// Clear all cached data
    func clearAll()
    
    /// Check if data exists for the given key
    func exists(for key: String) -> Bool
    
    /// Get metadata about cached item (size, creation date, etc.)
    func metadata(for key: String) -> CacheMetadata?
}

// MARK: - Cache Metadata

/// Metadata about cached items
struct CacheMetadata {
    let size: Int64
    let createdAt: Date
    let lastAccessed: Date?
    
    /// Age of the cached item
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    /// Whether the item is considered stale based on given TTL
    func isStale(ttl: TimeInterval) -> Bool {
        return age > ttl
    }
}

// MARK: - File Response Cache

/// File-based implementation of ResponseCache
final class FileResponseCache: ResponseCache {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "file-response-cache", qos: .utility, attributes: .concurrent)
    private let maxCacheSize: Int64 // Maximum cache size in bytes
    private let defaultTTL: TimeInterval // Default time-to-live in seconds
    
    /// Initialize with custom cache directory and settings
    init(folderName: String = "ResponseCache", 
         maxCacheSize: Int64 = 50 * 1024 * 1024, // 50MB default
         defaultTTL: TimeInterval = 24 * 60 * 60) { // 24 hours default
        
        self.maxCacheSize = maxCacheSize
        self.defaultTTL = defaultTTL
        
        // Create cache directory in Caches directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent(folderName, isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Start background cleanup
        scheduleCleanup()
    }
    
    // MARK: - ResponseCache Implementation
    
    func load(for key: String) -> Data? {
        return queue.sync {
            let fileURL = fileURL(for: key)
            
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                
                // Update access time
                updateAccessTime(for: fileURL)
                
                return data
            } catch {
                #if DEBUG
                print("📦 Cache read error for \(key): \(error)")
                #endif
                return nil
            }
        }
    }
    
    func save(_ data: Data, for key: String) {
        queue.async(flags: .barrier) {
            let fileURL = self.fileURL(for: key)
            
            do {
                try data.write(to: fileURL, options: .atomic)
                
                #if DEBUG
                let sizeKB = Double(data.count) / 1024.0
                print("💾 Cached \(String(format: "%.1f", sizeKB))KB for key: \(key)")
                #endif
                
                // Check if we need to cleanup after adding new data
                self.cleanupIfNeeded()
                
            } catch {
                #if DEBUG
                print("📦 Cache write error for \(key): \(error)")
                #endif
            }
        }
    }
    
    func remove(for key: String) {
        queue.async(flags: .barrier) {
            let fileURL = self.fileURL(for: key)
            
            do {
                try self.fileManager.removeItem(at: fileURL)
                
                #if DEBUG
                print("🗑️ Removed cached item: \(key)")
                #endif
            } catch {
                #if DEBUG
                print("📦 Cache removal error for \(key): \(error)")
                #endif
            }
        }
    }
    
    func clearAll() {
        queue.async(flags: .barrier) {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, 
                                                                       includingPropertiesForKeys: nil)
                for fileURL in contents {
                    try self.fileManager.removeItem(at: fileURL)
                }
                
                #if DEBUG
                print("🧹 Cleared all cached items (\(contents.count) files)")
                #endif
            } catch {
                #if DEBUG
                print("📦 Cache clear error: \(error)")
                #endif
            }
        }
    }
    
    func exists(for key: String) -> Bool {
        return queue.sync {
            let fileURL = fileURL(for: key)
            return fileManager.fileExists(atPath: fileURL.path)
        }
    }
    
    func metadata(for key: String) -> CacheMetadata? {
        return queue.sync {
            let fileURL = fileURL(for: key)
            
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) else {
                return nil
            }
            
            let size = attributes[.size] as? Int64 ?? 0
            let createdAt = attributes[.creationDate] as? Date ?? Date()
            let lastAccessed = attributes[.modificationDate] as? Date
            
            return CacheMetadata(size: size, createdAt: createdAt, lastAccessed: lastAccessed)
        }
    }
    
    // MARK: - Private Methods
    
    private func fileURL(for key: String) -> URL {
        let safeFileName = key.safeFileName()
        return cacheDirectory.appendingPathComponent(safeFileName)
    }
    
    private func updateAccessTime(for fileURL: URL) {
        // Update modification date to track access time
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
    }
    
    private func scheduleCleanup() {
        // Schedule periodic cleanup every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.cleanupIfNeeded()
        }
    }
    
    private func cleanupIfNeeded() {
        queue.async(flags: .barrier) {
            let currentSize = self.calculateCacheSize()
            
            #if DEBUG
            let sizeMB = Double(currentSize) / (1024 * 1024)
            print("📊 Cache size: \(String(format: "%.2f", sizeMB))MB / \(String(format: "%.2f", Double(self.maxCacheSize) / (1024 * 1024)))MB")
            #endif
            
            if currentSize > self.maxCacheSize {
                self.performCleanup()
            }
        }
    }
    
    private func calculateCacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, 
                                                                 includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return contents.reduce(0) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
    
    private func performCleanup() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else {
            return
        }
        
        // Sort files by last modified date (oldest first)
        let sortedFiles = contents.compactMap { fileURL -> (URL, Date, Int64)? in
            guard let resources = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = resources.contentModificationDate,
                  let fileSize = resources.fileSize else {
                return nil
            }
            return (fileURL, modificationDate, Int64(fileSize))
        }.sorted { $0.1 < $1.1 }
        
        var currentSize = calculateCacheSize()
        let targetSize = Int64(Double(maxCacheSize) * 0.8) // Remove until we're at 80% capacity
        
        var removedFiles = 0
        
        for (fileURL, _, fileSize) in sortedFiles {
            guard currentSize > targetSize else { break }
            
            do {
                try fileManager.removeItem(at: fileURL)
                currentSize -= fileSize
                removedFiles += 1
            } catch {
                #if DEBUG
                print("📦 Failed to remove cached file: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        if removedFiles > 0 {
            let newSizeMB = Double(currentSize) / (1024 * 1024)
            print("🧹 Cache cleanup: Removed \(removedFiles) files, new size: \(String(format: "%.2f", newSizeMB))MB")
        }
        #endif
    }
}

// MARK: - String Extensions

private extension String {
    /// Convert string to safe filename by replacing invalid characters
    func safeFileName() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:?<>\\|*\"")
        let validComponents = self.components(separatedBy: invalidCharacters)
        let safeString = validComponents.joined(separator: "_")
        
        // Ensure the filename isn't too long
        if safeString.count > 200 {
            let hash = safeString.hash
            return String(safeString.prefix(180)) + "_\(abs(hash))"
        }
        
        return safeString
    }
}

// MARK: - In-Memory Cache (for testing and performance)

/// In-memory cache implementation for testing or performance-critical scenarios
final class InMemoryResponseCache: ResponseCache {
    private var cache: [String: (data: Data, metadata: CacheMetadata)] = [:]
    private let queue = DispatchQueue(label: "memory-response-cache", attributes: .concurrent)
    private let maxItems: Int
    
    init(maxItems: Int = 100) {
        self.maxItems = maxItems
    }
    
    func load(for key: String) -> Data? {
        return queue.sync {
            return cache[key]?.data
        }
    }
    
    func save(_ data: Data, for key: String) {
        queue.async(flags: .barrier) {
            let metadata = CacheMetadata(size: Int64(data.count), createdAt: Date(), lastAccessed: nil)
            self.cache[key] = (data, metadata)
            
            // Remove oldest items if we exceed maxItems
            if self.cache.count > self.maxItems {
                let sortedKeys = self.cache.keys.sorted { key1, key2 in
                    let date1 = self.cache[key1]?.metadata.createdAt ?? Date.distantPast
                    let date2 = self.cache[key2]?.metadata.createdAt ?? Date.distantPast
                    return date1 < date2
                }
                
                let keysToRemove = sortedKeys.prefix(self.cache.count - self.maxItems)
                for key in keysToRemove {
                    self.cache.removeValue(forKey: key)
                }
            }
        }
    }
    
    func remove(for key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func exists(for key: String) -> Bool {
        return queue.sync {
            return cache[key] != nil
        }
    }
    
    func metadata(for key: String) -> CacheMetadata? {
        return queue.sync {
            return cache[key]?.metadata
        }
    }
}

// MARK: - Cache Key Generation

/// Utility for generating consistent cache keys
struct CacheKeyGenerator {
    
    /// Generate cache key for an endpoint with its parameters
    static func key(for endpoint: Endpoint) -> String {
        var components = [endpoint.path]
        
        // Add query parameters to key
        if let queryItems = endpoint.query, !queryItems.isEmpty {
            let queryString = queryItems
                .compactMap { item in
                    guard let value = item.value else { return item.name }
                    return "\(item.name)=\(value)"
                }
                .sorted()
                .joined(separator: "&")
            components.append(queryString)
        }
        
        return components.joined(separator: "?")
    }
    
    /// Generate cache key with custom identifier
    static func key(identifier: String, parameters: [String: Any] = [:]) -> String {
        guard !parameters.isEmpty else { return identifier }
        
        let paramString = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        return "\(identifier)?\(paramString)"
    }
}