//
//  MockAPIClient.swift
//  BlueBoxy
//
//  Mock API client for SwiftUI previews and testing
//  Provides realistic data for UI development
//

import Foundation

#if DEBUG
/// Mock API client that returns preview data instead of making real network requests
final class MockAPIClient {
    
    // MARK: - Authentication
    
    /// Mock authenticated user response
    func me() -> AuthEnvelope {
        PreviewData.load("auth_me_success.json", as: AuthEnvelope.self)
    }
    
    /// Mock login response
    func login(email: String, password: String) -> AuthEnvelope {
        PreviewData.load("auth_me_success.json", as: AuthEnvelope.self)
    }
    
    /// Mock registration response
    func register(email: String, password: String, name: String) -> AuthEnvelope {
        PreviewData.load("auth_me_success.json", as: AuthEnvelope.self)
    }
    
    // MARK: - Message Generation
    
    /// Mock message generation response
    func generateMessages() -> MessageGenerationResponse {
        PreviewData.load("messages_generate_success.json", as: MessageGenerationResponse.self)
    }
    
    /// Mock message generation with context
    func generateMessages(context: String?, mood: String?, category: String?) -> MessageGenerationResponse {
        // You could create different JSON files based on parameters
        switch category {
        case "romantic":
            return generateRomanticMessages()
        case "support":
            return generateSupportMessages()
        default:
            return PreviewData.load("messages_generate_success.json", as: MessageGenerationResponse.self)
        }
    }
    
    // MARK: - Profile Data
    
    /// Mock personality insight
    func getPersonalityInsight() -> PersonalityInsight {
        let authEnvelope = me()
        return authEnvelope.user.personalityInsight!
    }
    
    // MARK: - User Variations
    
    /// Mock user with incomplete profile
    func incompleteProfileUser() -> AuthEnvelope {
        var authEnvelope = me()
        // Create a user with missing fields for onboarding flow previews
        var user = authEnvelope.user
        // You would modify user properties here
        return AuthEnvelope(user: user, token: authEnvelope.token, refreshToken: authEnvelope.refreshToken, expiresAt: authEnvelope.expiresAt)
    }
    
    /// Mock new user
    func newUser() -> AuthEnvelope {
        let basicUser = DomainUser(
            id: 456,
            email: "new.user@example.com",
            name: "New User",
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
            subscriptionTier: "free"
        )
        
        return AuthEnvelope(
            user: basicUser,
            token: "new_user_token",
            refreshToken: nil,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        )
    }
    
    // MARK: - Private Helpers
    
    private func generateRomanticMessages() -> MessageGenerationResponse {
        // Could load a different JSON file or modify the existing one
        return PreviewData.load("messages_generate_success.json", as: MessageGenerationResponse.self)
    }
    
    private func generateSupportMessages() -> MessageGenerationResponse {
        // Could load a different JSON file for support messages
        return PreviewData.load("messages_generate_success.json", as: MessageGenerationResponse.self)
    }
}

// MARK: - Preview Helpers

extension MockAPIClient {
    /// Shared instance for previews
    static let shared = MockAPIClient()
    
    /// Quick access to sample data
    static var sampleUser: DomainUser {
        shared.me().user
    }
    
    static var sampleMessages: [MessageItem] {
        shared.generateMessages().messages
    }
    
    static var samplePersonalityInsight: PersonalityInsight {
        shared.getPersonalityInsight()
    }
}

// MARK: - SessionViewModel Mock Extension

#if DEBUG
extension SessionViewModel {
    /// Create a SessionViewModel with mock data for previews
    static var preview: SessionViewModel {
        let viewModel = SessionViewModel()
        viewModel.user = MockAPIClient.sampleUser
        viewModel.status = "Loaded"
        return viewModel
    }
    
    /// SessionViewModel with loading state for previews
    static var previewLoading: SessionViewModel {
        let viewModel = SessionViewModel()
        viewModel.isLoading = true
        viewModel.status = "Loading user..."
        return viewModel
    }
    
    /// SessionViewModel with error state for previews
    static var previewError: SessionViewModel {
        let viewModel = SessionViewModel()
        viewModel.error = APIServiceError.badRequest(message: "Invalid credentials")
        viewModel.status = "Login failed"
        return viewModel
    }
    
    /// SessionViewModel for new user (onboarding flow)
    static var previewNewUser: SessionViewModel {
        let viewModel = SessionViewModel()
        viewModel.user = MockAPIClient.shared.newUser().user
        viewModel.status = "Registered successfully"
        return viewModel
    }
}
#endif

#endif