//
//  RequestModelsTests.swift
//  BlueBoxyTests
//
//  Tests for request models to validate encoding and functionality
//  Ensures all request structs encode correctly and validation works
//

import Testing
import Foundation
@testable import BlueBoxy

struct RequestModelsTests {
    
    // MARK: - Auth Request Tests
    
    @Test func testRegisterRequestEncoding() async throws {
        let request = RegisterRequest(
            email: "test@example.com",
            password: "password123",
            name: "Test User",
            partnerName: "Test Partner",
            relationshipDuration: "1 year",
            partnerAge: 25
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["email"] as? String == "test@example.com")
        #expect(json?["password"] as? String == "password123")
        #expect(json?["name"] as? String == "Test User")
        #expect(json?["partner_name"] as? String == "Test Partner")
        #expect(json?["relationship_duration"] as? String == "1 year")
        #expect(json?["partner_age"] as? Int == 25)
        
        // Verify no camelCase fields leak through
        #expect(json?["partnerName"] == nil)
        #expect(json?["relationshipDuration"] == nil)
        #expect(json?["partnerAge"] == nil)
    }
    
    @Test func testRegisterRequestValidation() async throws {
        let validRequest = RegisterRequest(
            email: "test@example.com",
            password: "password123"
        )
        
        #expect(validRequest.isValid)
        #expect(validRequest.hasValidEmail)
        #expect(validRequest.hasValidPassword)
        
        let invalidEmail = RegisterRequest(
            email: "invalid-email",
            password: "password123"
        )
        
        #expect(invalidEmail.isValid)
        #expect(invalidEmail.hasValidEmail == false)
        #expect(invalidEmail.hasValidPassword)
        
        let weakPassword = RegisterRequest(
            email: "test@example.com",
            password: "123"
        )
        
        #expect(weakPassword.isValid)
        #expect(weakPassword.hasValidEmail)
        #expect(weakPassword.hasValidPassword == false)
    }
    
    @Test func testLoginRequestEncoding() async throws {
        let request = LoginRequest(
            email: "test@example.com",
            password: "password123"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["email"] as? String == "test@example.com")
        #expect(json?["password"] as? String == "password123")
    }
    
    // MARK: - Assessment Request Tests
    
    @Test func testAssessmentResponsesRequestEncoding() async throws {
        let responses = [
            "question1": "answer1",
            "question2": "answer2"
        ]
        
        let request = AssessmentResponsesRequest(
            responses: responses,
            personalityType: "Thoughtful Harmonizer"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["personalityType"] as? String == "Thoughtful Harmonizer")
        
        let jsonResponses = json?["responses"] as? [String: String]
        #expect(jsonResponses?["question1"] == "answer1")
        #expect(jsonResponses?["question2"] == "answer2")
    }
    
    @Test func testGuestAssessmentRequestEncoding() async throws {
        let responses = ["q1": "a1", "q2": "a2"]
        let onboardingData = JSONValue.object([
            "source": JSONValue.string("mobile_app"),
            "timestamp": JSONValue.int(1640995200)
        ])
        
        let request = GuestAssessmentRequest(
            responses: responses,
            personalityType: "Creative Explorer",
            onboardingData: onboardingData
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["personalityType"] as? String == "Creative Explorer")
        
        let jsonResponses = json?["responses"] as? [String: String]
        #expect(jsonResponses?["q1"] == "a1")
        #expect(jsonResponses?["q2"] == "a2")
        
        // Validate onboardingData is properly encoded
        #expect(json?["onboardingData"] != nil)
    }
    
    // MARK: - Preferences Request Tests
    
    @Test func testSavePreferencesRequestEncoding() async throws {
        let location = GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
        let preferences = [
            "budget": JSONValue.string("medium"),
            "distance": JSONValue.int(10)
        ]
        
        let request = SavePreferencesRequest(
            preferences: preferences,
            location: location,
            partnerAge: 25
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["partnerAge"] as? Int == 25)
        #expect(json?["preferences"] != nil)
        #expect(json?["location"] != nil)
        #expect(request.hasData)
        
        let locationData = json?["location"] as? [String: Double]
        #expect(locationData?["latitude"] == 37.7749)
        #expect(locationData?["longitude"] == -122.4194)
    }
    
    @Test func testGeoLocationPayloadValidation() async throws {
        let validLocation = GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
        #expect(validLocation.isValid)
        
        let invalidLatitude = GeoLocationPayload(latitude: 100.0, longitude: -122.4194)
        #expect(invalidLatitude.isValid == false)
        
        let invalidLongitude = GeoLocationPayload(latitude: 37.7749, longitude: 200.0)
        #expect(invalidLongitude.isValid == false)
        
        // Test CoreLocation integration if available
        #if canImport(CoreLocation)
        import CoreLocation
        
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let locationFromCoordinate = GeoLocationPayload(coordinate: coordinate)
        
        #expect(locationFromCoordinate.latitude == 40.7128)
        #expect(locationFromCoordinate.longitude == -74.0060)
        #expect(locationFromCoordinate.isValid)
        
        let convertedCoordinate = locationFromCoordinate.coordinate
        #expect(convertedCoordinate.latitude == 40.7128)
        #expect(convertedCoordinate.longitude == -74.0060)
        #endif
    }
    
