//
//  FixtureIntegrationTests.swift
//  BlueBoxyTests
//
//  Tests to verify all fixture files are properly loaded and decoded
//  Validates the complete fixture integration with actual API sample data
//

import Testing
import Foundation
@testable import BlueBoxy

struct FixtureIntegrationTests {
    
    // MARK: - App Fixture Loading Tests
    
    @Test func testLoadAuthMeFixture() async throws {
        let authEnvelope = try FixtureLoader.loadAuthMe()
        
        // Verify auth envelope structure
        #expect(authEnvelope.user.id > 0)
        #expect(authEnvelope.user.email.isEmpty == false)
        #expect(authEnvelope.user.name.isEmpty == false)
        
        // Verify optional fields can be present
        if let partnerName = authEnvelope.user.partnerName {
            #expect(partnerName.isEmpty == false)
        }
        
        if let personalityInsight = authEnvelope.user.personalityInsight {
            #expect(personalityInsight.description.isEmpty == false)
            #expect(personalityInsight.loveLanguage.isEmpty == false)
            #expect(personalityInsight.communicationStyle.isEmpty == false)
            #expect(personalityInsight.idealActivities.isEmpty == false)
            #expect(personalityInsight.stressResponse.isEmpty == false)
        }
    }
    
    @Test func testLoadMessageGenerationFixture() async throws {
        let messageResponse = try FixtureLoader.loadMessageGeneration()
        
        // Verify response structure
        #expect(messageResponse.success == true)
        #expect(messageResponse.messages.isEmpty == false)
        #expect(messageResponse.context.isEmpty == false)
        
        // Verify message structure
        let firstMessage = messageResponse.messages.first!
        #expect(firstMessage.id.isEmpty == false)
        #expect(firstMessage.content.isEmpty == false)
        #expect(firstMessage.category.isEmpty == false)
        #expect(firstMessage.personalityMatch.isEmpty == false)
        #expect(firstMessage.tone.isEmpty == false)
        #expect(firstMessage.estimatedImpact.isEmpty == false)
    }
    
    @Test func testLoadActivitiesListFixture() async throws {
        let activities = try FixtureLoader.loadActivitiesList()
        
        #expect(activities.isEmpty == false)
        
        let firstActivity = activities.first!
        #expect(firstActivity.id > 0)
        #expect(firstActivity.name.isEmpty == false)
        #expect(firstActivity.description.isEmpty == false)
        #expect(firstActivity.category.isEmpty == false)
        
        // Optional fields validation
        if let rating = firstActivity.rating {
            #expect(rating >= 0.0 && rating <= 5.0)
        }
        
        if let personalityMatch = firstActivity.personalityMatch {
            #expect(personalityMatch.isEmpty == false)
        }
    }
    
