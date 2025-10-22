#!/usr/bin/env swift
//
//  SetupAPIKey.swift
//  Helper to save OpenAI API key to Keychain
//
//  Run: swift SetupAPIKey.swift
//

import Foundation
import Security

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
}

// Usage
if CommandLine.arguments.count > 1 {
    let apiKey = CommandLine.arguments[1]
    if KeychainHelper.shared.save(service: "BlueBoxy", account: "openai_api_key", data: apiKey) {
        print("✅ API key saved to keychain successfully")
    } else {
        print("❌ Failed to save API key to keychain")
    }
} else {
    print("Usage: swift SetupAPIKey.swift <your-openai-api-key>")
    print("Example: swift SetupAPIKey.swift sk-proj-xxxxxxxxxxxx")
}
