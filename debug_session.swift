#!/usr/bin/env swift

import Foundation

print("🧪 Testing Session Authentication State")
print("=" + String(repeating: "=", count: 50))

// Simulate checking session state
struct MockSessionStore {
    var userId: Int? = 123
    var authToken: String? = "mock-jwt-token-12345"
    var currentUser: MockUser? = MockUser(id: 123, email: "test@example.com", name: "Test User")
    
    func isSessionValid() -> Bool {
        guard userId != nil, 
              let token = authToken, !token.isEmpty else {
            return false
        }
        return true
    }
    
    func summary() -> String {
        return """
        Session State:
        - User ID: \(userId?.description ?? "nil")
        - Auth Token: \(authToken?.isEmpty == false ? "Present (length: \(authToken?.count ?? 0))" : "Missing")
        - Current User: \(currentUser?.name ?? "nil")
        - Is Valid: \(isSessionValid())
        """
    }
}

struct MockUser {
    let id: Int
    let email: String
    let name: String
}

func testSessionScenarios() {
    print("📋 Testing Different Session Scenarios:")
    print()
    
    // Scenario 1: Valid session
    print("1️⃣ Valid Session:")
    let validSession = MockSessionStore()
    print(validSession.summary())
    print("✅ API calls should work: \(validSession.isSessionValid())")
    print()
    
    // Scenario 2: Missing token
    print("2️⃣ Missing Auth Token:")
    var invalidSession = MockSessionStore()
    invalidSession.authToken = nil
    print(invalidSession.summary())
    print("❌ API calls should fail with missingAuth: \(invalidSession.isSessionValid())")
    print()
    
    // Scenario 3: Empty token
    print("3️⃣ Empty Auth Token:")
    var emptyTokenSession = MockSessionStore()
    emptyTokenSession.authToken = ""
    print(emptyTokenSession.summary())
    print("❌ API calls should fail with missingAuth: \(emptyTokenSession.isSessionValid())")
    print()
    
    // Scenario 4: Missing user ID
    print("4️⃣ Missing User ID:")
    var noUserSession = MockSessionStore()
    noUserSession.userId = nil
    print(noUserSession.summary())
    print("❌ API calls should fail with missingAuth: \(noUserSession.isSessionValid())")
    print()
    
    print("🎯 Expected Behavior for Onboarding:")
    print("- User must be registered/logged in BEFORE completing onboarding")
    print("- Session should have valid userId and authToken")
    print("- OnboardingService should only be called after authentication is established")
    print()
    
    print("💡 Potential Fix:")
    print("- Move onboarding data submission to AFTER user registration completes")
    print("- Or create registration endpoint that also saves onboarding data")
    print("- Ensure SessionStore is properly populated after registration/login")
}

testSessionScenarios()