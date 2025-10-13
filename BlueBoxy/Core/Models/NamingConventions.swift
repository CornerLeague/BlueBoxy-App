//
//  NamingConventions.swift
//  BlueBoxy
//
//  Documentation of naming conventions and normalization patterns
//  This file serves as a reference for API field naming and any required mapping
//

import Foundation

/*
 NAMING CONVENTIONS FROM BACKEND API
 
 This documentation outlines the naming patterns used by the backend API
 and any mapping requirements for the iOS models.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Primary Naming Convention: camelCase
 
 The backend API already uses camelCase for all JSON response fields.
 This means NO CodingKeys mapping is needed for most models.
 
 Examples from API responses:
 - partnerName (not partner_name)
 - relationshipDuration (not relationship_duration)
 - personalityType (not personality_type)
 - personalityInsight (not personality_insight)
 - loveLanguage (not love_language)
 - communicationStyle (not communication_style)
 - idealActivities (not ideal_activities)
 - stressResponse (not stress_response)
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Calendar Event Naming Differences (Intentional)
 
 There are intentional naming differences between external provider events
 and the app's own database events to reflect their different sources:
 
 ### External Calendar Events (Google/Outlook API responses):
 ```json
 {
   "start": "2025-01-01T10:00:00Z",
   "end": "2025-01-01T11:00:00Z"
 }
 ```
 
 ### Database Calendar Events (App's own storage):
 ```json
 {
   "startTime": "2025-01-01T19:00:00Z",
   "endTime": "2025-01-01T21:00:00Z"
 }
 ```
 
 This difference is intentional and reflects the actual API structure.
 No CodingKeys mapping is applied - we model the APIs as they actually are.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Models That Use Default Naming (No CodingKeys Needed)
 
 The following models require NO CodingKeys because the API already uses camelCase:
 
 ### User & Auth:
 - User: All fields are camelCase
 - PersonalityInsight: All fields are camelCase  
 - AuthEnvelope: Uses camelCase
 
 ### Assessment:
 - AssessmentSavedResponse: completedAt is camelCase
 - GuestAssessmentResponse: onboardingData is camelCase
 
 ### Preferences:
 - PreferencesSaveResponse: All fields camelCase
 - PreferencesUpdateResponse: All fields camelCase
 
 ### Activities & Recommendations:
 - Activity: imageUrl, personalityMatch are camelCase
 - SimpleRecommendation: All fields camelCase
 - LocationBasedActivityGET: personalityMatch is camelCase
 - GrokActivityRecommendation: estimatedCost, recommendedTime, personalityMatch are camelCase
 - AIPoweredActivity: personalityMatch, imageUrl are camelCase
 
 ### Messages:
 - MessageItem: personalityMatch, estimatedImpact are camelCase
 - MessageGenerationResponse: All fields camelCase
 - MessageCategory: All fields camelCase
 
 ### Calendar:
 - CalendarProvider: displayName, isConnected, authUrl, lastSync, errorMessage are camelCase
 - ExternalCalendarEvent: providerId, externalId are camelCase
 - CalendarEventDB: userId, startTime, endTime, allDay, eventType, externalEventId, calendarProvider, createdAt, updatedAt are camelCase
 
 ### Stats:
 - UserStatsResponse: eventsCreated, userId, createdAt, updatedAt are camelCase
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## When CodingKeys Would Be Needed (Future Reference)
 
 If the backend ever changes to snake_case, you would add CodingKeys like this:
 
 ```swift
 struct User: Decodable {
     let id: Int
     let email: String
     let name: String
     let partnerName: String?
     let relationshipDuration: String?
     // ... other fields
     
     enum CodingKeys: String, CodingKey {
         case id, email, name
         case partnerName = "partner_name"
         case relationshipDuration = "relationship_duration"
         // ... other mappings
     }
 }
 ```
 
 But this is NOT needed currently since the API uses camelCase.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Special Cases and Considerations
 
 ### 1. Boolean Field Naming:
 - isConnected: Correctly uses "is" prefix
 - allDay: Uses adjective form (not "isAllDay")
 - success: Simple boolean without prefix
 
 ### 2. Time/Date Field Variations:
 - start, end: Used by external calendar providers
 - startTime, endTime: Used by app's database
 - createdAt, updatedAt: Timestamp fields with "At" suffix
 - completedAt: Assessment completion timestamp
 - lastSync: Calendar provider sync timestamp
 
 ### 3. ID Field Variations:
 - id: Primary key (Int for DB, String for external)
 - userId: Foreign key reference to user
 - externalId: ID from external system
 - externalEventId: External calendar event reference
 - providerId: Calendar provider identifier
 
 ### 4. Nested Object Naming:
 - personalityInsight: Nested object with camelCase fields
 - preferences: JSON blob with arbitrary keys
 - location: JSON blob with arbitrary keys  
 - metadata: JSON blob with arbitrary keys
 - reminders: JSON blob with arbitrary structure
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Validation and Consistency Checks
 
 ### Field Name Patterns:
 - Duration fields: "Duration" suffix (relationshipDuration)
 - Type fields: "Type" suffix (personalityType, eventType)
 - Match fields: "Match" suffix (personalityMatch)
 - Impact fields: "Impact" suffix (estimatedImpact)
 - URL fields: "Url" suffix (imageUrl, authUrl)
 - Name fields: "Name" suffix (partnerName, displayName)
 - Age fields: "Age" suffix (partnerAge)
 - Cost fields: "Cost" suffix (estimatedCost)
 - Time fields: "Time" suffix (startTime, endTime, recommendedTime)
 
 ### Acronym Handling:
 - URL: Capitalized as "Url" (imageUrl, authUrl)
 - ID: Capitalized as "Id" (userId, providerId, externalId)
 - API: Would be "Api" if used in field names
 - AI: Would be "Ai" if used in field names
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Cross-Platform Consistency
 
 The camelCase naming ensures consistency across platforms:
 - iOS Swift models: Natural camelCase property names
 - JavaScript/React frontend: Natural camelCase object properties  
 - Backend API: Consistent camelCase JSON responses
 - Database: May use snake_case internally but API layer converts
 
 This eliminates the need for field name mapping in most client implementations.
 
 ═══════════════════════════════════════════════════════════════════════════════
 */