    // MARK: - Recommendation Request Tests
    
    @Test func testLocationBasedPostRequestEncoding() async throws {
        let location = GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
        let preferences = [
            "budget": JSONValue.string("medium"),
            "atmosphere": JSONValue.string("romantic")
        ]
        
        let request = LocationBasedPostRequest(
            location: location,
            radius: 5,
            category: "dining",
            preferences: preferences,
            personalityType: "Thoughtful Harmonizer",
            resetAlgorithm: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["radius"] as? Int == 5)
        #expect(json?["category"] as? String == "dining")
        #expect(json?["personalityType"] as? String == "Thoughtful Harmonizer")
        #expect(json?["resetAlgorithm"] as? Bool == true)
        #expect(json?["location"] != nil)
        #expect(json?["preferences"] != nil)
    }
    
    @Test func testLocationBasedPostRequestConvenienceInit() async throws {
        let request = LocationBasedPostRequest(
            latitude: 37.7749,
            longitude: -122.4194,
            category: "dining",
            radiusInMiles: 3
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["radius"] as? Int == 3)
        #expect(json?["category"] as? String == "dining")
        
        let locationData = json?["location"] as? [String: Double]
        #expect(locationData?["latitude"] == 37.7749)
        #expect(locationData?["longitude"] == -122.4194)
    }
    
    @Test func testDrinksRecommendationsRequestEncoding() async throws {
        let location = GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
        let drinkPrefs = ["cocktails", "wine", "craft_beer"]
        
        let request = DrinksRecommendationsRequest(
            location: location,
            radius: 2,
            drinkPreferences: drinkPrefs,
            personalityType: "Social Butterfly",
            resetAlgorithm: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["radius"] as? Int == 2)
        #expect(json?["personalityType"] as? String == "Social Butterfly")
        #expect(json?["resetAlgorithm"] as? Bool == false)
        
        let jsonDrinkPrefs = json?["drinkPreferences"] as? [String]
        #expect(jsonDrinkPrefs?.contains("cocktails") == true)
        #expect(jsonDrinkPrefs?.contains("wine") == true)
        #expect(jsonDrinkPrefs?.contains("craft_beer") == true)
    }
    
    @Test func testAIPoweredRecommendationsRequestEncoding() async throws {
        let location = GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
        let preferences = [
            "mood": JSONValue.string("romantic"),
            "time": JSONValue.string("evening")
        ]
        
        let request = AIPoweredRecommendationsRequest(
            category: "cultural",
            location: location,
            preferences: preferences
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["category"] as? String == "cultural")
        #expect(json?["location"] != nil)
        #expect(json?["preferences"] != nil)
    }
    
    // MARK: - Event Request Tests
    
    @Test func testCreateEventRequestEncoding() async throws {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later
        
        let reminders = JSONValue.array([
            JSONValue.string("15 minutes before"),
            JSONValue.string("1 hour before")
        ])
        
        let metadata = JSONValue.object([
            "source": JSONValue.string("app"),
            "priority": JSONValue.string("high")
        ])
        
        let request = CreateEventRequest(
            title: "Romantic Dinner",
            description: "Anniversary dinner",
            location: "Downtown Bistro",
            startTime: startTime,
            endTime: endTime,
            allDay: false,
            eventType: "date",
            status: "confirmed",
            externalEventId: nil,
            calendarProvider: "google",
            reminders: reminders,
            metadata: metadata
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["title"] as? String == "Romantic Dinner")
        #expect(json?["description"] as? String == "Anniversary dinner")
        #expect(json?["location"] as? String == "Downtown Bistro")
        #expect(json?["allDay"] as? Bool == false)
        #expect(json?["eventType"] as? String == "date")
        #expect(json?["status"] as? String == "confirmed")
        #expect(json?["calendarProvider"] as? String == "google")
        #expect(json?["reminders"] != nil)
        #expect(json?["metadata"] != nil)
        
        // Validate dates are properly encoded
        #expect(json?["startTime"] as? String != nil)
        #expect(json?["endTime"] as? String != nil)
    }
    
    @Test func testCreateEventRequestValidation() async throws {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)
        
        let validRequest = CreateEventRequest(
            title: "Valid Event",
            startTime: startTime,
            endTime: endTime,
            eventType: "date"
        )
        
        #expect(validRequest.isValid)
        #expect(validRequest.duration == 3600)
        #expect(validRequest.isFuture)
        
        let invalidRequest = CreateEventRequest(
            title: "",
            startTime: endTime,  // Start after end
            endTime: startTime,
            eventType: ""
        )
        
