//
//  RegistrationDTO.swift
//  BlueBoxy
//
//  Centralized registration request builder to consolidate different registration endpoints
//  and ensure consistent payload formats across the app
//

import Foundation

// MARK: - Centralized Registration Request

/// Centralized registration request model that handles all registration scenarios
/// Uses snake_case field mapping consistent with SessionViewModel.register
struct RegistrationRequest: Encodable {
    let email: String
    let password: String
    let name: String?
    let partnerName: String?
    let personalityType: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name
        case partnerName = "partner_name"
        case personalityType = "personality_type" 
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
    }
    
    init(
        email: String,
        password: String,
        name: String? = nil,
        partnerName: String? = nil,
        personalityType: String? = nil,
        relationshipDuration: String? = nil,
        partnerAge: Int? = nil
    ) {
        self.email = email
        self.password = password
        self.name = name
        self.partnerName = partnerName
        self.personalityType = personalityType
        self.relationshipDuration = relationshipDuration
        self.partnerAge = partnerAge
    }
}

// MARK: - Registration Request Builder

/// Builder class for creating consistent registration requests
final class RegistrationRequestBuilder {
    private var email: String = ""
    private var password: String = ""
    private var name: String?
    private var partnerName: String?
    private var personalityType: String?
    private var relationshipDuration: String?
    private var partnerAge: Int?
    
    @discardableResult
    func setEmail(_ email: String) -> Self {
        self.email = email
        return self
    }
    
    @discardableResult
    func setPassword(_ password: String) -> Self {
        self.password = password
        return self
    }
    
    @discardableResult
    func setName(_ name: String?) -> Self {
        self.name = name
        return self
    }
    
    @discardableResult
    func setPartnerName(_ partnerName: String?) -> Self {
        self.partnerName = partnerName
        return self
    }
    
    @discardableResult
    func setPersonalityType(_ personalityType: String?) -> Self {
        self.personalityType = personalityType
        return self
    }
    
    @discardableResult
    func setRelationshipDuration(_ relationshipDuration: String?) -> Self {
        self.relationshipDuration = relationshipDuration
        return self
    }
    
    @discardableResult
    func setPartnerAge(_ partnerAge: Int?) -> Self {
        self.partnerAge = partnerAge
        return self
    }
    
    /// Build the final registration request
    func build() -> RegistrationRequest {
        return RegistrationRequest(
            email: email,
            password: password,
            name: name,
            partnerName: partnerName,
            personalityType: personalityType,
            relationshipDuration: relationshipDuration,
            partnerAge: partnerAge
        )
    }
}

// MARK: - Registration Service

/// Centralized registration service that all parts of the app should use
struct RegistrationService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    /// The canonical registration endpoint - all registration should use this
    static let canonicalEndpoint = "/api/auth/register"
    
    /// Perform registration using the canonical endpoint and payload format
    func register(_ request: RegistrationRequest) async throws -> AuthEnvelope {
        let endpoint = Endpoint(
            path: Self.canonicalEndpoint,
            method: .POST,
            body: request,
            requiresUser: false
        )
        
        return try await apiClient.request(endpoint)
    }
}

// MARK: - Validation Extensions

extension RegistrationRequest {
    /// Validates that the registration request has required fields
    var isValid: Bool {
        return !email.isEmpty && !password.isEmpty
    }
    
    /// Validates email format (basic validation)
    var hasValidEmail: Bool {
        return email.contains("@") && email.contains(".")
    }
    
    /// Validates password strength (basic validation)
    var hasValidPassword: Bool {
        return password.count >= 8
    }
    
    /// Comprehensive validation with specific error messages
    func validate() throws {
        guard isValid else {
            throw RegistrationError.missingRequiredFields
        }
        
        guard hasValidEmail else {
            throw RegistrationError.invalidEmail
        }
        
        guard hasValidPassword else {
            throw RegistrationError.weakPassword
        }
    }
}

// MARK: - Registration Errors

enum RegistrationError: LocalizedError {
    case missingRequiredFields
    case invalidEmail
    case weakPassword
    case networkError(Error)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredFields:
            return "Email and password are required"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters long"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Convenience Factory Methods

extension RegistrationRequest {
    /// Create a basic registration request with just email and password
    static func basic(email: String, password: String) -> RegistrationRequest {
        return RegistrationRequest(email: email, password: password)
    }
    
    /// Create a registration request with name
    static func withName(email: String, password: String, name: String) -> RegistrationRequest {
        return RegistrationRequest(email: email, password: password, name: name)
    }
    
    /// Create a full registration request with all relationship data
    static func complete(
        email: String,
        password: String,
        name: String,
        partnerName: String?,
        personalityType: String?,
        relationshipDuration: String? = nil,
        partnerAge: Int? = nil
    ) -> RegistrationRequest {
        return RegistrationRequest(
            email: email,
            password: password,
            name: name,
            partnerName: partnerName,
            personalityType: personalityType,
            relationshipDuration: relationshipDuration,
            partnerAge: partnerAge
        )
    }
}

// MARK: - Migration Helpers

extension RegistrationRequest {
    /// Convert from legacy SignUpRequest to maintain compatibility
    init(from signUpRequest: SignUpRequest) {
        self.init(
            email: signUpRequest.email,
            password: signUpRequest.password,
            name: signUpRequest.name,
            partnerName: signUpRequest.partnerName,
            personalityType: signUpRequest.personalityType
        )
    }
    
    /// Convert from RegisterRequest (from RequestModels.swift) to maintain compatibility
    init(from registerRequest: RegisterRequest) {
        self.init(
            email: registerRequest.email,
            password: registerRequest.password,
            name: registerRequest.name,
            partnerName: registerRequest.partnerName,
            personalityType: nil, // RegisterRequest doesn't have this field
            relationshipDuration: registerRequest.relationshipDuration,
            partnerAge: registerRequest.partnerAge
        )
    }
}