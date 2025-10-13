//
//  CachedAPIClient.swift
//  BlueBoxy
//
//  Cache-enabled API methods that try network first and fallback to cache
//  Provides offline support for key endpoints
//

import Foundation

// Using CacheStrategy from Core/Cache/CacheManager.swift

// MARK: - Network Cache Strategy

/// Strategy for handling network and cache interactions
enum NetworkCacheStrategy {
    case networkOnly
    case cacheOnly
    case networkFirst
    case cacheFirst
    case networkThenCache
}

// MARK: - Cache Configuration

/// Configuration for cached requests
struct CacheConfiguration {
    let strategy: NetworkCacheStrategy
    let cache: ResponseCache
    let cacheKey: String?
    let policy: BackoffPolicy
    
    /// Default configuration with network-first strategy
    static let `default` = CacheConfiguration(
        strategy: .networkFirst,
        cache: FileResponseCache(),
        cacheKey: nil,
        policy: .default
    )
    
    /// Offline-friendly configuration
    static let offline = CacheConfiguration(
        strategy: .cacheFirst,
        cache: FileResponseCache(),
        cacheKey: nil,
        policy: .conservative
    )
    
    /// Performance-optimized configuration
    static let performance = CacheConfiguration(
        strategy: .cacheFirst,
        cache: InMemoryResponseCache(),
        cacheKey: nil,
        policy: .failFast
    )
}

// MARK: - Cached API Client Class

class CachedAPIClient {
    static let shared = CachedAPIClient()
    
    let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    /// Execute request with caching support
    func getCached<T: Codable>(
        _ endpoint: Endpoint,
        configuration: CacheConfiguration = .default
    ) async -> Result<T, NetworkError> {
        
        let cacheKey = configuration.cacheKey ?? CacheKeyGenerator.key(for: endpoint)
        
        switch configuration.strategy {
        case .networkOnly:
            return await executeNetworkOnly(endpoint, policy: configuration.policy)
            
        case .cacheOnly:
            return executeCacheOnly(cacheKey, cache: configuration.cache)
            
        case .networkFirst:
            return await executeNetworkFirst(endpoint, cacheKey: cacheKey, 
                                           cache: configuration.cache, 
                                           policy: configuration.policy)
            
        case .cacheFirst:
            return await executeCacheFirst(endpoint, cacheKey: cacheKey, 
                                         cache: configuration.cache, 
                                         policy: configuration.policy)
            
        case .networkThenCache:
            return await executeNetworkThenCache(endpoint, cacheKey: cacheKey, 
                                               cache: configuration.cache, 
                                               policy: configuration.policy)
        }
    }
}

// MARK: - Private Implementation

private extension CachedAPIClient {
    
    // MARK: - Strategy Implementations
    
    func executeNetworkOnly<T: Codable>(
        _ endpoint: Endpoint,
        policy: BackoffPolicy
    ) async -> Result<T, NetworkError> {
        do {
            let result: T = try await apiClient.request(endpoint)
            return Result.success(result)
        } catch {
            return .failure(mapToNetworkError(error))
        }
    }
    
