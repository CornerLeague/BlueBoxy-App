//
//  AuthViewModel.swift
//  BlueBoxy
//
//  Core authentication and user state management
//  Handles login, registration, user session, and auth state
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var user: DomainUser?
    @Published var isAuthenticated: Bool = false
    @Published var authState: Loadable<DomainUser> = .idle
    @Published var registrationState: Loadable<DomainUser> = .idle
    @Published var logoutState: Loadable<Void> = .idle
    
    // MARK: - Dependencies
    
    internal let apiClient: APIClient
    internal let sessionStore: SessionStore
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Additional Properties
    
    @Published var lastSessionRefresh: Date?
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = .shared, sessionStore: SessionStore = .shared) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
        
        // Initialize authentication state from stored session
        self.isAuthenticated = sessionStore.userId != nil
        
        // Set up reactive session monitoring
        setupSessionObservation()
        
        // Load user data if already authenticated
        if isAuthenticated {
            Task {
                await refreshUser()
            }
        }
    }
    
    // MARK: - Authentication Actions
    
    /// Register a new user account
    func register(email: String, password: String, name: String? = nil, 
                 partnerName: String? = nil, relationshipDuration: String? = nil, 
                 partnerAge: Int? = nil) async {
        registrationState = .loading()
        
        do {
            // Use centralized registration service for consistent endpoint and payload
            let request = RegistrationRequest(
                email: email,
                password: password,
                name: name,
                partnerName: partnerName,
                personalityType: nil, // AuthViewModel doesn't currently pass personalityType
                relationshipDuration: relationshipDuration,
                partnerAge: partnerAge
            )
            
            let registrationService = RegistrationService(apiClient: apiClient)
            let response = try await registrationService.register(request)
            
            // Update session and state
            await updateAuthenticationState(user: response.user, token: response.token ?? "", isRegistration: true)
            registrationState = .loaded(response.user)
            
        } catch {
            let networkError = ErrorMapper.map(error)
            registrationState = .failed(networkError)
            handleAuthError(networkError)
        }
    }
    
    /// Login existing user
    func login(email: String, password: String) async {
        authState = .loading()
        
        do {
            let request = LoginRequest(email: email, password: password)
            let response: AuthEnvelope = try await apiClient.request(.authLogin(request))
            
            // Update session and state
            await updateAuthenticationState(user: response.user, token: response.token ?? "")
            authState = .loaded(response.user)
            
        } catch {
            let networkError = ErrorMapper.map(error)
            authState = .failed(networkError)
            handleAuthError(networkError)
        }
    }
    
    /// Refresh current user data
    func refreshUser() async {
        guard sessionStore.userId != nil else { 
            await logout()
            return 
        }
        
        do {
            let user: DomainUser = try await apiClient.request(.authMe())
            self.user = user
            authState = .loaded(user)
            
        } catch {
            let networkError = ErrorMapper.map(error)
            authState = .failed(networkError)
            
            // If refresh fails with auth error, logout user
            if networkError.isAuthenticationError {
                await logout()
            }
        }
    }
    
    /// Logout current user
    func logout() async {
        logoutState = .loading()
        
        // Attempt to notify server of logout
        do {
            try await apiClient.requestEmpty(.authLogout())
        } catch {
            // Ignore logout API errors - still proceed with local logout
            print("⚠️ Server logout failed: \(error.localizedDescription)")
        }
        
        // Clear local session regardless of server response
        sessionStore.logout()
        clearAuthenticationState()
        logoutState = .loaded(())
    }
    
    // MARK: - Validation Helpers
    
    /// Check if the current user session is valid
    var isSessionValid: Bool {
        return isAuthenticated && user != nil
    }
    
    /// Check if authentication is in progress
    var isAuthenticating: Bool {
        return authState.isLoading || registrationState.isLoading
    }
    
    /// Get current authentication error if any
    var authError: NetworkError? {
        return authState.error ?? registrationState.error
    }
    
    /// Clear any authentication errors
    func clearAuthError() {
        if case .failed = authState {
            authState = .idle
        }
        if case .failed = registrationState {
            registrationState = .idle
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupSessionObservation() {
        // Monitor session changes (if SessionStore publishes changes)
        // TODO: Define userAuthenticationFailed notification or use different approach
        // NotificationCenter.default
        //     .publisher(for: .userAuthenticationFailed)
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] _ in
        //         Task { @MainActor [weak self] in
        //             await self?.logout()
        //         }
        //     }
        //     .store(in: &cancellables)
    }
    
    internal func updateAuthenticationState(user: DomainUser, token: String, isRegistration: Bool = false) async {
        // Convert DomainUser to BasicUser for SessionStore
        let basicUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
            lastLoginAt: user.lastLoginAt
        )
        
        // Update session store with complete user session
        sessionStore.setUserSession(
            userId: user.id,
            user: basicUser,
            authToken: token,
            refreshToken: "" // Empty for now since we don't have refresh token from response
        )
        
        // Update view model state
        self.user = user
        self.isAuthenticated = true
        
        // Post appropriate notification for navigation
        DispatchQueue.main.async {
            if isRegistration {
                // Clear onboarding completion flag for new registrations
                // to ensure they go through the onboarding flow
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                NotificationCenter.default.post(name: .userDidRegister, object: user)
            } else {
                NotificationCenter.default.post(name: .userDidLogin, object: user)
            }
        }
    }
    
    private func clearAuthenticationState() {
        user = nil
        isAuthenticated = false
        authState = .idle
        registrationState = .idle
    }
    
    private func handleAuthError(_ error: NetworkError) {
        // Log authentication errors for debugging
        print("🚨 Authentication Error: \(error.localizedDescription)")
        
        // Clear sensitive state on auth errors
        if error.isAuthenticationError {
            clearAuthenticationState()
        }
    }
}

// MARK: - Session Store
// Using shared SessionStore from Core/Services/SessionStore.swift

// MARK: - Notification Extensions
// These are defined in Core/Services/SessionStore.swift
