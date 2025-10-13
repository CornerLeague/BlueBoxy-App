//
//  NamingConventionTests.swift
//  BlueBoxyTests
//
//  Tests to verify naming convention compliance across all models
//

import Testing
import Foundation
@testable import BlueBoxy

struct NamingConventionTests {
    
    // MARK: - camelCase Validation Tests
    
    @Test func testCamelCaseValidation() async throws {
        #if DEBUG
        // Valid camelCase examples
        let validCamelCase = [
            "id", "email", "name", "partnerName", "relationshipDuration", 
            "personalityType", "loveLanguage", "communicationStyle",
            "idealActivities", "stressResponse", "imageUrl", "personalityMatch",
            "startTime", "endTime", "allDay", "eventType", "createdAt", "updatedAt"
        ]
        
        for fieldName in validCamelCase {
            let isValid = NamingConventions.validateCamelCase(fieldName)
            #expect(isValid, "\(fieldName) should be valid camelCase")
        }
        
        // Invalid examples (snake_case, spaces, PascalCase)
        let invalidCamelCase = [
            "partner_name", "relationship_duration", "personality_type",
            "love_language", "communication_style", "ideal_activities",
            "stress_response", "image_url", "personality_match",
            "start_time", "end_time", "all_day", "event_type",
            "created_at", "updated_at", "Partner Name", "PartnerName"
        ]
        
        for fieldName in invalidCamelCase {
            let isValid = NamingConventions.validateCamelCase(fieldName)
            #expect(!isValid, "\(fieldName) should be invalid camelCase")
        }
        #endif
    }
    
    @Test func testFieldNamePatternValidation() async throws {
        #if DEBUG
        // Test fields with expected suffixes
        let suffixTests = [
            ("relationshipDuration", "Duration"),
            ("personalityType", "Type"),
            ("personalityMatch", "Match"),
            ("estimatedImpact", "Impact"),
            ("imageUrl", "Url"),
            ("partnerName", "Name"),
            ("partnerAge", "Age"),
            ("estimatedCost", "Cost"),
            ("startTime", "Time"),
            ("createdAt", "At")
        ]
        
        for (fieldName, expectedSuffix) in suffixTests {
            let isValid = NamingConventions.validateFieldNamePattern(fieldName, expectedSuffix: expectedSuffix)
            #expect(isValid, "\(fieldName) should end with \(expectedSuffix)")
        }
        #endif
    }
    
    // MARK: - Model Field Naming Tests
    
    @Test func testUserModelFieldNaming() async throws {
        // Test that User model can decode with camelCase field names
        let userJSON = """
        {
            "id": 1,
            "email": "test@example.com",
            "name": "Test User",
            "partnerName": "Partner",
            "relationshipDuration": "6 months",
            "partnerAge": 25,
            "personalityType": "Thoughtful Harmonizer",
            "personalityInsight": {
                "description": "Test description",
                "loveLanguage": "Quality Time",
                "communicationStyle": "Direct",
                "idealActivities": ["Reading"],
                "stressResponse": "Calm"
            }
        }
        """
        
        let data = userJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)
        
        // Verify all camelCase fields decoded correctly
        #expect(user.id == 1)
        #expect(user.email == "test@example.com")
        #expect(user.name == "Test User")
        #expect(user.partnerName == "Partner")
        #expect(user.relationshipDuration == "6 months")
        #expect(user.partnerAge == 25)
        #expect(user.personalityType == "Thoughtful Harmonizer")
        
