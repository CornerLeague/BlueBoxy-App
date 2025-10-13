//
//  APIClientTests.swift
//  BlueBoxyTests
//
//  Comprehensive tests for API client behavior with mock networking
//  Tests endpoint construction, headers, auth, error mapping, and responses
//

import Testing
import Foundation
@testable import BlueBoxy

struct APIClientTests {
    
    // MARK: - Test Setup Helpers
    
    /// Create API client with mock session and custom auth provider
    private func makeTestClient(userId: Int? = 123, authToken: String? = "test-token") -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        struct MockAuth: AuthProviding {
            let userId: Int?
            let authToken: String?
        }
        
        let auth = MockAuth(userId: userId, authToken: authToken)
        
        return APIClient(
            baseURL: URL(string: "https://api.blueboxy.test")!,
            session: session,
            decoder: APIConfiguration.decoder,
            encoder: APIConfiguration.encoder,
            auth: auth
        )
    }
    
    /// Reset mock state before each test
    init() {
        MockURLProtocol.reset()
    }
    
    // MARK: - Authentication Header Tests
    
    @Test func testUserHeaderInjection() async throws {
        let client = makeTestClient(userId: 99)
        let endpoint = Endpoint.userProfile()
        
        MockURLProtocol.handler = MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/user/profile",
            fixtureName: "auth/me_success",
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateMethod(.GET),
                MockURLProtocol.validatePath("/api/user/profile"),
                MockURLProtocol.validateHeader("X-User-ID", expectedValue: "99")
            )
        )
        
        let _: User = try await client.request(endpoint)
        
        #expect(MockURLProtocol.requestCount == 1)
        #expect(MockURLProtocol.hasRequest(to: "/api/user/profile"))
    }
    
    @Test func testAuthTokenInjection() async throws {
        let client = makeTestClient(authToken: "bearer-token-123")
        let endpoint = Endpoint.authMe()
        
        MockURLProtocol.handler = MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/auth/me",
            fixtureName: "auth/me_success",
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateMethod(.GET),
                MockURLProtocol.validatePath("/api/auth/me"),
                MockURLProtocol.validateHeader("Authorization", expectedValue: "Bearer bearer-token-123")
            )
        )
        
        let _: User = try await client.request(endpoint)
        
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    @Test func testMissingAuthThrowsError() async throws {
        let client = makeTestClient(userId: nil, authToken: nil)
        let endpoint = Endpoint.userProfile() // Requires user
        
        #expect(throws: APIServiceError.self) {
            let _: User = try await client.request(endpoint)
        }
    }
    
    // MARK: - HTTP Method and Body Tests
    
    @Test func testPOSTWithBody() async throws {
        let client = makeTestClient(userId: 123)
        let messageRequest = MessageGenerateRequest(
            category: "appreciation",
            timeOfDay: .evening,
            recentContext: "Had dinner together",
            specialOccasion: nil
        )
        let endpoint = Endpoint.messagesGenerate(messageRequest)
        
        MockURLProtocol.handler = MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/messages/generate",
            fixtureName: "messages/generate_success",
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateMethod(.POST),
                MockURLProtocol.validatePath("/api/messages/generate"),
                MockURLProtocol.validateHeader("X-User-ID", expectedValue: "123"),
                MockURLProtocol.validateBodyContains("\"category\":\"appreciation\""),
                MockURLProtocol.validateBodyContains("\"timeOfDay\":\"evening\""),
                MockURLProtocol.validateJSONBody(MessageGenerateRequest.self)
            )
        )
        
        let response: MessageGenerationResponse = try await client.request(endpoint)
        
        #expect(response.success)
        #expect(!response.messages.isEmpty)
    }
    
    @Test func testGETWithQueryParameters() async throws {
        let client = makeTestClient(userId: 123)
        let endpoint = Endpoint.messagesHistory(limit: 25, offset: 50)
        
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/messages/history",
            data: try FixtureLoader.loadRaw("messages/generate_success"),
            requestValidator: { request in
                #expect(request.httpMethod == "GET")
                #expect(request.url?.path.hasSuffix("/api/messages/history") == true)
                
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                
                let limitItem = queryItems.first { $0.name == "limit" }
                let offsetItem = queryItems.first { $0.name == "offset" }
                
                #expect(limitItem?.value == "25")
                #expect(offsetItem?.value == "50")
            }
        )
        
        let _: MessageGenerationResponse = try await client.request(endpoint)
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    @Test func testDELETERequest() async throws {
        let client = makeTestClient(userId: 123)
        let endpoint = Endpoint.eventsDelete(id: 456)
        
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/events/456",
            statusCode: 204,
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateMethod(.DELETE),
                MockURLProtocol.validatePath("/api/events/456"),
                MockURLProtocol.validateHeader("X-User-ID", expectedValue: "123")
            )
        )
        
        try await client.requestEmpty(endpoint)
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testUnauthorizedErrorMapping() async throws {
        let client = makeTestClient(userId: 123)
        let endpoint = Endpoint.authMe()
        
        MockURLProtocol.handler = MockURLProtocol.unauthorizedHandler(
            for: "https://api.blueboxy.test/api/auth/me"
        )
        
        do {
            let _: User = try await client.request(endpoint)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as APIServiceError {
            switch error {
            case .unauthorized:
                break // Expected
            default:
                #expect(Bool(false), "Expected unauthorized error, got \(error)")
            }
        }
    }
    
    @Test func testServerErrorMapping() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        MockURLProtocol.handler = MockURLProtocol.serverErrorHandler(
            for: "https://api.blueboxy.test/api/activities",
            message: "Database connection failed"
        )
        
        do {
            let _: ActivitiesResponse = try await client.request(endpoint)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as APIServiceError {
            switch error {
            case .server(let message):
                #expect(message == "Database connection failed")
            default:
                #expect(Bool(false), "Expected server error, got \(error)")
            }
        }
    }
    
    @Test func testNetworkErrorMapping() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        let networkError = URLError(.notConnectedToInternet)
        MockURLProtocol.handler = MockURLProtocol.networkErrorHandler(error: networkError)
        
        do {
            let _: ActivitiesResponse = try await client.request(endpoint)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as APIServiceError {
            switch error {
            case .network(let wrappedError):
                #expect(wrappedError is URLError)
            default:
                #expect(Bool(false), "Expected network error, got \(error)")
            }
        }
    }
    
    @Test func testRateLimitErrorMapping() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.messagesGenerate(MessageGenerateRequest(category: "test"))
        
        MockURLProtocol.handler = MockURLProtocol.rateLimitedHandler(
            for: "https://api.blueboxy.test/api/messages/generate"
        )
        
        do {
            let _: MessageGenerationResponse = try await client.request(endpoint)
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as APIServiceError {
            switch error {
            case .unknown(let status):
                #expect(status == 429)
            default:
                #expect(Bool(false), "Expected 429 status error, got \(error)")
            }
        }
    }
    
    // MARK: - Response Decoding Tests
    
    @Test func testSuccessfulJSONDecoding() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        MockURLProtocol.handler = try MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/activities",
            fixtureName: "activities/list_success"
        )
        
        let response: ActivitiesResponse = try await client.request(endpoint)
        
        #expect(!response.activities.isEmpty)
        
        let firstActivity = response.activities.first!
        #expect(firstActivity.id > 0)
        #expect(!firstActivity.name.isEmpty)
        #expect(!firstActivity.category.isEmpty)
    }
    
    @Test func testInvalidJSONDecodingError() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        let invalidJSON = "{ invalid json }"
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/activities",
            data: invalidJSON.data(using: .utf8)!
        )
        
        do {
            let _: ActivitiesResponse = try await client.request(endpoint)
            #expect(Bool(false), "Expected decoding error")
        } catch let error as APIServiceError {
            switch error {
            case .decoding:
                break // Expected
            default:
                #expect(Bool(false), "Expected decoding error, got \(error)")
            }
        }
    }
    
    // MARK: - Endpoint Construction Tests
    
    @Test func testEndpointPathConstruction() async throws {
        let client = makeTestClient(userId: 123)
        
        // Test various endpoint constructions
        let endpoints: [(Endpoint, String)] = [
            (Endpoint.activitiesList(), "/api/activities"),
            (Endpoint.authMe(), "/api/auth/me"),
            (Endpoint.eventsDetail(id: 789), "/api/events/789"),
            (Endpoint.userStats(), "/api/user/stats/0"),
            (Endpoint.calendarConnect(providerId: "google"), "/api/calendar/connect/google")
        ]
        
        for (endpoint, expectedPath) in endpoints {
            MockURLProtocol.reset()
            MockURLProtocol.handler = MockURLProtocol.successHandler(
                for: "https://api.blueboxy.test\(expectedPath)",
                data: "{}".data(using: .utf8)!,
                requestValidator: MockURLProtocol.validatePath(expectedPath)
            )
            
            // Make request and verify path construction
            do {
                let _: [String: Any] = try await client.request(endpoint)
            } catch {
                // We don't care about decoding errors here, just path construction
                if error is APIServiceError {
                    switch error as! APIServiceError {
                    case .decoding:
                        break // Expected for generic [String: Any]
                    default:
                        throw error
                    }
                }
            }
            
            #expect(MockURLProtocol.hasRequest(to: expectedPath))
        }
    }
    
    // MARK: - Default Headers Tests
    
    @Test func testDefaultHeaders() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/activities",
            data: "{}".data(using: .utf8)!,
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateHeader("Content-Type", expectedValue: "application/json"),
                MockURLProtocol.validateHeader("Accept", expectedValue: "application/json"),
                { request in
                    let userAgent = request.value(forHTTPHeaderField: "User-Agent")
                    #expect(userAgent?.contains("BlueBoxy iOS") == true)
                }
            )
        )
        
        // This will fail decoding but we only care about headers
        do {
            let _: [String: Any] = try await client.request(endpoint)
        } catch {
            // Expected decoding error
        }
        
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    // MARK: - Custom Headers Tests
    
    @Test func testCustomEndpointHeaders() async throws {
        let client = makeTestClient()
        let customHeaders = ["X-Custom-Header": "custom-value"]
        let endpoint = Endpoint.withHeaders(
            Endpoint.activitiesList(),
            headers: customHeaders
        )
        
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/activities",
            data: "{}".data(using: .utf8)!,
            requestValidator: MockURLProtocol.validateHeader("X-Custom-Header", expectedValue: "custom-value")
        )
        
        do {
            let _: [String: Any] = try await client.request(endpoint)
        } catch {
            // Expected decoding error
        }
        
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    // MARK: - Empty Response Tests
    
    @Test func testEmptyResponseHandling() async throws {
        let client = makeTestClient(userId: 123)
        let endpoint = Endpoint.eventsDelete(id: 456)
        
        MockURLProtocol.handler = MockURLProtocol.successHandler(
            for: "https://api.blueboxy.test/api/events/456",
            statusCode: 204 // No content
        )
        
        // Should not throw for empty response
        try await client.requestEmpty(endpoint)
        #expect(MockURLProtocol.requestCount == 1)
    }
    
    // MARK: - Complex Request Tests
    
    @Test func testComplexEventCreation() async throws {
        let client = makeTestClient(userId: 123)
        
        let eventRequest = CreateEventRequest(
            title: "Date Night",
            description: "Romantic dinner at new restaurant",
            location: "Downtown Bistro",
            startTime: Date(),
            endTime: Date().addingTimeInterval(7200), // 2 hours
            allDay: false,
            eventType: "date",
            status: "confirmed",
            externalEventId: nil,
            calendarProvider: "google",
            reminders: JSONValue.array([
                JSONValue.string("15 minutes before"),
                JSONValue.string("1 hour before")
            ]),
            metadata: JSONValue.object([
                "source": JSONValue.string("app"),
                "priority": JSONValue.string("high")
            ])
        )
        
        let endpoint = Endpoint.eventsCreate(eventRequest)
        
        MockURLProtocol.handler = try MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/events",
            fixtureName: "events/create_success",
            requestValidator: MockURLProtocol.validateAll(
                MockURLProtocol.validateMethod(.POST),
                MockURLProtocol.validatePath("/api/events"),
                MockURLProtocol.validateHeader("X-User-ID", expectedValue: "123"),
                MockURLProtocol.validateBodyContains("\"title\":\"Date Night\""),
                MockURLProtocol.validateBodyContains("\"eventType\":\"date\""),
                MockURLProtocol.validateJSONBody(CreateEventRequest.self)
            )
        )
        
        let createdEvent: Event = try await client.request(endpoint)
        
        #expect(createdEvent.id > 0)
        #expect(createdEvent.title == "Date Night")
    }
    
    // MARK: - Performance Tests
    
    @Test func testRequestPerformance() async throws {
        let client = makeTestClient()
        let endpoint = Endpoint.activitiesList()
        
        MockURLProtocol.handler = try MockURLProtocol.fixtureHandler(
            for: "https://api.blueboxy.test/api/activities",
            fixtureName: "activities/list_success"
        )
        
        let startTime = Date()
        
        // Make multiple concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let _: ActivitiesResponse = try await client.request(endpoint)
                    } catch {
                        // Ignore errors for performance test
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Should complete 10 requests in reasonable time
        #expect(duration < 1.0) // Less than 1 second
        #expect(MockURLProtocol.requestCount == 10)
    }
}

// MARK: - Test Helper Extensions

extension APIClientTests {
    
    /// Helper to create a mock location payload
    private func createMockLocation() -> GeoLocationPayload {
        return GeoLocationPayload(latitude: 37.7749, longitude: -122.4194)
    }
    
    /// Helper to create a mock preferences dictionary
    private func createMockPreferences() -> [String: JSONValue] {
        return [
            "budget": JSONValue.string("medium"),
            "atmosphere": JSONValue.string("romantic"),
            "distance": JSONValue.int(5)
        ]
    }
}