// MARK: - Naming Convention Utilities

#if DEBUG
struct NamingConventions {
    
    /// Validates that a field name follows camelCase convention
    static func validateCamelCase(_ fieldName: String) -> Bool {
        // Check if first character is lowercase
        guard let firstChar = fieldName.first, firstChar.isLowercase else {
            return false
        }
        
        // Check if contains no underscores (snake_case)
        guard !fieldName.contains("_") else {
            return false
        }
        
        // Check if contains no spaces
        guard !fieldName.contains(" ") else {
            return false
        }
        
        return true
    }
    
    /// Validates common field name patterns for consistency
    static func validateFieldNamePattern(_ fieldName: String, expectedSuffix: String? = nil) -> Bool {
        if let suffix = expectedSuffix {
            return fieldName.hasSuffix(suffix)
        }
        
        // Validate common patterns
        let commonPatterns = [
            "Duration", "Type", "Match", "Impact", "Url", "Name", 
            "Age", "Cost", "Time", "Id", "At", "Language", "Style"
        ]
        
        // At least one common pattern should match for structured field names
        return commonPatterns.contains { pattern in
            fieldName.hasSuffix(pattern) || fieldName.contains(pattern)
        } || fieldName.count < 8 // Allow short simple names
    }
    
    /// Generates CodingKeys mapping from camelCase to snake_case (for reference)
    static func generateSnakeCaseMapping(_ camelCaseFields: [String]) -> [String: String] {
        var mapping: [String: String] = [:]
        
        for field in camelCaseFields {
            let snakeCase = camelCaseToSnakeCase(field)
            if snakeCase != field {
                mapping[field] = snakeCase
            }
        }
        
        return mapping
    }
    
    /// Converts camelCase to snake_case (utility function)
    private static func camelCaseToSnakeCase(_ camelCase: String) -> String {
        var result = ""
        
        for (index, character) in camelCase.enumerated() {
            if character.isUppercase && index > 0 {
                result += "_"
            }
            result += character.lowercased()
        }
        
        return result
    }
    
    /// Validates that a model's field names follow conventions
    static func validateModelNaming<T>(_ modelType: T.Type) -> [String] where T: Decodable {
        var issues: [String] = []
        
        // This would require reflection to fully implement
        // For now, we'll provide a manual validation approach
        let modelName = String(describing: modelType)
        
        // Common validation checks
        if !validateCamelCase(modelName) {
            issues.append("Model name '\(modelName)' should follow PascalCase convention")
        }
        
        return issues
    }
}

// MARK: - Field Name Constants

/// Constants for commonly used field names to ensure consistency
enum FieldNames {
    // User fields
    static let partnerName = "partnerName"
    static let relationshipDuration = "relationshipDuration"
    static let partnerAge = "partnerAge"
    static let personalityType = "personalityType"
    static let personalityInsight = "personalityInsight"
    
    // PersonalityInsight fields
    static let loveLanguage = "loveLanguage"
    static let communicationStyle = "communicationStyle"
    static let idealActivities = "idealActivities"
    static let stressResponse = "stressResponse"
    
    // Activity fields
    static let imageUrl = "imageUrl"
    static let personalityMatch = "personalityMatch"
    
    // Calendar fields
    static let startTime = "startTime"
    static let endTime = "endTime"
    static let allDay = "allDay"
    static let eventType = "eventType"
    static let externalEventId = "externalEventId"
    static let calendarProvider = "calendarProvider"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
    
    // Provider fields
    static let displayName = "displayName"
    static let isConnected = "isConnected"
    static let authUrl = "authUrl"
    static let lastSync = "lastSync"
    static let errorMessage = "errorMessage"
    static let providerId = "providerId"
    static let externalId = "externalId"
    
    // Recommendation fields
    static let estimatedCost = "estimatedCost"
    static let recommendedTime = "recommendedTime"
    static let estimatedImpact = "estimatedImpact"
    
    // Response fields
    static let eventsCreated = "eventsCreated"
    static let userId = "userId"
    static let completedAt = "completedAt"
    static let onboardingData = "onboardingData"
}
#endif