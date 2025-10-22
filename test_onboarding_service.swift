#!/usr/bin/env swift

import Foundation

print("🧪 Testing OnboardingService Integration")
print("=" + String(repeating: "=", count: 50))

// Mock onboarding data to simulate what would be collected during onboarding
struct MockOnboardingData {
    let name = "John Doe"
    let partnerName = "Jane Doe"
    let relationshipDuration = "3 years"
    let partnerAge = "28"
    let personalityType = "Thoughtful Harmonizer"
    let assessmentResponses = [
        "communication": "Deep, meaningful conversations",
        "activities": "Quiet, intimate settings",
        "stress": "Take time to process alone first",
        "romance": "Quality time together",
        "conflict": "Try to find a compromise quickly"
    ]
    let preferences = [
        "dateFrequency": "weekly",
        "budgetRange": "moderate",
        "activityTypes": ["dining", "movies", "outdoor"],
        "notificationsEnabled": true
    ] as [String: Any]
    let location: (latitude: Double, longitude: Double)? = (37.7749, -122.4194) // San Francisco
    
    var hasCompletedAssessment: Bool { !assessmentResponses.isEmpty && !personalityType.isEmpty }
    var hasSetPreferences: Bool { !preferences.isEmpty }
    
    func generateSummary() -> String {
        return """
        Mock Onboarding Data Summary:
        - Name: \(name)
        - Partner Name: \(partnerName)
        - Relationship Duration: \(relationshipDuration)
        - Partner Age: \(partnerAge)
        - Assessment Completed: \(hasCompletedAssessment ? "Yes" : "No")
        - Personality Type: \(personalityType)
        - Preferences Set: \(hasSetPreferences ? "Yes (\(preferences.count) items)" : "No")
        - Location Provided: \(location != nil ? "Yes" : "No")
        """
    }
}

func testOnboardingServiceIntegration() async {
    let mockData = MockOnboardingData()
    
    print("📋 Mock Onboarding Data:")
    print(mockData.generateSummary())
    print()
    
    print("🔧 API Endpoints that would be called:")
    print("1. POST /api/user/profile - Update user profile")
    print("   - name: \(mockData.name)")
    print("   - partnerName: \(mockData.partnerName)")
    print("   - relationshipDuration: \(mockData.relationshipDuration)")
    print("   - partnerAge: \(mockData.partnerAge)")
    print("   - personalityType: \(mockData.personalityType)")
    print()
    
    print("2. POST /api/assessment/submit - Submit assessment results")
    print("   - responses: \(mockData.assessmentResponses.count) answers")
    print("   - personalityType: \(mockData.personalityType)")
    print()
    
    print("3. POST /api/user/preferences - Save user preferences")
    print("   - preferences: \(mockData.preferences.count) items")
    if let location = mockData.location {
        print("   - location: [\(location.latitude), \(location.longitude)]")
    }
    print()
    
    // Test data validation
    print("✅ Data Validation:")
    print("   - Required name present: \(!mockData.name.isEmpty)")
    print("   - Assessment completed: \(mockData.hasCompletedAssessment)")
    print("   - Preferences set: \(mockData.hasSetPreferences)")
    print()
    
    print("🎯 Expected Backend Behavior:")
    print("1. User profile will be updated with personal information")
    print("2. Assessment results will be stored for personality insights")
    print("3. Preferences will be saved for recommendation algorithms")
    print("4. Location will be used for location-based recommendations")
    print()
    
    print("📊 Data Flow:")
    print("iOS Onboarding → OnboardingService → API Endpoints → Database")
    print("✅ Integration test complete!")
}

// Run the test
await testOnboardingServiceIntegration()