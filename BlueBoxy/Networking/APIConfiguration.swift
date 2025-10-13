//
//  APIConfiguration.swift
//  BlueBoxy
//
//  Centralized API configuration with base URL from Info.plist,
//  timeouts, headers, and JSON encoding/decoding setup
//

import Foundation

enum APIConfiguration {
    
    /// Base URL loaded from Info.plist BASE_URL key (backed by xcconfig settings)
    static var baseURL: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            fatalError("BASE_URL missing or invalid in Info.plist. Check your xcconfig settings.")
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
    
    /// Configured URLSession with appropriate timeouts and connectivity settings
    static var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // Timeout settings
        configuration.timeoutIntervalForRequest = 20 // seconds
        configuration.timeoutIntervalForResource = 60 // seconds
        
        // Network behavior
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Cache policy
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
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

