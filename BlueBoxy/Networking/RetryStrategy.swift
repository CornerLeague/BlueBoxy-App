//
//  RetryStrategy.swift
//  BlueBoxy
//
//  Retry and backoff strategy with exponential backoff and jitter
//  Only retries idempotent GET requests on retryable errors
//

import Foundation

// MARK: - Retry Strategy

/// High-level retry strategy options
enum RetryStrategy {
    case noRetry
    case exponentialBackoff(maxAttempts: Int)
    case customPolicy(BackoffPolicy)
    
    /// Convert to BackoffPolicy for internal use
    var backoffPolicy: BackoffPolicy {
        switch self {
        case .noRetry:
            return BackoffPolicy.failFast
        case .exponentialBackoff(let maxAttempts):
            return BackoffPolicy(
                maxAttempts: maxAttempts,
                baseDelay: 0.4,
                maxDelay: 5.0,
                jitter: 0.8...1.3,
                retryableStatusCodes: [429]
            )
        case .customPolicy(let policy):
            return policy
        }
    }
}

// MARK: - Backoff Policy

/// Configuration for exponential backoff with jitter
struct BackoffPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval      // Base delay in seconds
    let maxDelay: TimeInterval       // Maximum delay cap in seconds
    let jitter: ClosedRange<Double>  // Jitter range to prevent thundering herd
    let retryableStatusCodes: Set<Int> // Additional status codes to retry
    
    /// Default retry policy suitable for most scenarios
    static let `default` = BackoffPolicy(
        maxAttempts: 3,
        baseDelay: 0.4,
        maxDelay: 5.0,
        jitter: 0.8...1.3,
        retryableStatusCodes: [429] // Rate limiting
    )
    
    /// Conservative policy for critical operations
    static let conservative = BackoffPolicy(
        maxAttempts: 2,
        baseDelay: 0.2,
        maxDelay: 2.0,
        jitter: 0.9...1.1,
        retryableStatusCodes: []
    )
    
    /// Aggressive policy for non-critical operations
    static let aggressive = BackoffPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 10.0,
        jitter: 0.5...1.5,
        retryableStatusCodes: [429, 502, 503, 504]
    )
    
    /// Calculate delay for given attempt with exponential backoff and jitter
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        
        // Exponential backoff: delay = base * 2^(attempt-1)
        let exponentialDelay = baseDelay * pow(2, Double(attempt - 1))
        
        // Apply jitter to prevent thundering herd
        let jitterFactor = Double.random(in: jitter)
        let jitteredDelay = exponentialDelay * jitterFactor
        
        // Cap at maximum delay
        return min(jitteredDelay, maxDelay)
    }
    
    /// Whether the policy allows retrying this attempt number
    func canRetry(attempt: Int) -> Bool {
        return attempt <= maxAttempts
    }
}

// MARK: - Retry Context

/// Context information about the current retry attempt
struct RetryContext {
    let attempt: Int
    let totalAttempts: Int
    let previousError: Error?
    let endpoint: Endpoint
    
    var isFirstAttempt: Bool {
        return attempt == 1
    }
    
    var isLastAttempt: Bool {
        return attempt >= totalAttempts
    }
    
    var attemptsRemaining: Int {
        return max(0, totalAttempts - attempt)
    }
}

// MARK: - Retry Decision Logic

extension APIClient {
    
    /// Determine if an error should trigger a retry
    private func isRetryable(_ error: Error, context: RetryContext, policy: BackoffPolicy) -> Bool {
        // Never retry on last attempt
        guard !context.isLastAttempt else { return false }
        
        // Only retry GET requests (idempotent operations)
        guard context.endpoint.method == .GET else { return false }
        
        // Map error to check retryability
        let networkError = ErrorMapper.map(error)
        
        switch networkError {
        case .connectivity, .server:
            return true
        case .rateLimited:
            return true
        case .unknown(let status):
            // Retry unknown errors with certain status codes
            if let status = status, policy.retryableStatusCodes.contains(status) {
                return true
            }
            // Retry 5xx server errors
            return status != nil && (500...599).contains(status!)
        case .unauthorized, .forbidden, .notFound, .badRequest, .decoding, .cancelled:
            return false
        }
    }
    