        #expect(invalidRequest.isValid == false)
        #expect(invalidRequest.duration < 0)
    }
    
    @Test func testCreateEventRequestConvenienceInits() async throws {
        let startTime = Date().addingTimeInterval(3600) // 1 hour from now
        let endTime = startTime.addingTimeInterval(7200) // 2 hours later
        
        // Test simple event initializer
        let simpleEvent = CreateEventRequest(
            title: "Simple Event",
            startTime: startTime,
            endTime: endTime
        )
        
        #expect(simpleEvent.title == "Simple Event")
        #expect(simpleEvent.eventType == "date")
        #expect(simpleEvent.isValid)
        
        // Test all-day event initializer
        let allDayEvent = CreateEventRequest(
            title: "All Day Event",
            date: Date(),
            eventType: "anniversary"
        )
        
        #expect(allDayEvent.title == "All Day Event")
        #expect(allDayEvent.eventType == "anniversary")
        #expect(allDayEvent.allDay == true)
        #expect(allDayEvent.isValid)
        #expect(allDayEvent.duration >= 24 * 3600) // At least 24 hours
    }
    
    // MARK: - Message Request Tests
    
    @Test func testMessageGenerateRequestEncoding() async throws {
        let request = MessageGenerateRequest(
            category: "appreciation",
            timeOfDay: .evening,
            recentContext: "Had a wonderful dinner together",
            specialOccasion: "Our anniversary"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["category"] as? String == "appreciation")
        #expect(json?["timeOfDay"] as? String == "evening")
        #expect(json?["recentContext"] as? String == "Had a wonderful dinner together")
        #expect(json?["specialOccasion"] as? String == "Our anniversary")
    }
    
    @Test func testMessageGenerateRequestValidation() async throws {
        let validRequest = MessageGenerateRequest(category: "appreciation")
        #expect(validRequest.isValid)
        #expect(validRequest.hasValidCategory)
        
        let invalidCategory = MessageGenerateRequest(category: "invalid_category")
        #expect(invalidCategory.isValid)
        #expect(invalidCategory.hasValidCategory == false)
        
        let emptyCategory = MessageGenerateRequest(category: "")
        #expect(emptyCategory.isValid == false)
        #expect(emptyCategory.hasValidCategory == false)
        
        // Test all valid categories
        for category in MessageGenerateRequest.validCategories {
            let request = MessageGenerateRequest(category: category)
            #expect(request.hasValidCategory)
        }
    }
    
    @Test func testTimeOfDayEncoding() async throws {
        let timeValues: [TimeOfDay] = [.morning, .afternoon, .evening, .night]
        
        for time in timeValues {
            let request = MessageGenerateRequest(category: "appreciation", timeOfDay: time)
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            #expect(json?["timeOfDay"] as? String == time.rawValue)
        }
    }
    
    // MARK: - Calendar Request Tests
    
    @Test func testCalendarDisconnectRequestEncoding() async throws {
        let request = CalendarDisconnectRequest(userId: "user123")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["userId"] as? String == "user123")
    }
    
    // MARK: - Debug Samples Tests
    
    #if DEBUG
    @Test func testDebugSamples() async throws {
        // Test that all debug sample objects can be encoded
        let registerSample = RegisterRequest.sample
        let loginSample = LoginRequest.sample
        let messageSample = MessageGenerateRequest.sample
        let eventSample = CreateEventRequest.sample
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Should not throw
        let _ = try encoder.encode(registerSample)
        let _ = try encoder.encode(loginSample)
        let _ = try encoder.encode(messageSample)
        let _ = try encoder.encode(eventSample)
        
        // Validate sample data
        #expect(registerSample.isValid)
        #expect(loginSample.isValid)
        #expect(messageSample.isValid)
        #expect(eventSample.isValid)
    }
    #endif
    
    // MARK: - JSON Encoding Integration Tests
    
    @Test func testAllRequestModelsEncodable() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Test that all request models can be encoded without errors
        let requests: [Encodable] = [
            RegisterRequest(email: "test@example.com", password: "password123"),
            LoginRequest(email: "test@example.com", password: "password123"),
            AssessmentResponsesRequest(responses: ["q1": "a1"]),
            GuestAssessmentRequest(responses: ["q1": "a1"], personalityType: "Test"),
            SavePreferencesRequest(),
            UpdatePreferencesRequest(preferences: ["key": JSONValue.string("value")]),
            LocationBasedPostRequest(
                location: GeoLocationPayload(latitude: 0, longitude: 0),
                radius: 5,
                category: "test"
            ),
            DrinksRecommendationsRequest(
                location: GeoLocationPayload(latitude: 0, longitude: 0),
                radius: 5,
                drinkPreferences: ["coffee"]
            ),
            AIPoweredRecommendationsRequest(category: "test"),
            CalendarDisconnectRequest(userId: "test"),
            CreateEventRequest(
                title: "Test",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                eventType: "test"
            ),
            MessageGenerateRequest(category: "test")
        ]
        
        for request in requests {
            // Should not throw
            let _ = try encoder.encode(request)
        }
    }
}