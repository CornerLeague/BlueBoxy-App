//
//  ModelDecodingTests.swift
//  BlueBoxyTests
//
//  Comprehensive tests to validate model decoding with JSON fixtures
//  Tests all models against sample API responses
//

import Testing
import Foundation
@testable import BlueBoxy

struct ModelDecodingTests {
    
    // MARK: - Authentication Model Tests
    
    @Test func testDecodeAuthMe() async throws {
        let env: AuthEnvelope = try FixtureLoader.loadAuth("me_success", as: AuthEnvelope.self)
        #expect(env.user.id > 0)
        #expect(env.user.email.isEmpty == false)
        #expect(env.user.name != nil)
        
        // Optional fields should be handled correctly
        if let partnerName = env.user.partnerName {
            #expect(partnerName.isEmpty == false)
        }
        
        // Date parsing validation
        #expect(env.user.createdAt != nil)
        #expect(env.user.updatedAt != nil)
    }
    
    // MARK: - Message Model Tests
    
    @Test func testDecodeMessages() async throws {
        let res: MessageGenerationResponse = try FixtureLoader.loadMessages("generate_success", as: MessageGenerationResponse.self)
        #expect(res.success == true)
        #expect(res.messages.isEmpty == false)
        
        // Verify message structure
        let firstMessage = res.messages.first!
        #expect(firstMessage.id.isEmpty == false)
        #expect(firstMessage.content.isEmpty == false)
        #expect(firstMessage.category.isEmpty == false)
        #expect(firstMessage.generatedAt != nil)
        
        // Test JSONValue context
        #expect(res.context.isEmpty == false)
        for (key, value) in res.context {
            #expect(key.isEmpty == false)
            // JSONValue should be valid
            switch value {
            case .string(let str): #expect(str != nil)
            case .int(let num): #expect(num != nil)
            case .double(let num): #expect(num != nil)
            case .bool(let flag): #expect(flag != nil)
            case .array(let arr): #expect(arr != nil)
            case .object(let obj): #expect(obj != nil)
            case .null: break // null is valid
            }
        }
    }
    
    // MARK: - Activity Model Tests
    
    @Test func testDecodeActivities() async throws {
        let response: ActivitiesResponse = try FixtureLoader.loadActivities("list_success", as: ActivitiesResponse.self)
        #expect(response.activities.isEmpty == false)
        
        // Verify activity structure
        for activity in response.activities {
            #expect(activity.id > 0)
            #expect(activity.name.isEmpty == false)
            #expect(activity.description.isEmpty == false)
            #expect(activity.category.isEmpty == false)
            
            // Optional numeric fields
            if let rating = activity.rating {
                #expect(rating >= 0)
                #expect(rating <= 5)
            }
            if let distance = activity.distance {
                #expect(distance >= 0)
            }
            if let personalityMatch = activity.personalityMatch {
                #expect(personalityMatch >= 0)
                #expect(personalityMatch <= 100)
            }
        }
    }
    
    // MARK: - Event Model Tests
    
    @Test func testDecodeEventCreate() async throws {
        let event: Event = try FixtureLoader.loadEvents("create_success", as: Event.self)
        #expect(event.id > 0)
        #expect(event.userId > 0)
        #expect(event.title.isEmpty == false)
        #expect(event.eventType.isEmpty == false)
        #expect(event.status.isEmpty == false)
        #expect(event.startTime < event.endTime)
    }
    
    @Test func testDecodeEventsList() async throws {
        let response: EventsResponse = try FixtureLoader.loadEvents("list_success", as: EventsResponse.self)
        #expect(response.events.isEmpty == false)
        
        for event in response.events {
            #expect(event.id > 0)
            #expect(event.title.isEmpty == false)
            #expect(event.startTime < event.endTime)
        }
    }
    
    // MARK: - Recommendation Model Tests
    
    @Test func testDecodeAIPoweredRecommendations() async throws {
        let response: AIPoweredRecommendationsResponse = try FixtureLoader.loadRecommendations("ai_powered_success", as: AIPoweredRecommendationsResponse.self)
        #expect(response.success == true)
        #expect(response.recommendations.activities.isEmpty == false)
        
        for activity in response.recommendations.activities {
            #expect(activity.id > 0)
            #expect(activity.name.isEmpty == false)
        }
    }
    
    @Test func testDecodeRecommendationActivities() async throws {
        let response: RecommendationsResponse = try FixtureLoader.loadRecommendations("activities_success", as: RecommendationsResponse.self)
        #expect(response.activities.isEmpty == false)
        
        for activity in response.activities {
            #expect(activity.id > 0)
            #expect(activity.name.isEmpty == false)
            #expect(activity.category.isEmpty == false)
        }
    }
    
    @Test func testDecodeLocationRecommendations() async throws {
        let response: RecommendationsResponse = try FixtureLoader.loadRecommendations("location_post_success", as: RecommendationsResponse.self)
        #expect(response.activities.isEmpty == false)
        
        for activity in response.activities {
            #expect(activity.id > 0)
            #expect(activity.name.isEmpty == false)
            
            // Location-based should have distance
            if let distance = activity.distance {
                #expect(distance >= 0)
            }
        }
    }
    
