//
//  APIConfiguration.swift
//  BlueBoxy
//
//  Centralized API configuration with base URL from Info.plist,
//  timeouts, headers, and JSON encoding/decoding setup
//

import Foundation

enum APIConfiguration {
    
    /// Base URL built from components to avoid xcconfig URL parsing issues
    static var baseURL: URL {
        // Strategy 1: Build from Info.plist components
        let scheme = Bundle.main.object(forInfoDictionaryKey: "API_SCHEME") as? String
        let host = Bundle.main.object(forInfoDictionaryKey: "API_HOST") as? String
        let portString = Bundle.main.object(forInfoDictionaryKey: "API_PORT") as? String
        let hostFallback = Bundle.main.object(forInfoDictionaryKey: "API_HOST_FALLBACK") as? String
        
        print("🔧 [APIConfiguration] API_SCHEME: '\(scheme ?? "nil")'")
        print("🔧 [APIConfiguration] API_HOST: '\(host ?? "nil")'")
        print("🔧 [APIConfiguration] API_PORT: '\(portString ?? "nil")'")
        print("🔧 [APIConfiguration] API_HOST_FALLBACK: '\(hostFallback ?? "nil")'")
        
        // Strategy 2: Environment variable fallback
        let envURL = ProcessInfo.processInfo.environment["BASE_URL"]
        
        let finalURL: URL
        
        // Try building from components first
        if let scheme = scheme, !scheme.isEmpty, scheme != "$(API_SCHEME)",
           let host = host, !host.isEmpty, host != "$(API_HOST)",
           let portString = portString, !portString.isEmpty, portString != "$(API_PORT)",
           let port = Int(portString) {
            
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.port = port
            
            if let url = components.url {
                finalURL = url
                print("✅ [APIConfiguration] Built URL from components: \(finalURL)")
            } else {
                finalURL = fallbackURL(hostFallback: hostFallback)
            }
            
        } else if let env = envURL, !env.isEmpty, let url = URL(string: env) {
            // Environment variable fallback
            finalURL = url
            print("✅ [APIConfiguration] Using environment BASE_URL: \(finalURL)")
            
        } else {
            // Development fallbacks
            finalURL = fallbackURL(hostFallback: hostFallback)
        }
        
        return finalURL
    }
    
    /// Generate fallback URL based on target environment
    private static func fallbackURL(hostFallback: String?) -> URL {
        let fallbackURLString: String
        
        #if DEBUG
        #if targetEnvironment(simulator)
        fallbackURLString = "http://127.0.0.1:3001"
        print("⚠️ [APIConfiguration] Using simulator fallback: \(fallbackURLString)")
        #else
        // Physical device - try fallback host or default IP
        if let fallback = hostFallback, !fallback.isEmpty, fallback != "$(API_HOST_FALLBACK)" {
            fallbackURLString = "http://\(fallback):3001"
        } else {
            fallbackURLString = "http://192.168.1.41:3001"
        }
        print("⚠️ [APIConfiguration] Using device fallback: \(fallbackURLString)")
        #endif
        #else
        fatalError("API configuration missing in production build. Check your xcconfig settings.")
        #endif
        
        guard let url = URL(string: fallbackURLString) else {
            fatalError("Fallback URL has invalid format: \(fallbackURLString)")
        }
        
        return url
    }
    /// Default headers sent with every request
    static var defaultHeaders: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "BlueBoxy iOS/\(appVersion)"
        ]
    }
    
    /// Enhanced URLSession with networking best practices and debugging capabilities
    static var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // Enhanced timeout settings based on SwiftNIO research
        configuration.timeoutIntervalForRequest = 30 // Increased for development servers
        configuration.timeoutIntervalForResource = 90 // Extended for complex requests
        
        // Robust connectivity settings
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Development-friendly cache policy
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024)
        
        // Enhanced HTTP settings
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpShouldUsePipelining = false // Safer for debugging
        configuration.httpCookieAcceptPolicy = .always
        
        // Development debugging enhancements
        #if DEBUG
        configuration.networkServiceType = .default
        // Add debug protocols if available (from Pulse research)
        if let debugProtocolClass = NSClassFromString("MockingURLProtocol") as? URLProtocol.Type {
            configuration.protocolClasses = [debugProtocolClass] + (configuration.protocolClasses ?? [])
        }
        #endif
        
        return URLSession(configuration: configuration)
    }()
    
    /// JSON decoder configured for BlueBoxy API responses
    static var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        // Handle flexible JSON values with custom decoding if needed
        return decoder
    }()
    
    /// JSON encoder configured for BlueBoxy API requests
    static var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .useDefaultKeys
        
        // Pretty printing in debug builds
        #if DEBUG
        encoder.outputFormatting = .prettyPrinted
        #endif
        
        return encoder
    }()
    
    // MARK: - Private Helpers
    
    /// App version string for User-Agent header
    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Development & Debug Support

#if DEBUG
extension APIConfiguration {
    /// Override base URL for testing (use with caution)
    static func setTestBaseURL(_ url: URL) {
        // This could be implemented with a static var if needed for testing
        // For now, we rely on Info.plist configuration
    }
    
    /// Validate configuration at app startup
    static func validateConfiguration() {
        print("[API] Base URL: \(baseURL)")
        print("[API] App Version: \(appVersion)")
        print("[API] Request Timeout: \(session.configuration.timeoutIntervalForRequest)s")
        print("[API] Resource Timeout: \(session.configuration.timeoutIntervalForResource)s")
    }
}
#endif

