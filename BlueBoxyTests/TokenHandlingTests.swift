//
//  TokenHandlingTests.swift
//  BlueBoxyTests
//
//  Tests to ensure proper token storage and authentication header behavior
//  to prevent empty session tokens causing 401 responses after registration
//

import XCTest
@testable import BlueBoxy

final class TokenHandlingTests: XCTestCase {
    
    var sessionStore: SessionStore!
    var mockAPIClient: MockAPIClientForTokens!
    
    override func setUpWithError() throws {
        sessionStore = SessionStore.shared
        mockAPIClient = MockAPIClientForTokens()
        
        // Clear any existing session
        sessionStore.logout()
    }
    
    override func tearDownWithError() throws {
        sessionStore.logout()
        sessionStore = nil
        mockAPIClient = nil
    }
    
    // MARK: - SessionStore Token Handling Tests
    
    func testSessionStoreRejectsEmptyAuthTokens() throws {
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        // Test with empty auth token
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "",
            refreshToken: "valid-refresh-token"
        )
        
        // Session should be invalid due to empty auth token
        XCTAssertFalse(sessionStore.isSessionValid())
        XCTAssertFalse(sessionStore.isAuthenticated)
        XCTAssertNil(sessionStore.authToken) // Should be nil, not empty string
    }
    
    func testSessionStoreRejectsEmptyRefreshTokens() throws {
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        // Test with empty refresh token
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "valid-auth-token",
            refreshToken: ""
        )
        
        // Session should be valid with valid auth token
        XCTAssertTrue(sessionStore.isSessionValid())
        XCTAssertTrue(sessionStore.isAuthenticated)
        XCTAssertEqual(sessionStore.authToken, "valid-auth-token")
        XCTAssertNil(sessionStore.refreshToken) // Should be nil, not empty string
    }
    
    func testSessionStoreAcceptsValidTokens() throws {
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        // Test with valid tokens
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "valid-auth-token",
            refreshToken: "valid-refresh-token"
        )
        
        // Session should be valid
        XCTAssertTrue(sessionStore.isSessionValid())
        XCTAssertTrue(sessionStore.isAuthenticated)
        XCTAssertEqual(sessionStore.authToken, "valid-auth-token")
        XCTAssertEqual(sessionStore.refreshToken, "valid-refresh-token")
    }
    
    func testUpdateTokensRejectsEmptyTokens() throws {
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        // Set up initial valid session
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "initial-token",
            refreshToken: "initial-refresh"
        )
        
        XCTAssertTrue(sessionStore.isSessionValid())
        
        // Update with empty tokens
        sessionStore.updateTokens(authToken: "", refreshToken: "")
        
        // Session should become invalid
        XCTAssertFalse(sessionStore.isSessionValid())
        XCTAssertNil(sessionStore.authToken)
        XCTAssertNil(sessionStore.refreshToken)
    }
    
    // MARK: - APIClient Authentication Header Tests
    
    func testAPIClientRejectsEmptyAuthToken() async throws {
        // Set up session with empty token
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "",
            refreshToken: ""
        )
        
        let endpoint = Endpoint(
            path: "/test",
            method: .GET,
            requiresAuth: true
        )
        
        do {
            let _: Empty = try await mockAPIClient.request(endpoint)
            XCTFail("Expected APIServiceError.missingAuth to be thrown")
        } catch APIServiceError.missingAuth {
            // Expected behavior
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAPIClientAcceptsValidAuthToken() async throws {
        // Set up session with valid token
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date()
        )
        
        sessionStore.setUserSession(
            userId: 1,
            user: mockUser,
            authToken: "valid-token",
            refreshToken: "valid-refresh"
        )
        
        let endpoint = Endpoint(
            path: "/test",
            method: .GET,
            requiresAuth: true
        )
        
        mockAPIClient.mockResponse = Empty()
        
        do {
            let _: Empty = try await mockAPIClient.request(endpoint)
            // Should succeed without throwing
            
            // Verify Authorization header was set correctly
            XCTAssertEqual(mockAPIClient.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid-token")
        } catch {
            XCTFail("Unexpected error with valid token: \(error)")
        }
    }
    
    func testAPIClientSkipsAuthForNonAuthEndpoints() async throws {
        // Set up session with empty token
        sessionStore.setUserSession(
            userId: 1,
            user: User(id: 1, email: "test@example.com", name: "Test", createdAt: Date(), updatedAt: Date(), lastLoginAt: Date()),
            authToken: "",
            refreshToken: ""
        )
        
        let endpoint = Endpoint(
            path: "/public",
            method: .GET,
            requiresAuth: false // No auth required
        )
        
        mockAPIClient.mockResponse = Empty()
        
        do {
            let _: Empty = try await mockAPIClient.request(endpoint)
            // Should succeed since no auth is required
            
            // Verify no Authorization header was set
            XCTAssertNil(mockAPIClient.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        } catch {
            XCTFail("Unexpected error for non-auth endpoint: \(error)")
        }
    }
    
    // MARK: - AuthViewModel Token Handling Tests
    
    func testAuthViewModelUpdateAuthenticationStateWithValidToken() async throws {
        let mockUser = DomainUser(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            partnerName: nil,
            relationshipDuration: nil,
            partnerAge: nil,
            personalityType: nil,
            personalityInsight: nil,
            preferences: nil,
            location: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date(),
            isActive: true,
            subscriptionTier: nil
        )
        
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, sessionStore: sessionStore)
        
        await authViewModel.updateAuthenticationState(
            user: mockUser,
            token: "valid-token",
            refreshToken: "valid-refresh",
            isRegistration: false
        )
        
        XCTAssertTrue(sessionStore.isAuthenticated)
        XCTAssertTrue(authViewModel.isAuthenticated)
        XCTAssertEqual(sessionStore.authToken, "valid-token")
    }
    
    func testAuthViewModelUpdateAuthenticationStateWithEmptyToken() async throws {
        let mockUser = DomainUser(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            partnerName: nil,
            relationshipDuration: nil,
            partnerAge: nil,
            personalityType: nil,
            personalityInsight: nil,
            preferences: nil,
            location: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date(),
            isActive: true,
            subscriptionTier: nil
        )
        
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, sessionStore: sessionStore)
        
        await authViewModel.updateAuthenticationState(
            user: mockUser,
            token: "", // Empty token
            refreshToken: "valid-refresh",
            isRegistration: false
        )
        
        // Should not set session with empty token
        XCTAssertFalse(sessionStore.isAuthenticated)
        XCTAssertFalse(authViewModel.isAuthenticated)
        XCTAssertNil(sessionStore.authToken)
    }
    
    func testAuthViewModelUpdateAuthenticationStateWithNilToken() async throws {
        let mockUser = DomainUser(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            partnerName: nil,
            relationshipDuration: nil,
            partnerAge: nil,
            personalityType: nil,
            personalityInsight: nil,
            preferences: nil,
            location: nil,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: Date(),
            isActive: true,
            subscriptionTier: nil
        )
        
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, sessionStore: sessionStore)
        
        await authViewModel.updateAuthenticationState(
            user: mockUser,
            token: nil, // Nil token
            refreshToken: "valid-refresh",
            isRegistration: false
        )
        
        // Should not set session with nil token
        XCTAssertFalse(sessionStore.isAuthenticated)
        XCTAssertFalse(authViewModel.isAuthenticated)
        XCTAssertNil(sessionStore.authToken)
    }
}

// MARK: - Mock API Client for Token Testing

class MockAPIClientForTokens: APIClient {
    var mockResponse: Any?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    override func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Build a sample request to capture authentication headers
        let mockURL = URL(string: "https://api.example.com\(endpoint.path)")!
        var request = URLRequest(url: mockURL)
        request.httpMethod = endpoint.method.rawValue
        
        // Apply the same authentication logic as the real client
        try addAuthentication(to: &request, endpoint: endpoint)
        
        // Store the request for testing
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw APIServiceError.decodingError(NSError(domain: "MockError", code: 0))
        }
        
        return response
    }
    
    // Expose the private method for testing
    func addAuthentication(to request: inout URLRequest, endpoint: Endpoint) throws {
        let auth = SessionAuthProvider()
        
        if endpoint.requiresAuth {
            guard let token = auth.authToken, !token.isEmpty else {
                throw APIServiceError.missingAuth
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if endpoint.requiresUser {
            guard let userId = auth.userId else {
                throw APIServiceError.missingAuth
            }
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")
        }
    }
}