    @Test func testLoadAssessmentSaveFixture() async throws {
        let assessment = try FixtureLoader.loadAssessmentSave()
        
        #expect(assessment.id > 0)
        #expect(assessment.userId > 0)
        #expect(assessment.personalityType.isEmpty == false)
        #expect(assessment.completedAt.isEmpty == false)
        
        // Validate ISO date format
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: assessment.completedAt) != nil)
    }
    
    @Test func testLoadSimpleRecommendationsFixture() async throws {
        let recommendations = try FixtureLoader.loadSimpleRecommendations()
        
        #expect(recommendations.isEmpty == false)
        
        let firstRec = recommendations.first!
        #expect(firstRec.title.isEmpty == false)
        #expect(firstRec.description.isEmpty == false)
        #expect(firstRec.category.isEmpty == false)
    }
    
    @Test func testLoadLocationPostRecommendationsFixture() async throws {
        let response = try FixtureLoader.loadLocationPostRecommendations()
        
        #expect(response.success == true)
        #expect(response.recommendations.isEmpty == false)
        #expect(response.canGenerateMore != nil)
        #expect(response.generationsRemaining >= 0)
        #expect(response.category.isEmpty == false)
        #expect(response.radius > 0)
        
        // Verify recommendation structure
        let firstRec = response.recommendations.first!
        #expect(firstRec.id.isEmpty == false)
        #expect(firstRec.name.isEmpty == false)
        #expect(firstRec.description.isEmpty == false)
        #expect(firstRec.category.isEmpty == false)
    }
    
    @Test func testLoadRecommendationCategoriesFixture() async throws {
        let response = try FixtureLoader.loadRecommendationCategories()
        
        #expect(response.success == true)
        #expect(response.categories.isEmpty == false)
        
        let firstCategory = response.categories.first!
        #expect(firstCategory.id.isEmpty == false)
        #expect(firstCategory.label.isEmpty == false)
        #expect(firstCategory.icon.isEmpty == false)
        #expect(firstCategory.color.isEmpty == false)
        
        if !response.drinkPreferences.isEmpty {
            let firstDrink = response.drinkPreferences.first!
            #expect(firstDrink.id.isEmpty == false)
            #expect(firstDrink.label.isEmpty == false)
            #expect(firstDrink.icon.isEmpty == false)
        }
    }
    
    @Test func testLoadAIPoweredRecommendationsFixture() async throws {
        let response = try FixtureLoader.loadAIPoweredRecommendations()
        
        #expect(response.success == true)
        #expect(response.message.isEmpty == false)
        #expect(response.recommendations.activities.isEmpty == false)
        
        let firstActivity = response.recommendations.activities.first!
        #expect(firstActivity.id > 0)
        #expect(firstActivity.name.isEmpty == false)
        #expect(firstActivity.description.isEmpty == false)
        #expect(firstActivity.category.isEmpty == false)
    }
    
    @Test func testLoadEventCreateFixture() async throws {
        let event = try FixtureLoader.loadEventCreate()
        
        #expect(event.id > 0)
        #expect(event.userId > 0)
        #expect(event.title.isEmpty == false)
        #expect(event.startTime.isEmpty == false)
        #expect(event.endTime.isEmpty == false)
        #expect(event.eventType.isEmpty == false)
        
        // Validate ISO date formats
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: event.startTime) != nil)
        #expect(formatter.date(from: event.endTime) != nil)
        
        if let createdAt = event.createdAt {
            #expect(formatter.date(from: createdAt) != nil)
        }
    }
    
    @Test func testLoadEventsListFixture() async throws {
        let events = try FixtureLoader.loadEventsList()
        
        #expect(events.isEmpty == false)
        
        let firstEvent = events.first!
        #expect(firstEvent.id > 0)
        #expect(firstEvent.title.isEmpty == false)
        #expect(firstEvent.startTime.isEmpty == false)
        #expect(firstEvent.endTime.isEmpty == false)
    }
    
    @Test func testLoadUserStatsFixture() async throws {
        let stats = try FixtureLoader.loadUserStats()
        
        #expect(stats.eventsCreated >= 0)
        
        if let userId = stats.userId {
            #expect(userId > 0)
        }
        
        if let createdAt = stats.createdAt {
            let formatter = ISO8601DateFormatter()
            #expect(formatter.date(from: createdAt) != nil)
        }
    }
    
    @Test func testLoadCalendarProvidersFixture() async throws {
        let providers = try FixtureLoader.loadCalendarProviders()
        
        #expect(providers.isEmpty == false)
        
        let firstProvider = providers.first!
        #expect(firstProvider.id.isEmpty == false)
        #expect(firstProvider.name.isEmpty == false)
        #expect(firstProvider.displayName.isEmpty == false)
        #expect(firstProvider.icon.isEmpty == false)
        #expect(firstProvider.description.isEmpty == false)
        #expect(firstProvider.status.isEmpty == false)
    }
    
    // MARK: - Preview Data Integration Tests
    
    @Test func testPreviewDataIntegration() async throws {
        #if DEBUG
        // Test that PreviewData can safely load all fixture types
        let user = PreviewData.user
        let activities = PreviewData.activities
        let messages = PreviewData.messages
        let events = PreviewData.calendarEvents
        let recommendations = PreviewData.recommendations
        let providers = PreviewData.calendarProviders
        let stats = PreviewData.userStats
        
        // Verify all preview data is accessible
        #expect(user.id > 0)
        #expect(activities.isEmpty == false)
        #expect(messages.isEmpty == false)
        #expect(events.isEmpty == false)
        #expect(recommendations.isEmpty == false)
        #expect(providers.isEmpty == false)
        #expect(stats.eventsCreated >= 0)
        #endif
    }
    
    // MARK: - Raw Fixture Access Tests
    
    @Test func testRawFixtureDataAccess() async throws {
        // Test direct JSON loading
        let authJSON = try FixtureLoader.loadJSON("Resources/Fixtures/auth/me_success")
        #expect(authJSON["user"] != nil)
        
        let messageJSON = try FixtureLoader.loadJSON("Resources/Fixtures/messages/generate_success")
        #expect(messageJSON["success"] as? Bool == true)
        #expect(messageJSON["messages"] != nil)
        
        let activitiesData = try FixtureLoader.loadData("Resources/Fixtures/activities/list_success")
        #expect(activitiesData.count > 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testFixtureErrorHandling() async throws {
        // Test that non-existent fixtures throw proper errors
        do {
            let _ = try FixtureLoader.load("NonExistentFixture", as: User.self)
            #expect(Bool(false), "Should have thrown an error for non-existent fixture")
        } catch let error as FixtureError {
            #expect(error.localizedDescription.contains("not found"))
        } catch {
            #expect(Bool(false), "Should have thrown FixtureError")
        }
    }
    
    // MARK: - Fixture Completeness Tests
    
    @Test func testAllRequiredFixturesPresent() async throws {
        let requiredFixtures = [
            "Resources/Fixtures/auth/me_success",
            "Resources/Fixtures/messages/generate_success",
            "Resources/Fixtures/activities/list_success",
            "Resources/Fixtures/assessment/save_success",
            "Resources/Fixtures/recommendations/activities_success",
            "Resources/Fixtures/recommendations/location_post_success",
            "Resources/Fixtures/recommendations/categories_success",
            "Resources/Fixtures/recommendations/ai_powered_success",
            "Resources/Fixtures/events/create_success",
            "Resources/Fixtures/events/list_success",
            "Resources/Fixtures/user/stats_success",
            "Resources/Fixtures/calendar/providers_success"
        ]
        
        for fixture in requiredFixtures {
            do {
                let _ = try FixtureLoader.loadData(fixture)
                // If we get here, the fixture exists and is loadable
            } catch {
                #expect(Bool(false), "Required fixture missing or unloadable: \(fixture)")
            }
        }
    }
    
    // MARK: - JSON Value Fixture Tests
    
    @Test func testJSONValueFixtureHandling() async throws {
        let user = try FixtureLoader.loadAuthMe().user
        
        // Test that JSONValue fields can be loaded if present
        if let preferences = user.preferences {
            // Should be able to access JSONValue fields
            #expect(preferences.isEmpty == false)
        }
        
        if let location = user.location {
            #expect(location.isEmpty == false)
        }
    }
}
