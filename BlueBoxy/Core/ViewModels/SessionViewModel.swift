//
//  SessionViewModel.swift
//  BlueBoxy
//
//  Session management view model with authentication and user state
//

import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: DomainUser?
    @Published var status = "Idle"
    @Published var isLoading = false
    @Published var error: APIServiceError?
    
    // MARK: - Private Properties
    
    private let apiClient = APIClient.shared
    private let sessionStore = SessionStore.shared
    
    // MARK: - Computed Properties
    
    var isLoggedIn: Bool {
        return sessionStore.userId != nil && user != nil
    }
    
    var hasCompleteProfile: Bool {
        return user?.hasCompleteProfile ?? false
    }
    
    var needsOnboarding: Bool {
        return isLoggedIn && !hasCompleteProfile
    }
    
    // MARK: - Initialization
    
    init() {
        // Check if user is already logged in
        if sessionStore.userId != nil {
            Task {
                await loadCurrentUser()
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func register(
        email: String, 
        password: String, 
        name: String,
        partnerName: String? = nil,
        personalityType: String? = nil
    ) async {
        isLoading = true
        error = nil
        status = "Registering..."
        
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
            let env = try await registrationService.register(request)
            
            // Update session
            sessionStore.userId = env.user.id
            user = env.user
            status = "Registered successfully"
            
            // Clear onboarding flag and emit registration notification for new users
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .userDidRegister, object: env.user)
            }
            
        } catch let apiError as APIServiceError {
            error = apiError
            status = apiError.localizedDescription
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            status = serviceError.localizedDescription
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        error = nil
        status = "Logging in..."
        
        struct LoginBody: Encodable {
            let email: String
            let password: String
        }
        
        do {
            let body = LoginBody(email: email, password: password)
            let endpoint = Endpoint(
                path: "/api/auth/login",
                method: .POST,
                body: body,
                requiresUser: false
            )
            let env: AuthEnvelope = try await apiClient.request(endpoint)
            
            // Update session
            sessionStore.userId = env.user.id
            user = env.user
            status = "Logged in successfully"
            
        } catch let apiError as APIServiceError {
            error = apiError
            status = apiError.localizedDescription
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            status = serviceError.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadCurrentUser() async {
        guard sessionStore.userId != nil else {
            user = nil
            status = "Not logged in"
            return
        }
        
        isLoading = true
        error = nil
        status = "Loading user..."
        
        do {
            let endpoint = Endpoint(
                path: "/api/auth/me",
                method: .GET,
                requiresUser: true
            )
            let env: AuthEnvelope = try await apiClient.request(endpoint)
            
            user = env.user
            status = "User loaded"
            
        } catch let apiError as APIServiceError {
            error = apiError
            status = apiError.localizedDescription
            
            // If unauthorized, clear session
            if case .unauthorized = apiError {
                logout()
            }
            
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            status = serviceError.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        sessionStore.logout()
        user = nil
        error = nil
        status = "Logged out"
    }
    
    // MARK: - Profile Management
    
    func updateProfile(
        name: String? = nil,
        partnerName: String? = nil,
        relationshipDuration: String? = nil,
        partnerAge: Int? = nil,
        personalityType: String? = nil
    ) async {
        guard isLoggedIn else {
            status = "Must be logged in to update profile"
            return
        }
        
        isLoading = true
        error = nil
        status = "Updating profile..."
        
        let request = UpdateProfileRequest(
            name: name,
            partnerName: partnerName,
            relationshipDuration: relationshipDuration,
            partnerAge: partnerAge,
            personalityType: personalityType,
            preferences: nil,
            location: nil
        )
        
        do {
            let endpoint = Endpoint(
                path: "/api/auth/profile",
                method: .PUT,
                body: request,
                requiresUser: true
            )
            let env: AuthEnvelope = try await apiClient.request(endpoint)
            
            user = env.user
            status = "Profile updated successfully"
            
        } catch let apiError as APIServiceError {
            error = apiError
            status = apiError.localizedDescription
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            status = serviceError.localizedDescription
        }
        
        isLoading = false
    }
    
    func updatePreferences(_ preferences: [String: Any]) async {
        guard isLoggedIn else {
            status = "Must be logged in to update preferences"
            return
        }
        
        isLoading = true
        error = nil
        status = "Updating preferences..."
        
        // Convert to AnyEncodable - handle common types
        let encodablePreferences: [String: AnyEncodable] = preferences.compactMapValues { value in
            if let encodable = value as? Encodable {
                return AnyEncodable(encodable)
            } else {
                // Handle basic types that might not conform to Encodable
                switch value {
                case let string as String:
                    return AnyEncodable(string)
                case let int as Int:
                    return AnyEncodable(int)
                case let double as Double:
                    return AnyEncodable(double)
                case let bool as Bool:
                    return AnyEncodable(bool)
                default:
                    return nil // Skip non-encodable values
                }
            }
        }
        
        let request = UpdateProfileRequest(
            name: nil,
            partnerName: nil,
            relationshipDuration: nil,
            partnerAge: nil,
            personalityType: nil,
            preferences: encodablePreferences,
            location: nil
        )
        
        do {
            let endpoint = Endpoint(
                path: "/api/auth/profile",
                method: .PUT,
                body: request,
                requiresUser: true
            )
            let env: AuthEnvelope = try await apiClient.request(endpoint)
            
            user = env.user
            status = "Preferences updated successfully"
            
        } catch let apiError as APIServiceError {
            error = apiError
            status = apiError.localizedDescription
        } catch {
            let serviceError = APIServiceError.network(error)
            self.error = serviceError
            status = serviceError.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Convenience Methods
    
    func clearError() {
        error = nil
        if status.contains("error") || status.contains("Error") {
            status = "Idle"
        }
    }
    
    func refreshUser() async {
        await loadCurrentUser()
    }
    
    // MARK: - User Properties Helpers
    
    var userName: String? {
        return user?.name
    }
    
    var userEmail: String? {
        return user?.email
    }
    
    var partnerName: String? {
        return user?.partnerName
    }
    
    var personalityType: String? {
        return user?.personalityType
    }
    
    var relationshipDurationInMonths: Int? {
        return user?.relationshipDurationMonths
    }
    
    var personalityInsight: PersonalityInsight? {
        return user?.personalityInsight
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func validatePassword(_ password: String) -> Bool {
        return password.count >= 8
    }
    
    func validateName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}