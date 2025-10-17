#!/usr/bin/env swift

import Foundation

// Verification script to check registration flow consistency
print("🔍 Registration Flow Consistency Check")
print("=====================================")

// Function to check if code contains required onboarding setup
func checkRegistrationMethod(filePath: String, methodName: String) {
    print("\n📋 Checking \(methodName) in \(filePath)")
    
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        print("❌ Could not read file: \(filePath)")
        return
    }
    
    // Check for onboarding flag clearing
    let hasOnboardingClear = content.contains("UserDefaults.standard.removeObject(forKey: \"hasCompletedOnboarding\")")
    
    // Check for userDidRegister notification
    let hasNotification = content.contains("NotificationCenter.default.post(name: .userDidRegister")
    
    // Check for DispatchQueue.main.async (proper notification posting)
    let hasMainQueue = content.contains("DispatchQueue.main.async")
    
    print("  ✅ Clears onboarding flag: \(hasOnboardingClear ? "YES" : "NO")")
    print("  ✅ Emits .userDidRegister: \(hasNotification ? "YES" : "NO")")
    print("  ✅ Uses main queue: \(hasMainQueue ? "YES" : "NO")")
    
    let isConsistent = hasOnboardingClear && hasNotification && hasMainQueue
    print("  🎯 Registration consistency: \(isConsistent ? "✅ CONSISTENT" : "❌ INCONSISTENT")")
    
    if !isConsistent {
        print("  💡 This registration path may not properly trigger onboarding flow")
    }
}

// Function to check if RootView listens for notifications
func checkRootViewListening(filePath: String) {
    print("\n📋 Checking RootView notification handling")
    
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        print("❌ Could not read file: \(filePath)")
        return
    }
    
    let hasUserDidRegisterListener = content.contains(".userDidRegister")
    let hasRefreshOnboarding = content.contains("refreshOnboardingState")
    let hasNavigateToOnboarding = content.contains("navigateToOnboardingAfterRegistration")
    
    print("  ✅ Listens for .userDidRegister: \(hasUserDidRegisterListener ? "YES" : "NO")")
    print("  ✅ Refreshes onboarding state: \(hasRefreshOnboarding ? "YES" : "NO")")
    print("  ✅ Navigates to onboarding: \(hasNavigateToOnboarding ? "YES" : "NO")")
    
    let isProperlyConfigured = hasUserDidRegisterListener && hasRefreshOnboarding && hasNavigateToOnboarding
    print("  🎯 RootView configuration: \(isProperlyConfigured ? "✅ PROPER" : "❌ INCOMPLETE")")
}

// Define file paths
let basePath = "/Users/newmac/Desktop/BlueBoxy/BlueBoxy"
let files = [
    ("\(basePath)/ViewModels/AuthViewModel.swift", "AuthViewModel.register"),
    ("\(basePath)/Core/Services/AuthService.swift", "AuthService.signUp"),
    ("\(basePath)/Core/ViewModels/SessionViewModel.swift", "SessionViewModel.register")
]

// Check each registration method
for (filePath, methodName) in files {
    checkRegistrationMethod(filePath: filePath, methodName: methodName)
}

// Check RootView
checkRootViewListening(filePath: "\(basePath)/Views/RootView.swift")

print("\n" + String(repeating: "=", count: 50))
print("✨ Registration Flow Analysis Complete!")
print("\n🎯 Expected behavior for ALL registration paths:")
print("   1. Clear hasCompletedOnboarding flag")
print("   2. Emit .userDidRegister notification on main queue")
print("   3. RootView catches notification and navigates to onboarding")
print("\n💡 If any path is INCONSISTENT:")
print("   • New users via that path won't be directed to onboarding")
print("   • They may be stuck in an authenticated but incomplete state")
print("   • The registration won't feel complete to the user")
print("\n🔧 Fix inconsistent paths by adding:")
print("   UserDefaults.standard.removeObject(forKey: \"hasCompletedOnboarding\")")
print("   DispatchQueue.main.async {")
print("       NotificationCenter.default.post(name: .userDidRegister, object: user)")
print("   }")