    // MARK: - User Stats Model Tests
    
    @Test func testDecodeUserStats() async throws {
        let stats: UserStatsResponse = try FixtureLoader.loadUser("stats_success", as: UserStatsResponse.self)
        
        #expect(stats.eventsCreated >= 0)
        #expect(stats.messagesGenerated >= 0)
        #expect(stats.activitiesCompleted >= 0)
        #expect(stats.recommendationsUsed >= 0)
        #expect(stats.streakDays >= 0)
        
        // Optional date field
        if let lastActive = stats.lastActive {
            #expect(lastActive <= Date())
        }
    }
    
    // MARK: - Assessment Model Tests
    
    @Test func testDecodeAssessmentResult() async throws {
        let result: AssessmentResult = try FixtureLoader.loadAssessment("save_success", as: AssessmentResult.self)
        
        #expect(result.personalityType.isEmpty == false)
        #expect(result.responses.isEmpty == false)
        
        // Validate scores if present
        if let scores = result.scores {
            for (key, value) in scores {
                #expect(key.isEmpty == false)
                #expect(value >= 0)
            }
        }
    }
    
    // MARK: - Calendar Model Tests
    
    @Test func testDecodeCalendarProviders() async throws {
        let response: CalendarProvidersResponse = try FixtureLoader.loadCalendar("providers_success", as: CalendarProvidersResponse.self)
        #expect(response.providers.isEmpty == false)
        
        for provider in response.providers {
            #expect(provider.id.isEmpty == false)
            #expect(provider.name.isEmpty == false)
        }
    }
    
    // MARK: - Edge Cases and Validation
    
    @Test func testJSONValueHandling() async throws {
        let res: MessageGenerationResponse = try FixtureLoader.loadMessages("generate_success")
        
        for (key, value) in res.context {
            #expect(key.isEmpty == false)
            
            // Test JSONValue accessibility
            switch value {
            case .string(let str): #expect(str.isEmpty == false)
            case .int(let num): #expect(num != nil)
            case .double(let num): #expect(num != nil)
            case .bool(let flag): #expect(flag != nil)
            case .array: break // arrays can be empty
            case .object: break // objects can be empty
            case .null: break // null is valid
            }
        }
    }
    
    @Test func testDateDecoding() async throws {
        let user: User = try FixtureLoader.loadAuth("me_success")
        
        #expect(user.createdAt != nil)
        #expect(user.updatedAt != nil)
        
        // Dates should be reasonable
        let now = Date()
        let tenYearsAgo = now.addingTimeInterval(-10 * 365 * 24 * 60 * 60)
        let oneYearFromNow = now.addingTimeInterval(365 * 24 * 60 * 60)
        
        #expect(user.createdAt > tenYearsAgo)
        #expect(user.createdAt < oneYearFromNow)
    }
    
    @Test func testOptionalFieldHandling() async throws {
        let activities: ActivitiesResponse = try FixtureLoader.loadActivities("list_success")
        
        // Test that activities with missing optional fields work
        for activity in activities.activities {
            // Required fields must be present
            #expect(activity.name.isEmpty == false)
            #expect(activity.description.isEmpty == false)
            #expect(activity.category.isEmpty == false)
            
            // Optional fields can be nil - that's okay
            // Just ensure they don't crash when accessed
            let _ = activity.rating
            let _ = activity.distance
            let _ = activity.personalityMatch
            let _ = activity.location
            let _ = activity.imageUrl
        }
    }
    
    // MARK: - Fixture Validation Tests
    
    @Test func testAllFixturesLoadable() async throws {
        let categories = ["auth", "messages", "activities", "recommendations", "events", "user", "assessment", "calendar"]
        
        for category in categories {
            let fixtures = FixtureLoader.listFixtures(in: category)
            for fixture in fixtures {
                // Should be able to load each fixture as JSON
                #expect(throws: Never.self) {
                    let _ = try FixtureLoader.loadJSON("\(category)/\(fixture)")
                }
            }
        }
    }
    
    @Test func testFixtureLoaderErrorHandling() async throws {
        // Test that loading non-existent fixtures throws proper errors
        #expect(throws: FixtureError.self) {
            let _: User = try FixtureLoader.loadAuth("nonexistent")
        }
        
        // Test that invalid type decoding throws proper errors
        #expect(throws: FixtureError.self) {
            // Try to decode user data as activities (should fail)
            let _: ActivitiesResponse = try FixtureLoader.loadAuth("me_success")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testDecodingPerformance() async throws {
        // Measure decoding performance for common operations
        let startTime = Date()
        
        // Decode several different model types
        let _: ActivitiesResponse = try FixtureLoader.loadActivities("list_success")
        let _: MessageGenerationResponse = try FixtureLoader.loadMessages("generate_success")
        let _: RecommendationsResponse = try FixtureLoader.loadRecommendations("activities_success")
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time (< 100ms for all three)
        #expect(duration < 0.1)
    }
}