        let insight = user.personalityInsight!
        #expect(insight.description == "Test description")
        #expect(insight.loveLanguage == "Quality Time")
        #expect(insight.communicationStyle == "Direct")
        #expect(insight.idealActivities == ["Reading"])
        #expect(insight.stressResponse == "Calm")
    }
    
    @Test func testCalendarEventNamingDifferences() async throws {
        // Test ExternalCalendarEvent uses start/end
        let externalEventJSON = """
        {
            "id": "ext123",
            "title": "Meeting",
            "start": "2025-01-01T10:00:00Z",
            "end": "2025-01-01T11:00:00Z",
            "providerId": "google",
            "externalId": "google_123"
        }
        """
        
        let externalData = externalEventJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let externalEvent = try decoder.decode(ExternalCalendarEvent.self, from: externalData)
        
        #expect(externalEvent.start == "2025-01-01T10:00:00Z")
        #expect(externalEvent.end == "2025-01-01T11:00:00Z")
        #expect(externalEvent.providerId == "google")
        #expect(externalEvent.externalId == "google_123")
        
        // Test CalendarEventDB uses startTime/endTime
        let dbEventJSON = """
        {
            "id": 1,
            "userId": 123,
            "title": "Date Night",
            "startTime": "2025-01-01T19:00:00Z",
            "endTime": "2025-01-01T21:00:00Z",
            "allDay": false,
            "eventType": "date",
            "externalEventId": null,
            "calendarProvider": null,
            "createdAt": "2025-01-01T10:00:00Z",
            "updatedAt": "2025-01-01T10:30:00Z"
        }
        """
        
        let dbData = dbEventJSON.data(using: .utf8)!
        let dbEvent = try decoder.decode(CalendarEventDB.self, from: dbData)
        
        #expect(dbEvent.startTime == "2025-01-01T19:00:00Z")
        #expect(dbEvent.endTime == "2025-01-01T21:00:00Z")
        #expect(dbEvent.userId == 123)
        #expect(dbEvent.allDay == false)
        #expect(dbEvent.eventType == "date")
        #expect(dbEvent.externalEventId == nil)
        #expect(dbEvent.calendarProvider == nil)
        #expect(dbEvent.createdAt == "2025-01-01T10:00:00Z")
        #expect(dbEvent.updatedAt == "2025-01-01T10:30:00Z")
    }
    
    @Test func testActivityAndRecommendationNaming() async throws {
        // Test Activity model camelCase fields
        let activityJSON = """
        {
            "id": 1,
            "name": "Coffee Shop",
            "description": "Great place for coffee",
            "category": "dining",
            "location": "Downtown",
            "rating": 4.5,
            "distance": "0.3 miles",
            "personalityMatch": "Thoughtful Harmonizer",
            "imageUrl": "https://example.com/image.jpg"
        }
        """
        
        let data = activityJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let activity = try decoder.decode(Activity.self, from: data)
        
        #expect(activity.personalityMatch == "Thoughtful Harmonizer")
        #expect(activity.imageUrl == "https://example.com/image.jpg")
        
        // Test GrokActivityRecommendation camelCase fields
        let grokRecJSON = """
        {
            "id": "grok_123",
            "name": "Restaurant",
            "description": "Fine dining",
            "category": "dining",
            "rating": 4.8,
            "distance": 1.2,
            "price": "$$$",
            "address": "123 Main St",
            "phone": "555-1234",
            "website": "https://restaurant.com",
            "specialties": ["Italian", "Wine"],
            "atmosphere": "Romantic",
            "estimatedCost": "$80-120",
            "recommendedTime": "Evening",
            "personalityMatch": "Social Butterfly"
        }
        """
        
        let grokData = grokRecJSON.data(using: .utf8)!
        let grokRec = try decoder.decode(GrokActivityRecommendation.self, from: grokData)
        
        #expect(grokRec.estimatedCost == "$80-120")
        #expect(grokRec.recommendedTime == "Evening")
        #expect(grokRec.personalityMatch == "Social Butterfly")
    }
    
    @Test func testMessageModelNaming() async throws {
        // Test MessageItem camelCase fields
        let messageJSON = """
        {
            "id": "msg_123",
            "content": "Great message content",
            "category": "appreciation",
            "personalityMatch": "Thoughtful Harmonizer",
            "tone": "warm",
            "estimatedImpact": "high"
        }
        """
        
        let data = messageJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(MessageItem.self, from: data)
        
        #expect(message.personalityMatch == "Thoughtful Harmonizer")
        #expect(message.estimatedImpact == "high")
    }
    
    @Test func testCalendarProviderNaming() async throws {
        // Test CalendarProvider camelCase fields
        let providerJSON = """
        {
            "id": "google",
            "name": "google",
            "displayName": "Google Calendar",
            "icon": "google-icon",
            "description": "Connect to Google Calendar",
            "isConnected": true,
            "status": "active",
            "authUrl": "https://auth.google.com",
            "lastSync": "2025-01-01T10:00:00Z",
            "errorMessage": null
        }
        """
        
        let data = providerJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let provider = try decoder.decode(CalendarProvider.self, from: data)
        
        #expect(provider.displayName == "Google Calendar")
        #expect(provider.isConnected == true)
        #expect(provider.authUrl == "https://auth.google.com")
        #expect(provider.lastSync == "2025-01-01T10:00:00Z")
        #expect(provider.errorMessage == nil)
    }
    
    @Test func testAssessmentAndStatsNaming() async throws {
        // Test AssessmentSavedResponse camelCase fields
        let assessmentJSON = """
        {
            "id": 1,
            "userId": 123,
            "personalityType": "Thoughtful Harmonizer",
            "completedAt": "2025-01-01T10:00:00Z"
        }
        """
        
        let data = assessmentJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let assessment = try decoder.decode(AssessmentSavedResponse.self, from: data)
        
        #expect(assessment.userId == 123)
        #expect(assessment.personalityType == "Thoughtful Harmonizer")
        #expect(assessment.completedAt == "2025-01-01T10:00:00Z")
        
        // Test UserStatsResponse camelCase fields
        let statsJSON = """
        {
            "eventsCreated": 5,
            "id": 1,
            "userId": 123,
            "createdAt": "2025-01-01T10:00:00Z",
            "updatedAt": "2025-01-01T10:30:00Z"
        }
        """
        
        let statsData = statsJSON.data(using: .utf8)!
        let stats = try decoder.decode(UserStatsResponse.self, from: statsData)
        
        #expect(stats.eventsCreated == 5)
        #expect(stats.userId == 123)
        #expect(stats.createdAt == "2025-01-01T10:00:00Z")
        #expect(stats.updatedAt == "2025-01-01T10:30:00Z")
    }
    
    // MARK: - Snake Case Conversion Tests
    
    @Test func testSnakeCaseConversion() async throws {
        #if DEBUG
        let testCases = [
            ("partnerName", "partner_name"),
            ("relationshipDuration", "relationship_duration"),
            ("personalityType", "personality_type"),
            ("loveLanguage", "love_language"),
            ("communicationStyle", "communication_style"),
            ("idealActivities", "ideal_activities"),
            ("stressResponse", "stress_response"),
            ("imageUrl", "image_url"),
            ("personalityMatch", "personality_match"),
            ("startTime", "start_time"),
            ("endTime", "end_time"),
            ("allDay", "all_day"),
            ("eventType", "event_type"),
            ("createdAt", "created_at"),
            ("updatedAt", "updated_at"),
            ("displayName", "display_name"),
            ("isConnected", "is_connected"),
            ("authUrl", "auth_url"),
            ("lastSync", "last_sync"),
            ("errorMessage", "error_message"),
            ("providerId", "provider_id"),
            ("externalId", "external_id"),
            ("estimatedCost", "estimated_cost"),
            ("recommendedTime", "recommended_time"),
            ("estimatedImpact", "estimated_impact"),
            ("eventsCreated", "events_created"),
            ("userId", "user_id"),
            ("completedAt", "completed_at"),
            ("onboardingData", "onboarding_data")
        ]
        
        let mapping = NamingConventions.generateSnakeCaseMapping(testCases.map { $0.0 })
        
        for (camelCase, expectedSnakeCase) in testCases {
            #expect(mapping[camelCase] == expectedSnakeCase, 
                   "\(camelCase) should map to \(expectedSnakeCase), got \(mapping[camelCase] ?? "nil")")
        }
        #endif
    }
    
    // MARK: - Field Name Constants Tests
    
    @Test func testFieldNameConstants() async throws {
        #if DEBUG
        // Verify field name constants match expected values
        #expect(FieldNames.partnerName == "partnerName")
        #expect(FieldNames.relationshipDuration == "relationshipDuration")
        #expect(FieldNames.personalityType == "personalityType")
        #expect(FieldNames.loveLanguage == "loveLanguage")
        #expect(FieldNames.communicationStyle == "communicationStyle")
        #expect(FieldNames.idealActivities == "idealActivities")
        #expect(FieldNames.stressResponse == "stressResponse")
        #expect(FieldNames.imageUrl == "imageUrl")
        #expect(FieldNames.personalityMatch == "personalityMatch")
        #expect(FieldNames.startTime == "startTime")
        #expect(FieldNames.endTime == "endTime")
        #expect(FieldNames.allDay == "allDay")
        #expect(FieldNames.eventType == "eventType")
        #expect(FieldNames.createdAt == "createdAt")
        #expect(FieldNames.updatedAt == "updatedAt")
        #expect(FieldNames.displayName == "displayName")
        #expect(FieldNames.isConnected == "isConnected")
        #expect(FieldNames.authUrl == "authUrl")
        #expect(FieldNames.lastSync == "lastSync")
        #expect(FieldNames.errorMessage == "errorMessage")
        #expect(FieldNames.estimatedCost == "estimatedCost")
        #expect(FieldNames.recommendedTime == "recommendedTime")
        #expect(FieldNames.estimatedImpact == "estimatedImpact")
        #expect(FieldNames.eventsCreated == "eventsCreated")
        #expect(FieldNames.userId == "userId")
        #expect(FieldNames.completedAt == "completedAt")
        #expect(FieldNames.onboardingData == "onboardingData")
        #endif
    }
    
    // MARK: - Demonstrate No CodingKeys Needed
    
    @Test func testNoCodingKeysNeeded() async throws {
        // This test demonstrates that our models decode correctly without any CodingKeys
        // because the backend API already uses camelCase
        
        let complexJSON = """
        {
            "user": {
                "id": 1,
                "email": "test@example.com",
                "name": "Test User",
                "partnerName": "Partner",
                "relationshipDuration": "1 year",
                "partnerAge": 25,
                "personalityType": "Thoughtful Harmonizer",
                "personalityInsight": {
                    "description": "Thoughtful and caring",
                    "loveLanguage": "Quality Time",
                    "communicationStyle": "Direct and honest",
                    "idealActivities": ["Deep conversations", "Quiet activities"],
                    "stressResponse": "Seeks calm discussion"
                },
                "preferences": {
                    "budget": "medium",
                    "maxDistance": 10
                },
                "location": {
                    "latitude": 37.7749,
                    "longitude": -122.4194
                }
            }
        }
        """
        
        let data = complexJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // This should decode successfully without any CodingKeys defined
        let authEnvelope = try decoder.decode(AuthEnvelope.self, from: data)
        
        let user = authEnvelope.user
        #expect(user.partnerName == "Partner")
        #expect(user.relationshipDuration == "1 year")
        #expect(user.partnerAge == 25)
        #expect(user.personalityType == "Thoughtful Harmonizer")
        
        let insight = user.personalityInsight!
        #expect(insight.loveLanguage == "Quality Time")
        #expect(insight.communicationStyle == "Direct and honest")
        #expect(insight.idealActivities.count == 2)
        #expect(insight.stressResponse == "Seeks calm discussion")
        
        // JSONValue fields should decode properly
        #expect(user.preferences != nil)
        #expect(user.location != nil)
    }
}