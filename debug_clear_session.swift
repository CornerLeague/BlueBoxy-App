#!/usr/bin/env swift

import Foundation
import Security

// Clear UserDefaults session data
let defaults = UserDefaults.standard

// Remove all BlueBoxy session related keys
let keysToRemove = [
    "blueboxy.userId",
    "blueboxy.userData", 
    "blueboxy.sessionExpiry",
    "hasCompletedOnboarding",
    "pendingDeepLinkRoute",
    "bookmarked_activities"
]

print("🧹 Clearing UserDefaults session data...")
for key in keysToRemove {
    defaults.removeObject(forKey: key)
    print("  ✅ Removed: \(key)")
}

// Clear Keychain items
let keychainService = "com.blueboxy.app"
let keychainKeys = [
    "blueboxy.userId",
    "blueboxy.authToken", 
    "blueboxy.refreshToken"
]

print("\n🔐 Clearing Keychain session data...")
for key in keychainKeys {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: key
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess {
        print("  ✅ Removed from Keychain: \(key)")
    } else if status == errSecItemNotFound {
        print("  ℹ️ Not found in Keychain: \(key)")
    } else {
        print("  ❌ Failed to remove from Keychain: \(key) (status: \(status))")
    }
}

print("\n✨ Session data cleared! Restart your app to test fresh authentication.")