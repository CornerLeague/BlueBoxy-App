//
//  Environment.swift
//  BlueBoxy
//
//  Secure environment configuration - keeps sensitive keys out of Info.plist
//

import Foundation
import Security

struct AppConfig {
    
    // MARK: - Secure Configuration
    
    /// Base URL for API calls
    static let baseURL: String = {
        #if DEBUG
        return "http://localhost:5000"
        #else
        return "https://your-production-api.com"
        #endif
    }()
    
    /// OpenAI API Configuration
    static let openAIConfig = OpenAIConfig()
    
    /// XAI API Configuration  
    static let xaiConfig = XAIConfig()
    
    /// Database Configuration (for server-side only)
    static let databaseConfig = DatabaseConfig()
    
    // MARK: - Configuration Structs
    
    struct OpenAIConfig {
        /// Get OpenAI API key from secure storage or environment
        var apiKey: String {
            // Try keychain first (recommended)
            if let keychainKey = KeychainHelper.shared.get(service: "BlueBoxy", account: "openai_api_key") {
                return keychainKey
            }
            
            // Try environment variable
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            
            // Fallback for development - API key is stored in keychain
            #if DEBUG
            // OpenAI API key saved in keychain for security
            // If needed, update via: security add-generic-password -s BlueBoxy -a openai_api_key -w "your-key"
            fatalError("OpenAI API key not configured. Please set OPENAI_API_KEY environment variable or save to keychain.")
            #else
            fatalError("OpenAI API key not configured. Please set OPENAI_API_KEY environment variable or save to keychain.")
            #endif
        }
        
        let baseURL = "https://api.openai.com/v1"
        // Using gpt-4 for better activity recommendations, or use gpt-3.5-turbo for cost savings
        let model = "gpt-4"
    }
    
    struct XAIConfig {
        /// Get XAI API key from secure storage or environment
        var apiKey: String {
            if let envKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
                return envKey
            }
            
            if let keychainKey = KeychainHelper.shared.get(service: "BlueBoxy", account: "xai_api_key") {
                return keychainKey
            }
            
            #if DEBUG
            fatalError("XAI API key not configured. Please set in environment or keychain.")
            #else
            fatalError("XAI API key not configured. Please set in environment or keychain.")
            #endif
        }
        
        let baseURL = "https://api.x.ai/v1"
    }
    
    struct DatabaseConfig {
        // Note: Database credentials should NEVER be in mobile apps!
        // This is for reference only - your mobile app should call your backend API
        
        /// Database connection (server-side only)
        static let connectionString: String = {
            if let envDB = ProcessInfo.processInfo.environment["DATABASE_URL"] {
                return envDB
            }
            return "postgresql://localhost/blueboxy_dev"
        }()
        
        static let host = ProcessInfo.processInfo.environment["PGHOST"] ?? "localhost"
        static let database = ProcessInfo.processInfo.environment["PGDATABASE"] ?? "blueboxy_dev"
        static let user = ProcessInfo.processInfo.environment["PGUSER"] ?? "postgres"
        
        // Never store password in mobile app - use environment variables on server
        static let password = ProcessInfo.processInfo.environment["PGPASSWORD"] ?? ""
    }
    
    // MARK: - App Configuration
    
    /// Session configuration
    static let sessionConfig = SessionConfig()
    
    struct SessionConfig {
        let secret: String = {
            if let envSecret = ProcessInfo.processInfo.environment["SESSION_SECRET"] {
                return envSecret
            }
            
            if let keychainSecret = KeychainHelper.shared.get(service: "BlueBoxy", account: "session_secret") {
                return keychainSecret
            }
            
            // Generate a random secret for development
            #if DEBUG
            return "dev-session-secret-\(UUID().uuidString)"
            #else
            fatalError("Session secret not configured. Please set in environment or keychain.")
            #endif
        }()
    }
    
    // MARK: - Helper Methods
    
    /// Check if all required configuration is available
    static func validateConfiguration() -> Bool {
        do {
            // Test that we can get required keys
            _ = openAIConfig.apiKey
            _ = xaiConfig.apiKey
            _ = sessionConfig.secret
            return true
        } catch {
            print("❌ Configuration validation failed: \(error)")
            return false
        }
    }
    
    /// Print configuration status (without exposing sensitive data)
    static func printConfigurationStatus() {
        print("🔧 Environment Configuration:")
        print("   Base URL: \(baseURL)")
        print("   OpenAI configured: \(!openAIConfig.apiKey.isEmpty)")
        print("   XAI configured: \(!xaiConfig.apiKey.isEmpty)")
        print("   Session configured: \(!sessionConfig.secret.isEmpty)")
        
        #if DEBUG
        print("   Mode: Development")
        #else
        print("   Mode: Production")
        #endif
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func save(service: String, account: String, data: String) -> Bool {
        let data = data.data(using: .utf8)!
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ] as CFDictionary
        
        SecItemDelete(query)
        return SecItemAdd(query, nil) == errSecSuccess
    }
    
    func get(service: String, account: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    func delete(service: String, account: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        
        return SecItemDelete(query) == errSecSuccess
    }
}