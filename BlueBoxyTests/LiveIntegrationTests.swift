//
//  LiveIntegrationTests.swift
//  BlueBoxyTests
//
//  Live integration tests against actual backend (opt-in only)
//  Run with LIVE_API=1 environment variable when backend is running
//

import Testing
import Foundation
@testable import BlueBoxy

struct LiveIntegrationTests {
    
    /// Check if live API testing is enabled via environment variable
    private var isLiveAPIEnabled: Bool {
        ProcessInfo.processInfo.environment["LIVE_API"] == "1"
    }
    
    /// Check if backend URL is properly configured for live testing
    private var hasLiveBackendURL: Bool {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String else {
            return false
        }
        // Assume live testing uses localhost or specific test domain
        return baseURL.contains("127.0.0.1") || 
               baseURL.contains("localhost") || 
               baseURL.contains("staging") ||
               baseURL.contains("test")
    }
    
    // MARK: - Public Endpoint Tests (No Auth Required)
    
    @Test func testLiveActivitiesList() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        let response: ActivitiesResponse = try await APIClient.shared.request(
            Endpoint.activitiesList()
        )
        
        #expect(!response.activities.isEmpty)
        
        // Validate structure of live data
        let firstActivity = response.activities.first!
        #expect(firstActivity.id > 0)
        #expect(!firstActivity.name.isEmpty)
        #expect(!firstActivity.description.isEmpty)
        #expect(!firstActivity.category.isEmpty)
        
        print("✅ Live test: Successfully loaded \(response.activities.count) activities")
    }
    
    @Test func testLiveActivitiesDetail() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        // First get activities list to get a valid ID
        let activitiesResponse: ActivitiesResponse = try await APIClient.shared.request(
            Endpoint.activitiesList()
        )
        
        guard let firstActivity = activitiesResponse.activities.first else {
            throw LiveTestError.noTestData("No activities available for detail test")
        }
        
        let activity: Activity = try await APIClient.shared.request(
            Endpoint.activitiesDetail(id: firstActivity.id)
        )
        
        #expect(activity.id == firstActivity.id)
        #expect(!activity.name.isEmpty)
        
        print("✅ Live test: Successfully loaded activity detail for ID \(activity.id)")
    }
    
    // MARK: - Guest Assessment Tests (No Auth Required)
    
    @Test func testLiveGuestAssessment() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        let testResponses = [
            "communication_style": "direct",
            "conflict_resolution": "collaborative",
            "love_language": "quality_time",
            "social_preference": "small_groups"
        ]
        
        let request = GuestAssessmentRequest(
            responses: testResponses,
            personalityType: "Test Personality",
            onboardingData: JSONValue.object([
                "source": JSONValue.string("live_test"),
                "timestamp": JSONValue.int(Int(Date().timeIntervalSince1970))
            ])
        )
        
        let result: AssessmentResult = try await APIClient.shared.request(
            Endpoint.assessmentGuest(request)
        )
        
        #expect(!result.personalityType.isEmpty)
        #expect(!result.responses.isEmpty)
        
        print("✅ Live test: Successfully submitted guest assessment, got personality: \(result.personalityType)")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testLiveUnauthorizedEndpoint() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        // Try to access authenticated endpoint without auth
        do {
            let _: User = try await APIClient.shared.request(Endpoint.authMe())
            #expect(Bool(false), "Expected unauthorized error")
        } catch let error as APIServiceError {
            switch error {
            case .unauthorized:
                print("✅ Live test: Correctly received unauthorized error")
            case .missingAuth:
                print("✅ Live test: Correctly received missing auth error")
            default:
                throw LiveTestError.unexpectedError("Expected unauthorized error, got \(error)")
            }
        }
    }
    
    @Test func testLiveNotFoundEndpoint() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        // Try to access non-existent endpoint
        let invalidEndpoint = Endpoint(
            path: "/api/nonexistent/endpoint",
            method: .GET
        )
        
        do {
            let _: [String: Any] = try await APIClient.shared.request(invalidEndpoint)
            #expect(Bool(false), "Expected not found error")
        } catch let error as APIServiceError {
            switch error {
            case .notFound:
                print("✅ Live test: Correctly received not found error")
            case .unknown(let status) where status == 404:
                print("✅ Live test: Correctly received 404 error")
            default:
                throw LiveTestError.unexpectedError("Expected not found error, got \(error)")
            }
        }
    }
    
    // MARK: - Network Performance Tests
    
    @Test func testLiveResponseTimes() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        let endpoints: [(String, Endpoint)] = [
            ("activities", Endpoint.activitiesList()),
        ]
        
        for (name, endpoint) in endpoints {
            let startTime = Date()
            
            do {
                let _: ActivitiesResponse = try await APIClient.shared.request(endpoint)
                let duration = Date().timeIntervalSince(startTime)
                
                // Response should be reasonably fast (< 5 seconds)
                #expect(duration < 5.0, "Response time for \(name) too slow: \(duration)s")
                
                print("✅ Live test: \(name) responded in \(String(format: "%.2f", duration))s")
            } catch {
                throw LiveTestError.performanceTest("Failed to measure \(name) performance: \(error)")
            }
        }
    }
    
    // MARK: - Connection and Configuration Tests
    
    @Test func testLiveServerConnectivity() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        // Simple connectivity test - try to reach any public endpoint
        let startTime = Date()
        
        do {
            let _: ActivitiesResponse = try await APIClient.shared.request(Endpoint.activitiesList())
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ Live test: Server connectivity confirmed in \(String(format: "%.2f", duration))s")
        } catch let error as APIServiceError {
            switch error {
            case .network(let networkError):
                if let urlError = networkError as? URLError {
                    switch urlError.code {
                    case .cannotConnectToHost, .cannotFindHost:
                        throw LiveTestError.connectivity("Cannot connect to server - is it running?")
                    case .timedOut:
                        throw LiveTestError.connectivity("Server connection timed out")
                    default:
                        throw LiveTestError.connectivity("Network error: \(urlError.localizedDescription)")
                    }
                }
                throw LiveTestError.connectivity("Network error: \(networkError.localizedDescription)")
            default:
                // Other errors might be expected (like auth errors), so server is responsive
                print("✅ Live test: Server is responsive (received \(error))")
            }
        }
    }
    
    @Test func testLiveAPIConfiguration() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        
        // Validate API configuration for live testing
        let baseURL = APIConfiguration.baseURL
        let baseURLString = baseURL.absoluteString
        
        print("🔍 Live test: Using base URL: \(baseURLString)")
        
        // Ensure we're not accidentally testing against production
        let isDevelopmentURL = baseURLString.contains("localhost") ||
                              baseURLString.contains("127.0.0.1") ||
                              baseURLString.contains("staging") ||
                              baseURLString.contains("test") ||
                              baseURLString.contains("dev")
        
        #expect(isDevelopmentURL, "Live tests should only run against development/staging URLs")
        
        print("✅ Live test: API configuration validated for testing")
    }
    
    // MARK: - Data Consistency Tests
    
    @Test func testLiveDataConsistency() async throws {
        try #require(isLiveAPIEnabled, "Set LIVE_API=1 environment variable to enable live tests")
        try #require(hasLiveBackendURL, "Configure BASE_URL for live testing")
        
        // Test that the same endpoint returns consistent data structure
        let firstResponse: ActivitiesResponse = try await APIClient.shared.request(Endpoint.activitiesList())
        
        // Small delay to avoid rate limiting
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let secondResponse: ActivitiesResponse = try await APIClient.shared.request(Endpoint.activitiesList())
        
        // Data structure should be consistent
        #expect(type(of: firstResponse) == type(of: secondResponse))
        
        // If there are activities, they should have consistent structure
        if let firstActivity = firstResponse.activities.first,
           let secondActivity = secondResponse.activities.first(where: { $0.id == firstActivity.id }) {
            #expect(firstActivity.name == secondActivity.name)
            #expect(firstActivity.category == secondActivity.category)
        }
        
        print("✅ Live test: Data consistency validated across requests")
    }
}

