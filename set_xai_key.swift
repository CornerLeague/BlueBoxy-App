#!/usr/bin/env swift

import Foundation
import Security

// Store XAI API key in keychain for BlueBoxy app
// Replace with your actual API key or get from environment
let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "YOUR_XAI_API_KEY_HERE"
let service = "BlueBoxy"
let account = "xai_api_key"

func saveToKeychain(service: String, account: String, data: String) -> Bool {
    let data = data.data(using: .utf8)!
    
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecValueData: data
    ] as CFDictionary
    
    // Delete any existing item first
    SecItemDelete(query)
    
    // Add the new item
    let status = SecItemAdd(query, nil)
    return status == errSecSuccess
}

print("🔑 Storing XAI API key in keychain...")
print("   Service: \(service)")
print("   Account: \(account)")
print("   Key length: \(apiKey.count) characters")

let success = saveToKeychain(service: service, account: account, data: apiKey)

if success {
    print("✅ API key successfully stored in keychain!")
    print("   The app will now use this key instead of environment variables.")
    print("   Rebuild and restart the app to use the new key.")
} else {
    print("❌ Failed to store API key in keychain.")
    print("   You may need to run this with proper permissions.")
}

print("\n🎯 Next steps:")
print("1. Rebuild the app: xcodebuild -project BlueBoxy.xcodeproj -scheme BlueBoxy build")
print("2. Reinstall and launch the app in simulator")
print("3. Test the Generate Activities button")