    func executeCacheOnly<T: Codable>(
        _ cacheKey: String,
        cache: ResponseCache
    ) -> Result<T, NetworkError> {
        guard let cachedData = cache.load(for: cacheKey) else {
            return .failure(.notFound)
        }
        
        do {
            let decodedValue = try APIConfiguration.decoder.decode(T.self, from: cachedData)
            
            #if DEBUG
            NetLog.logger.debug("📦 Cache hit for key: \(cacheKey, privacy: .public)")
            #endif
            
            return Result.success(decodedValue)
        } catch {
            #if DEBUG
            NetLog.logger.debug("📦 Cache decode error for \(cacheKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            #endif
            
            return .failure(.decoding(error.localizedDescription))
        }
    }
    
    func executeNetworkFirst<T: Codable>(
        _ endpoint: Endpoint,
        cacheKey: String,
        cache: ResponseCache,
        policy: BackoffPolicy
    ) async -> Result<T, NetworkError> {
        
        // Try network first
        let networkResult: Result<T, NetworkError> = await executeNetworkOnly(endpoint, policy: policy)
        
        switch networkResult {
        case .success(let value):
            // Save to cache on success
            saveToCache(value, key: cacheKey, cache: cache)
            return Result.success(value)
            
        case .failure(let networkError):
            // Fallback to cache
            #if DEBUG
            NetLog.logger.debug("🌐 Network failed, checking cache for: \(cacheKey, privacy: .public)")
            #endif
            
            let cacheResult: Result<T, NetworkError> = executeCacheOnly(cacheKey, cache: cache)
            
            switch cacheResult {
            case .success(let cachedValue):
                #if DEBUG
                NetLog.logger.debug("📦 Using cached data after network failure")
                #endif
                return Result.success(cachedValue)
                
            case .failure:
                // Return original network error if cache also fails
                return .failure(networkError)
            }
        }
    }
    
    private func executeCacheFirst<T: Codable>(
        _ endpoint: Endpoint,
        cacheKey: String,
        cache: ResponseCache,
        policy: BackoffPolicy
    ) async -> Result<T, NetworkError> {
        
        // Try cache first
        let cacheResult: Result<T, NetworkError> = executeCacheOnly(cacheKey, cache: cache)
        
        switch cacheResult {
        case .success(let cachedValue):
            #if DEBUG
            NetLog.logger.debug("📦 Cache hit, using cached data for: \(cacheKey, privacy: .public)")
            #endif
            return Result.success(cachedValue)
            
        case .failure:
            // Fallback to network
            #if DEBUG
            NetLog.logger.debug("📦 Cache miss, trying network for: \(cacheKey, privacy: .public)")
            #endif
            
            let networkResult: Result<T, NetworkError> = await executeNetworkOnly(endpoint, policy: policy)
            
            if case .success(let value) = networkResult {
                saveToCache(value, key: cacheKey, cache: cache)
            }
            
            return networkResult
        }
    }
    
    private func executeNetworkThenCache<T: Codable>(
        _ endpoint: Endpoint,
        cacheKey: String,
        cache: ResponseCache,
        policy: BackoffPolicy
    ) async -> Result<T, NetworkError> {
        
        let networkResult: Result<T, NetworkError> = await executeNetworkOnly(endpoint, policy: policy)
        
        if case .success(let value) = networkResult {
            saveToCache(value, key: cacheKey, cache: cache)
        }
        
        return networkResult
    }
    
    // MARK: - Helper Methods
    
    private func mapToNetworkError(_ error: Error) -> NetworkError {
        if let apiError = error as? APIServiceError {
            switch apiError {
            case .network(let networkError):
                return .connectivity(networkError.localizedDescription)
            case .badRequest(let message):
                return .badRequest(message: message)
            case .unauthorized:
                return .unauthorized
            case .notFound:
                return .notFound
            case .server(let message):
                return .server(message)
            case .unknown(let status):
                return .unknown(status: status)
            default:
                return .unknown(status: nil)
            }
        } else {
            return .connectivity(error.localizedDescription)
        }
    }
    
    private func saveToCache<T: Encodable>(_ value: T, key: String, cache: ResponseCache) {
        do {
            let data = try APIConfiguration.encoder.encode(value)
            cache.save(data, for: key)
            
            #if DEBUG
            let sizeKB = Double(data.count) / 1024.0
            NetLog.logger.debug("💾 Saved \(String(format: "%.1f", sizeKB), privacy: .public)KB to cache for key: \(key, privacy: .public)")
            #endif
        } catch {
            #if DEBUG
            NetLog.logger.debug("💾 Failed to save to cache: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }
    
    /// Check if cached data exists for endpoint
    func hasCachedData(for endpoint: Endpoint, cache: ResponseCache = FileResponseCache()) -> Bool {
        let cacheKey = CacheKeyGenerator.key(for: endpoint)
        return cache.exists(for: cacheKey)
    }
    
    /// Get cache metadata for endpoint
    func cacheMetadata(for endpoint: Endpoint, cache: ResponseCache = FileResponseCache()) -> CacheMetadata? {
        let cacheKey = CacheKeyGenerator.key(for: endpoint)
        return cache.metadata(for: cacheKey)
    }
    
    /// Clear cached data for endpoint
    func clearCache(for endpoint: Endpoint, cache: ResponseCache = FileResponseCache()) {
        let cacheKey = CacheKeyGenerator.key(for: endpoint)
        cache.remove(for: cacheKey)
    }
}

// MARK: - Convenience Extensions

extension APIClient {
    
    /// Get cached data with automatic fallback
    func getCachedWithFallback<T: Decodable>(
        _ endpoint: Endpoint,
        cache: ResponseCache = FileResponseCache(),
        cacheKey: String? = nil,
        policy: BackoffPolicy = .default
    ) async -> Result<T, NetworkError> {
        
        let config = CacheConfiguration(
            strategy: .networkFirst,
            cache: cache,
            cacheKey: cacheKey,
            policy: policy
        )
        
        return await getCached(endpoint, configuration: config)
    }
    
    /// Get offline-friendly data (cache-first)
    func getCachedOffline<T: Decodable>(
        _ endpoint: Endpoint,
        cache: ResponseCache = FileResponseCache(),
        cacheKey: String? = nil
    ) async -> Result<T, NetworkError> {
        
        let config = CacheConfiguration(
            strategy: .cacheFirst,
            cache: cache,
            cacheKey: cacheKey,
            policy: .conservative
        )
        
        return await getCached(endpoint, configuration: config)
    }
    
    /// Force refresh data and update cache
    func refreshAndCache<T: Decodable>(
        _ endpoint: Endpoint,
        cache: ResponseCache = FileResponseCache(),
        cacheKey: String? = nil,
        policy: BackoffPolicy = .default
    ) async -> Result<T, NetworkError> {
        
        let config = CacheConfiguration(
            strategy: .networkThenCache,
            cache: cache,
            cacheKey: cacheKey,
            policy: policy
        )
        
        return await getCached(endpoint, configuration: config)
    }
}

// Using CacheManager from Core/Cache/CacheManager.swift

// MARK: - Cache Statistics

struct CacheStats {
    let totalItems: Int
    let totalSize: Int64
    let oldestItem: Date?
    let newestItem: Date?
    
    var totalSizeMB: Double {
        return Double(totalSize) / (1024 * 1024)
    }
}

// MARK: - Debug Utilities

#if DEBUG
extension APIClient {
    /// Print cache information for debugging
    func debugCache(for endpoint: Endpoint, cache: ResponseCache = FileResponseCache()) {
        let cacheKey = CacheKeyGenerator.key(for: endpoint)
        let exists = cache.exists(for: cacheKey)
        let metadata = cache.metadata(for: cacheKey)
        
        print("🔍 Cache Debug for: \(endpoint.path)")
        print("   Key: \(cacheKey)")
        print("   Exists: \(exists)")
        
        if let meta = metadata {
            let ageMins = meta.age / 60
            let sizeMB = Double(meta.size) / (1024 * 1024)
            print("   Size: \(String(format: "%.2f", sizeMB))MB")
            print("   Age: \(String(format: "%.1f", ageMins)) minutes")
            print("   Created: \(meta.createdAt)")
        }
    }
}
#endif