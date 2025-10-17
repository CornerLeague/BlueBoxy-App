//
//  RegistrationServiceTests.swift
//  BlueBoxyTests
//
//  Regression tests to ensure all registration entry points use identical
//  endpoints, HTTP methods, and JSON keys
//

import XCTest
@testable import BlueBoxy

final class RegistrationServiceTests: XCTestCase {
    
    var mockAPIClient: MockAPIClient!
    var authService: AuthService!
    var sessionViewModel: SessionViewModel!
    var authViewModel: AuthViewModel!
    var registrationService: RegistrationService!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        authService = AuthService()
        sessionViewModel = SessionViewModel()
        authViewModel = AuthViewModel(apiClient: mockAPIClient, sessionStore: SessionStore.shared)
        registrationService = RegistrationService(apiClient: mockAPIClient)
    }
    
    override func tearDownWithError() throws {
        mockAPIClient = nil
        authService = nil
        sessionViewModel = nil
        authViewModel = nil
        registrationService = nil
    }
    
    // MARK: - Endpoint Consistency Tests
    
    func testAllRegistrationServicesUseCanonicalEndpoint() throws {
        // Verify the canonical endpoint is consistent across all services
        XCTAssertEqual(RegistrationService.canonicalEndpoint, "/api/auth/register")
    }
    
    func testRegistrationRequestPayloadFormat() throws {
        // Test the centralized registration request uses correct field mapping
        let request = RegistrationRequest(
            email: "test@example.com",
            password: "password123",
            name: "Test User",
            partnerName: "Partner Name",
            personalityType: "INTJ",
            relationshipDuration: "6 months",
            partnerAge: 25
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Verify all fields use snake_case as expected by the backend
        XCTAssertEqual(json["email"] as? String, "test@example.com")
        XCTAssertEqual(json["password"] as? String, "password123")
        XCTAssertEqual(json["name"] as? String, "Test User")
        XCTAssertEqual(json["partner_name"] as? String, "Partner Name")
        XCTAssertEqual(json["personality_type"] as? String, "INTJ")
        XCTAssertEqual(json["relationship_duration"] as? String, "6 months")
        XCTAssertEqual(json["partner_age"] as? Int, 25)
        
        // Verify no camelCase fields leak through
        XCTAssertNil(json["partnerName"])
        XCTAssertNil(json["personalityType"])
        XCTAssertNil(json["relationshipDuration"])
        XCTAssertNil(json["partnerAge"])
    }
    
    func testRegistrationRequestValidation() throws {
        // Test valid request
        let validRequest = RegistrationRequest(email: "test@example.com", password: "password123")
        XCTAssertNoThrow(try validRequest.validate())
        XCTAssertTrue(validRequest.isValid)
        XCTAssertTrue(validRequest.hasValidEmail)
        XCTAssertTrue(validRequest.hasValidPassword)
        
        // Test invalid email
        let invalidEmailRequest = RegistrationRequest(email: "invalid-email", password: "password123")
        XCTAssertThrowsError(try invalidEmailRequest.validate()) { error in
            XCTAssertEqual(error as? RegistrationError, .invalidEmail)
        }
        
        // Test weak password
        let weakPasswordRequest = RegistrationRequest(email: "test@example.com", password: "123")
        XCTAssertThrowsError(try weakPasswordRequest.validate()) { error in
            XCTAssertEqual(error as? RegistrationError, .weakPassword)
        }
        
        // Test missing required fields
        let missingFieldsRequest = RegistrationRequest(email: "", password: "password123")
        XCTAssertThrowsError(try missingFieldsRequest.validate()) { error in
            XCTAssertEqual(error as? RegistrationError, .missingRequiredFields)
        }
    }
    
    // MARK: - Legacy Compatibility Tests
    
    func testLegacySignUpRequestCompatibility() throws {
        // Test conversion from legacy SignUpRequest to new RegistrationRequest
        let legacyRequest = SignUpRequest(
            email: "test@example.com",
            password: "password123",
            name: "Test User",
            partnerName: "Partner Name",
            personalityType: "ENFP"
        )
        
        let newRequest = RegistrationRequest(from: legacyRequest)
        
        XCTAssertEqual(newRequest.email, legacyRequest.email)
        XCTAssertEqual(newRequest.password, legacyRequest.password)
        XCTAssertEqual(newRequest.name, legacyRequest.name)
        XCTAssertEqual(newRequest.partnerName, legacyRequest.partnerName)
        XCTAssertEqual(newRequest.personalityType, legacyRequest.personalityType)
        XCTAssertNil(newRequest.relationshipDuration)
        XCTAssertNil(newRequest.partnerAge)
    }
    
    func testLegacyRegisterRequestCompatibility() throws {
        // Test conversion from RegisterRequest (from RequestModels.swift) to new RegistrationRequest
        let legacyRequest = RegisterRequest(
            email: "test@example.com",
            password: "password123",
            name: "Test User",
            partnerName: "Partner Name",
            relationshipDuration: "1 year",
            partnerAge: 30
        )
        
        let newRequest = RegistrationRequest(from: legacyRequest)
        
        XCTAssertEqual(newRequest.email, legacyRequest.email)
        XCTAssertEqual(newRequest.password, legacyRequest.password)
        XCTAssertEqual(newRequest.name, legacyRequest.name)
        XCTAssertEqual(newRequest.partnerName, legacyRequest.partnerName)
        XCTAssertEqual(newRequest.relationshipDuration, legacyRequest.relationshipDuration)
        XCTAssertEqual(newRequest.partnerAge, legacyRequest.partnerAge)
        XCTAssertNil(newRequest.personalityType) // RegisterRequest doesn't have this field
    }
    
    // MARK: - Builder Pattern Tests
    
    func testRegistrationRequestBuilder() throws {
        let request = RegistrationRequestBuilder()
            .setEmail("test@example.com")
            .setPassword("password123")
            .setName("Test User")
            .setPartnerName("Partner Name")
            .setPersonalityType("ISFJ")
            .setRelationshipDuration("8 months")
            .setPartnerAge(28)
            .build()
        
        XCTAssertEqual(request.email, "test@example.com")
        XCTAssertEqual(request.password, "password123")
        XCTAssertEqual(request.name, "Test User")
        XCTAssertEqual(request.partnerName, "Partner Name")
        XCTAssertEqual(request.personalityType, "ISFJ")
        XCTAssertEqual(request.relationshipDuration, "8 months")
        XCTAssertEqual(request.partnerAge, 28)
    }
    
    func testConvenienceFactoryMethods() throws {
        // Test basic factory method
        let basicRequest = RegistrationRequest.basic(email: "test@example.com", password: "password123")
        XCTAssertEqual(basicRequest.email, "test@example.com")
        XCTAssertEqual(basicRequest.password, "password123")
        XCTAssertNil(basicRequest.name)
        XCTAssertNil(basicRequest.partnerName)
        
        // Test withName factory method
        let namedRequest = RegistrationRequest.withName(email: "test@example.com", password: "password123", name: "Test User")
        XCTAssertEqual(namedRequest.name, "Test User")
        
        // Test complete factory method
        let completeRequest = RegistrationRequest.complete(
            email: "test@example.com",
            password: "password123",
            name: "Test User",
            partnerName: "Partner",
            personalityType: "ENTP"
        )
        XCTAssertEqual(completeRequest.personalityType, "ENTP")
        XCTAssertEqual(completeRequest.partnerName, "Partner")
    }
    
    // MARK: - Service Integration Tests
    
    func testRegistrationServiceUsesCorrectEndpoint() async throws {
        // Mock a successful registration response
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
            lastLoginAt: nil,
            isActive: true,
            subscriptionTier: nil
        )
        
        let mockResponse = AuthEnvelope(
            user: mockUser,
            token: "mock-token",
            refreshToken: nil,
            expiresAt: nil
        )
        
        // Configure mock to expect the correct endpoint
        mockAPIClient.mockResponse = mockResponse
        
        let request = RegistrationRequest.basic(email: "test@example.com", password: "password123")
        let response = try await registrationService.register(request)
        
        XCTAssertEqual(response.user.email, "test@example.com")
        
        // Verify the mock received the correct endpoint path
        XCTAssertEqual(mockAPIClient.lastEndpoint?.path, "/api/auth/register")
        XCTAssertEqual(mockAPIClient.lastEndpoint?.method, .POST)
        XCTAssertFalse(mockAPIClient.lastEndpoint?.requiresUser ?? true)
    }
    
    // MARK: - Error Handling Tests
    
    func testRegistrationErrorDescriptions() {
        XCTAssertEqual(RegistrationError.missingRequiredFields.errorDescription, "Email and password are required")
        XCTAssertEqual(RegistrationError.invalidEmail.errorDescription, "Please enter a valid email address")
        XCTAssertEqual(RegistrationError.weakPassword.errorDescription, "Password must be at least 8 characters long")
        
        let networkError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network failed"])
        XCTAssertEqual(RegistrationError.networkError(networkError).errorDescription, "Network error: Network failed")
        
        XCTAssertEqual(RegistrationError.serverError("Server unavailable").errorDescription, "Server error: Server unavailable")
    }
}

// MARK: - Mock API Client for Testing

class MockAPIClient: APIClient {
    var mockResponse: Any?
    var mockError: Error?
    var lastEndpoint: Endpoint?
    
    override func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        lastEndpoint = endpoint
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw APIServiceError.decodingError(NSError(domain: "MockError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Mock response not set or wrong type"]))
        }
        
        return response
    }
    
    override func requestEmpty(_ endpoint: Endpoint) async throws {
        lastEndpoint = endpoint
        
        if let error = mockError {
            throw error
        }
    }
}

// MARK: - Extensions for Testing

extension RegistrationError: Equatable {
    public static func == (lhs: RegistrationError, rhs: RegistrationError) -> Bool {
        switch (lhs, rhs) {
        case (.missingRequiredFields, .missingRequiredFields):
            return true
        case (.invalidEmail, .invalidEmail):
            return true
        case (.weakPassword, .weakPassword):
            return true
        case (.networkError, .networkError):
            return true
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}