    /// Execute request with retry logic
    func requestWithRetry<T: Decodable>(
        _ endpoint: Endpoint,
        policy: BackoffPolicy = .default
    ) async throws -> T {
        precondition(endpoint.method == .GET, "Only GET requests should be retried automatically.")
        
        var lastError: Error = APIServiceError.unknown(status: 0)
        
        for attempt in 1...policy.maxAttempts {
            let context = RetryContext(
                attempt: attempt,
                totalAttempts: policy.maxAttempts,
                previousError: attempt > 1 ? lastError : nil,
                endpoint: endpoint
            )
            
            do {
                #if DEBUG
                if !context.isFirstAttempt {
                    NetLog.logger.debug("🔄 Retry attempt \(attempt, privacy: .public)/\(policy.maxAttempts, privacy: .public) for \(endpoint.path, privacy: .public)")
                }
                #endif
                
                let result: T = try await request(endpoint)
                
                #if DEBUG
                if !context.isFirstAttempt {
                    NetLog.logger.debug("✅ Retry successful on attempt \(attempt, privacy: .public)")
                }
                #endif
                
                return result
                
            } catch {
                lastError = error
                
                // Check if we should retry this error
                if !isRetryable(error, context: context, policy: policy) {
                    #if DEBUG
                    NetLog.logger.debug("❌ Error not retryable: \(error.localizedDescription, privacy: .public)")
                    #endif
                    throw error
                }
                
                // Don't sleep after the last attempt
                if !context.isLastAttempt {
                    let delayTime = policy.delay(for: attempt)
                    
                    #if DEBUG
                    NetLog.logger.debug("⏳ Waiting \(String(format: "%.2f", delayTime), privacy: .public)s before retry \(attempt + 1, privacy: .public)")
                    #endif
                    
                    try await Task.sleep(nanoseconds: UInt64(delayTime * 1_000_000_000))
                }
            }
        }
        
        // All attempts failed
        #if DEBUG
        NetLog.logger.error("💥 All retry attempts failed for \(endpoint.path, privacy: .public)")
        #endif
        
        throw lastError
    }
    
    /// Execute request with retry and return Result instead of throwing
    func requestWithRetryResult<T: Decodable>(
        _ endpoint: Endpoint,
        policy: BackoffPolicy = .default
    ) async -> Result<T, NetworkError> {
        do {
            let result: T = try await requestWithRetry(endpoint, policy: policy)
            return .success(result)
        } catch {
            return .failure(ErrorMapper.map(error))
        }
    }
}

// MARK: - Retry Statistics

#if DEBUG
/// Statistics tracking for retry behavior (debug builds only)
final class RetryStatistics {
    static let shared = RetryStatistics()
    
    private var stats: [String: RetryStats] = [:]
    private let queue = DispatchQueue(label: "retry-stats", attributes: .concurrent)
    
    private init() {}
    
    func recordAttempt(endpoint: String, attempt: Int, success: Bool) {
        queue.async(flags: .barrier) {
            var endpointStats = self.stats[endpoint] ?? RetryStats()
            endpointStats.recordAttempt(attempt: attempt, success: success)
            self.stats[endpoint] = endpointStats
        }
    }
    
    func getStats() -> [String: RetryStats] {
        return queue.sync {
            return stats
        }
    }
    
    func printStats() {
        let allStats = getStats()
        
        print("📊 Retry Statistics:")
        for (endpoint, stats) in allStats {
            print("  \(endpoint):")
            print("    Total Requests: \(stats.totalRequests)")
            print("    Successful on First Try: \(stats.firstAttemptSuccesses)")
            print("    Required Retries: \(stats.totalRequests - stats.firstAttemptSuccesses)")
            print("    Success Rate: \(String(format: "%.1f", stats.successRate * 100))%")
            print("    Average Attempts: \(String(format: "%.2f", stats.averageAttempts))")
        }
    }
}

struct RetryStats {
    var totalRequests = 0
    var firstAttemptSuccesses = 0
    var totalAttempts = 0
    var failures = 0
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - failures) / Double(totalRequests)
    }
    
    var averageAttempts: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalAttempts) / Double(totalRequests)
    }
    
    mutating func recordAttempt(attempt: Int, success: Bool) {
        if attempt == 1 {
            totalRequests += 1
            if success {
                firstAttemptSuccesses += 1
            }
        }
        
        totalAttempts += 1
        
        if !success && attempt == 1 {
            // This will be a failure unless later attempts succeed
            failures += 1
        } else if success && attempt > 1 {
            // Later attempt succeeded, so remove from failures
            failures -= 1
        }
    }
}
#endif

// MARK: - Convenience Extensions

extension BackoffPolicy {
    /// Create a custom policy with specific parameters
    static func custom(
        maxAttempts: Int,
        baseDelay: TimeInterval = 0.4,
        maxDelay: TimeInterval = 5.0,
        jitter: ClosedRange<Double> = 0.8...1.3,
        retryableStatusCodes: Set<Int> = [429]
    ) -> BackoffPolicy {
        return BackoffPolicy(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            jitter: jitter,
            retryableStatusCodes: retryableStatusCodes
        )
    }
    
    /// Policy for quick operations that should fail fast
    static let failFast = BackoffPolicy(
        maxAttempts: 1,
        baseDelay: 0,
        maxDelay: 0,
        jitter: 1.0...1.0,
        retryableStatusCodes: []
    )
}

// MARK: - Task Cancellation Support

extension APIClient {
    /// Execute request with retry and cancellation support
    func requestWithRetryAndCancellation<T: Decodable>(
        _ endpoint: Endpoint,
        policy: BackoffPolicy = .default
    ) async throws -> T {
        return try await withTaskCancellationHandler(
            operation: {
                return try await requestWithRetry(endpoint, policy: policy)
            },
            onCancel: {
                #if DEBUG
                NetLog.logger.debug("🚫 Request cancelled: \(endpoint.path, privacy: .public)")
                #endif
            }
        )
    }
}