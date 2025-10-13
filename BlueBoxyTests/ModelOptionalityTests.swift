//
//  ModelOptionalityTests.swift
//  BlueBoxyTests
//
//  Tests to verify model optionality patterns match backend schema
//

import Testing
import Foundation
@testable import BlueBoxy

struct ModelOptionalityTests {
    
    // MARK: - User Model Optionality Tests
    
    @Test func testUserModelRequiredFields() async throws {
        // Test minimal valid User with only required fields
        let minimalUserJSON = """
        {
            "id": 1,
            "email": "test@example.com",
            "name": "Test User"
        }
        """
        
        let data = minimalUserJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)
        
        #expect(user.id == 1)
        #expect(user.email == "test@example.com")
        #expect(user.name == "Test User")
        #expect(user.partnerName == nil)
        #expect(user.relationshipDuration == nil)
        #expect(user.partnerAge == nil)
        #expect(user.personalityType == nil)
        #expect(user.personalityInsight == nil)
        #expect(user.preferences == nil)
        #expect(user.location == nil)
    }
    
    @Test func testUserModelWithAllOptionalFields() async throws {
        // Test User with all optional fields present
        let fullUserJSON = """
        {
            "id": 2,
            "email": "full@example.com",
            "name": "Full User",
            "partnerName": "Partner",
            "relationshipDuration": "6 months",
            "partnerAge": 25,
            "personalityType": "Thoughtful Harmonizer",
            "personalityInsight": {
                "description": "Thoughtful person",
                "loveLanguage": "Quality Time",
                "communicationStyle": "Direct",
                "idealActivities": ["Reading", "Walking"],
                "stressResponse": "Calm discussion"
            },
            "preferences": {
                "budget": "medium",
                "distance": 10
            },
            "location": {
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        }
        """
        
        let data = fullUserJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: data)
        
        // Verify required fields
        #expect(user.id == 2)
        #expect(user.email == "full@example.com")
        #expect(user.name == "Full User")
        
        // Verify optional fields are present and decoded
        #expect(user.partnerName == "Partner")
        #expect(user.relationshipDuration == "6 months")
        #expect(user.partnerAge == 25)
        #expect(user.personalityType == "Thoughtful Harmonizer")
        #expect(user.personalityInsight != nil)
        #expect(user.preferences != nil)
        #expect(user.location != nil)
        
        // Verify PersonalityInsight fields when present
        let insight = user.personalityInsight!
        #expect(insight.description == "Thoughtful person")
        #expect(insight.loveLanguage == "Quality Time")
        #expect(insight.communicationStyle == "Direct")
        #expect(insight.idealActivities.count == 2)
        #expect(insight.stressResponse == "Calm discussion")
    }
    
    // MARK: - Calendar Event Optionality Tests
    
    @Test func testExternalCalendarEventRequiredFields() async throws {
        let minimalEventJSON = """
        {
            "id": "ext123",
            "title": "Meeting",
            "start": "2025-01-01T10:00:00Z",
            "end": "2025-01-01T11:00:00Z",
            "providerId": "google",
            "externalId": "google_123"
        }
        """
        
        let data = minimalEventJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(ExternalCalendarEvent.self, from: data)
        
        #expect(event.id == "ext123")
        #expect(event.title == "Meeting")
        #expect(event.start == "2025-01-01T10:00:00Z")
        #expect(event.end == "2025-01-01T11:00:00Z")
        #expect(event.providerId == "google")
        #expect(event.externalId == "google_123")
        
        // Optional fields should be nil
        #expect(event.description == nil)
        #expect(event.location == nil)
        #expect(event.attendees == nil)
    }
    
    @Test func testCalendarEventDBOptionalFields() async throws {
        let minimalEventJSON = """
        {
            "id": 1,
            "userId": 123,
            "title": "Date Night",
            "startTime": "2025-01-01T19:00:00Z",
            "endTime": "2025-01-01T21:00:00Z",
            "allDay": false,
            "eventType": "date"
        }
        """
        
        let data = minimalEventJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(CalendarEventDB.self, from: data)
        
        // Required fields
        #expect(event.id == 1)
        #expect(event.userId == 123)
        #expect(event.title == "Date Night")
        #expect(event.startTime == "2025-01-01T19:00:00Z")
        #expect(event.endTime == "2025-01-01T21:00:00Z")
        #expect(event.allDay == false)
        #expect(event.eventType == "date")
        
        // Optional fields should be nil
        #expect(event.description == nil)
        #expect(event.location == nil)
        #expect(event.status == nil)
        #expect(event.externalEventId == nil)
        #expect(event.calendarProvider == nil)
        #expect(event.reminders == nil)
        #expect(event.metadata == nil)
        #expect(event.createdAt == nil)
        #expect(event.updatedAt == nil)
    }
    
    // MARK: - Recommendation Optionality Tests
    
    @Test func testGrokActivityRecommendationRequiredFields() async throws {
        let minimalRecJSON = """
        {
            "id": "grok_123",
            "name": "Coffee Shop",
            "description": "Great coffee place",
            "category": "dining"
        }
        """
        
        let data = minimalRecJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let rec = try decoder.decode(GrokActivityRecommendation.self, from: data)
        
        // Required fields
        #expect(rec.id == "grok_123")
        #expect(rec.name == "Coffee Shop")
        #expect(rec.description == "Great coffee place")
        #expect(rec.category == "dining")
        
        // All optional fields should be nil
        #expect(rec.rating == nil)
        #expect(rec.distance == nil)
        #expect(rec.price == nil)
        #expect(rec.address == nil)
        #expect(rec.phone == nil)
        #expect(rec.website == nil)
        #expect(rec.specialties == nil)
        #expect(rec.atmosphere == nil)
        #expect(rec.estimatedCost == nil)
        #expect(rec.recommendedTime == nil)
        #expect(rec.personalityMatch == nil)
    }
    
    @Test func testAIPoweredActivityOptionalFields() async throws {
        let minimalActivityJSON = """
        {
            "id": 456,
            "name": "Museum Visit",
            "description": "Art museum downtown",
            "category": "cultural"
        }
        """
        
        let data = minimalActivityJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let activity = try decoder.decode(AIPoweredActivity.self, from: data)
        
        // Required fields
        #expect(activity.id == 456)
        #expect(activity.name == "Museum Visit")
        #expect(activity.description == "Art museum downtown")
        #expect(activity.category == "cultural")
        
        // Optional fields should be nil
        #expect(activity.rating == nil)
        #expect(activity.personalityMatch == nil)
        #expect(activity.distance == nil)
        #expect(activity.imageUrl == nil)
        #expect(activity.location == nil)
    }
    
    // MARK: - JSONValue Optionality Tests
    
    @Test func testJSONValueHandling() async throws {
        let jsonWithVariousTypes = """
        {
            "preferences": {
                "budget": "medium",
                "maxDistance": 10,
                "isFlexible": true,
                "activities": ["dining", "outdoor"],
                "nested": {
                    "key": "value"
                },
                "nullValue": null
            }
        }
        """
        
        struct TestModel: Decodable {
            let preferences: [String: JSONValue]
        }
        
        let data = jsonWithVariousTypes.data(using: .utf8)!
        let decoder = JSONDecoder()
        let model = try decoder.decode(TestModel.self, from: data)
        
        let prefs = model.preferences
        
        // Test different JSONValue types
        if case .string(let budget) = prefs["budget"] {
            #expect(budget == "medium")
        } else {
            #expect(Bool(false), "budget should be string")
        }
        
        if case .int(let distance) = prefs["maxDistance"] {
            #expect(distance == 10)
        } else {
            #expect(Bool(false), "maxDistance should be int")
        }
        
        if case .bool(let flexible) = prefs["isFlexible"] {
            #expect(flexible == true)
        } else {
            #expect(Bool(false), "isFlexible should be bool")
        }
        
        if case .array(let activities) = prefs["activities"] {
            #expect(activities.count == 2)
        } else {
            #expect(Bool(false), "activities should be array")
        }
        
        if case .object(let nested) = prefs["nested"] {
            #expect(nested["key"] != nil)
        } else {
            #expect(Bool(false), "nested should be object")
        }
        
        if case .null = prefs["nullValue"] {
            // Expected
        } else {
            #expect(Bool(false), "nullValue should be null")
        }
    }
    
    // MARK: - Date String Format Tests
    
    @Test func testISO8601DateStringHandling() async throws {
        let eventWithDatesJSON = """
        {
            "id": 1,
            "userId": 123,
            "title": "Test Event",
            "startTime": "2025-01-01T19:00:00.000Z",
            "endTime": "2025-01-01T21:00:00Z",
            "allDay": false,
            "eventType": "test",
            "createdAt": "2025-01-01T10:00:00.123Z",
            "updatedAt": "2025-01-01T10:30:00Z"
        }
        """
        
        let data = eventWithDatesJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(CalendarEventDB.self, from: data)
        
        // Verify date strings are preserved as strings
        #expect(event.startTime == "2025-01-01T19:00:00.000Z")
        #expect(event.endTime == "2025-01-01T21:00:00Z")
        #expect(event.createdAt == "2025-01-01T10:00:00.123Z")
        #expect(event.updatedAt == "2025-01-01T10:30:00Z")
        
        // Test date validation utility
        #if DEBUG
        let startTimeValidation = ModelValidation.validateISO8601DateString(event.startTime, fieldName: "startTime")
        #expect(startTimeValidation.isValid)
        
        let endTimeValidation = ModelValidation.validateISO8601DateString(event.endTime, fieldName: "endTime")
        #expect(endTimeValidation.isValid)
        #endif
    }
    
    // MARK: - Error Envelope Optionality Tests
    
    @Test func testErrorEnvelopeOptionalFields() async throws {
        let minimalErrorJSON = """
        {
            "error": {
            }
        }
        """
        
        let data = minimalErrorJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(APIErrorEnvelope.self, from: data)
        
        #expect(envelope.success == nil)
        #expect(envelope.error != nil)
        #expect(envelope.error?.code == nil)
        #expect(envelope.error?.message == nil)
    }
}