//
//  AuthService.swift
//  BlueBoxy
//
//  Authentication service using domain models and flexible decoding
//

import Foundation

@MainActor
class AuthService: ObservableObject {
    private let apiClient = APIClient.shared
    private let sessionStore = SessionStore.shared
    
    @Published var currentUser: DomainUser?
    @Published var isLoading = false
    @Published var error: APIServiceError?
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async throws -> DomainUser {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let request = LoginRequest(email: email, password: password)
            let endpoint = Endpoint(
                path: "/auth/login",
                method: .POST,
                body: request,
                requiresUser: false
            )
            let response: AuthEnvelope = try await apiClient.request(endpoint)
            
            // Store user ID in session
            sessionStore.userId = response.user.id
            currentUser = response.user
            
            return response.user
            
        } catch let apiError as APIServiceError {
            error = apiError
            throw apiError
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            throw serviceError
        }
    }
    
    func signUp(
        email: String,
        password: String,
        name: String,
        partnerName: String? = nil,
        personalityType: String? = nil
    ) async throws -> DomainUser {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Use centralized registration service for consistent endpoint and payload
            let request = RegistrationRequest(
                email: email,
                password: password,
                name: name,
                partnerName: partnerName,
                personalityType: personalityType
            )
            
            let registrationService = RegistrationService(apiClient: apiClient)
            let response = try await registrationService.register(request)
            
            // Store user ID in session
            sessionStore.userId = response.user.id
            currentUser = response.user
            
            // Clear onboarding flag and emit registration notification for new users
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .userDidRegister, object: response.user)
            }
            
            return response.user
            
        } catch let apiError as APIServiceError {
            error = apiError
            throw apiError
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            throw serviceError
        }
    }
    
    func getCurrentUser() async throws -> DomainUser {
        let endpoint = Endpoint(
            path: "/auth/me",
            method: .GET,
            requiresUser: true
        )
        let response: AuthEnvelope = try await apiClient.request(endpoint)
        
        currentUser = response.user
        return response.user
    }
    
    func updateProfile(_ request: UpdateProfileRequest) async throws -> DomainUser {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let endpoint = Endpoint(
                path: "/auth/profile",
                method: .PUT,
                body: request,
                requiresUser: true
            )
            let response: AuthEnvelope = try await apiClient.request(endpoint)
            
            currentUser = response.user
            return response.user
            
        } catch let apiError as APIServiceError {
            error = apiError
            throw apiError
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            throw serviceError
        }
    }
    
    func logout() {
        sessionStore.logout()
        currentUser = nil
        error = nil
    }
    
    // MARK: - Message Generation
    
    func generateMessages(
        context: String? = nil,
        mood: String? = nil,
        category: String? = nil
    ) async throws -> MessageGenerationResponse {
        let request = MessageGenerationRequest(
            context: context,
            mood: mood,
            category: category,
            personalityType: currentUser?.personalityType,
            relationshipStage: currentUser?.relationshipDuration
        )
        
        let endpoint = Endpoint(
            path: "/messages/generate",
            method: .POST,
            body: request,
            requiresUser: true
        )
        return try await apiClient.request(endpoint)
    }
    
    func getPersonalityInsight() async throws -> PersonalityInsight {
        struct PersonalityInsightResponse: Decodable {
            let insight: PersonalityInsight
        }
        
        let endpoint = Endpoint(
            path: "/user/personality-insight",
            method: .GET,
            requiresUser: true
        )
        let response: PersonalityInsightResponse = try await apiClient.request(endpoint)
        
        return response.insight
    }
    
    // MARK: - Convenience Methods
    
    var isLoggedIn: Bool {
        return sessionStore.userId != nil
    }
    
    var hasCompleteProfile: Bool {
        return currentUser?.hasCompleteProfile ?? false
    }
    
    var userPersonalityType: String? {
        return currentUser?.personalityType
    }
    
    var relationshipDurationInMonths: Int? {
        return currentUser?.relationshipDurationMonths
    }
}