// MARK: - Live Test Errors

enum LiveTestError: Error, LocalizedError {
    case noTestData(String)
    case unexpectedError(String)
    case connectivity(String)
    case performanceTest(String)
    
    var errorDescription: String? {
        switch self {
        case .noTestData(let message):
            return "No test data available: \(message)"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        case .connectivity(let message):
            return "Connectivity issue: \(message)"
        case .performanceTest(let message):
            return "Performance test failed: \(message)"
        }
    }
}

// MARK: - Live Test Helpers

extension LiveIntegrationTests {
    
    /// Print live test configuration info
    private func printTestConfiguration() {
        print("🧪 Live Integration Test Configuration:")
        print("   Base URL: \(APIConfiguration.baseURL)")
        print("   LIVE_API: \(ProcessInfo.processInfo.environment["LIVE_API"] ?? "not set")")
        
        #if DEBUG
        APIConfiguration.validateConfiguration()
        #endif
    }
    
    /// Validate that we have a reasonable test environment
    private func validateTestEnvironment() throws {
        guard isLiveAPIEnabled else {
            throw LiveTestError.unexpectedError("LIVE_API environment variable not set")
        }
        
        guard hasLiveBackendURL else {
            throw LiveTestError.unexpectedError("BASE_URL not configured for testing")
        }
        
        // Additional safety checks
        let baseURLString = APIConfiguration.baseURL.absoluteString.lowercased()
        
        let dangerousPatterns = ["production", "prod", "api.blueboxy.com"]
        for pattern in dangerousPatterns {
            if baseURLString.contains(pattern) {
                throw LiveTestError.unexpectedError("Refusing to run live tests against production-like URL")
            }
        }
    }
}

// MARK: - Test Setup and Teardown

extension LiveIntegrationTests {
    
    /// Setup method to run before live tests
    init() throws {
        if isLiveAPIEnabled {
            printTestConfiguration()
            try validateTestEnvironment()
            print("✅ Live test environment validated")
        }
    }
}