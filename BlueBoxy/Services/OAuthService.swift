//
//  OAuthService.swift
//  BlueBoxy
//
//  OAuth authentication service for calendar provider integration
//  Handles secure authentication flow with state management and error handling
//

import Foundation
import AuthenticationServices
import UIKit

@MainActor
class OAuthService: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var authState: OAuthState = .idle
    @Published var currentProvider: CalendarProvider?
    
    // MARK: - Private Properties
    
    private var authSession: ASWebAuthenticationSession?
    private var currentOAuthState: String?
    private var pendingProvider: CalendarProvider?
    
    // MARK: - OAuth State
    
    enum OAuthState: Equatable {
        case idle
        case initiating
        case presentingWeb
        case processingCallback
        case exchangingCode
        case completed(success: Bool, provider: CalendarProvider)
        case failed(error: OAuthError)
        
        var isLoading: Bool {
            switch self {
            case .initiating, .presentingWeb, .processingCallback, .exchangingCode:
                return true
            default:
                return false
            }
        }
        
        var isActive: Bool {
            switch self {
            case .idle, .completed, .failed:
                return false
            default:
                return true
            }
        }
    }
    
    // MARK: - OAuth Errors
    
    enum OAuthError: LocalizedError, Equatable {
        case invalidProvider
        case missingAuthUrl
        case invalidAuthUrl
        case userCancelled
        case invalidCallback
        case missingAuthorizationCode
        case stateValidationFailed
        case networkError(String)
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidProvider:
                return "Invalid calendar provider selected"
            case .missingAuthUrl:
                return "Authentication URL not available for this provider"
            case .invalidAuthUrl:
                return "Invalid authentication URL format"
            case .userCancelled:
                return "Authentication was cancelled"
            case .invalidCallback:
                return "Invalid authentication callback received"
            case .missingAuthorizationCode:
                return "Authorization code not received"
            case .stateValidationFailed:
                return "Security validation failed - please try again"
            case .networkError(let message):
                return "Network error: \(message)"
            case .unknownError(let message):
                return "Authentication error: \(message)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .userCancelled:
                return "Try connecting to the calendar provider again"
            case .stateValidationFailed:
                return "This may be a security issue. Please try authenticating again"
            case .networkError:
                return "Check your internet connection and try again"
            default:
                return "Please try connecting to the calendar provider again"
            }
        }
    }
    
    // MARK: - Configuration
    
    private struct OAuthConfig {
        static let callbackScheme = "blueboxy"
        static let stateLength = 32
        static let timeoutInterval: TimeInterval = 60
    }
    
    // MARK: - Public Methods
    
    /// Initiate OAuth flow for a calendar provider
    func authenticate(provider: CalendarProvider) async -> Result<CalendarConnectionResponse, OAuthError> {
        // Validate provider
        guard provider.authUrl != nil else {
            let error = OAuthError.missingAuthUrl
            authState = .failed(error: error)
            return .failure(error)
        }
        
        // Set initial state
        authState = .initiating
        currentProvider = provider
        pendingProvider = provider
        
        do {
            // Generate secure state parameter
            let state = generateSecureState()
            currentOAuthState = state
            
            // Build authorization URL with state
            guard let authUrl = buildAuthorizationUrl(provider: provider, state: state) else {
                let error = OAuthError.invalidAuthUrl
                authState = .failed(error: error)
                return .failure(error)
            }
            
            // Present authentication session
            let result = await presentAuthenticationSession(url: authUrl)
            
            switch result {
            case .success(let callbackUrl):
                return await processAuthenticationCallback(callbackUrl: callbackUrl, provider: provider)
                
            case .failure(let error):
                authState = .failed(error: error)
                return .failure(error)
            }
            
        } catch {
            let oauthError = OAuthError.unknownError(error.localizedDescription)
            authState = .failed(error: oauthError)
            return .failure(oauthError)
        }
    }
    
    /// Cancel any ongoing authentication
    func cancelAuthentication() {
        authSession?.cancel()
        authSession = nil
        currentOAuthState = nil
        pendingProvider = nil
        authState = .idle
    }
    
    /// Reset authentication state
    func resetState() {
        cancelAuthentication()
        currentProvider = nil
    }
    
    // MARK: - Private Methods
    
    private func generateSecureState() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<OAuthConfig.stateLength).map { _ in
            characters.randomElement()!
        })
    }
    
    private func buildAuthorizationUrl(provider: CalendarProvider, state: String) -> URL? {
        guard let baseAuthUrl = provider.authUrl,
              var components = URLComponents(string: baseAuthUrl) else {
            return nil
        }
        
        // Add state parameter for security
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "state", value: state))
        
        // Add redirect_uri if not already present
        if !queryItems.contains(where: { $0.name == "redirect_uri" }) {
            queryItems.append(URLQueryItem(name: "redirect_uri", value: "\(OAuthConfig.callbackScheme)://oauth/callback"))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    private func presentAuthenticationSession(url: URL) async -> Result<URL, OAuthError> {
        return await withCheckedContinuation { continuation in
            authState = .presentingWeb
            
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: OAuthConfig.callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor [weak self] in
                    if let error = error {
                        let oauthError = self?.mapAuthSessionError(error) ?? .unknownError(error.localizedDescription)
                        continuation.resume(returning: .failure(oauthError))
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        continuation.resume(returning: .failure(.invalidCallback))
                        return
                    }
                    
                    continuation.resume(returning: .success(callbackURL))
                }
            }
            
            // Configure session
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            // Store session reference and start
            self.authSession = session
            
            DispatchQueue.main.async {
                if !session.start() {
                    continuation.resume(returning: .failure(.unknownError("Failed to start authentication session")))
                }
            }
        }
    }
    
    private func processAuthenticationCallback(callbackUrl: URL, provider: CalendarProvider) async -> Result<CalendarConnectionResponse, OAuthError> {
        authState = .processingCallback
        
        // Extract parameters from callback URL
        guard let components = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            let error = OAuthError.invalidCallback
            authState = .failed(error: error)
            return .failure(error)
        }
        
        // Check for error in callback
        if let errorParam = queryItems.first(where: { $0.name == "error" })?.value {
            let error = OAuthError.networkError(errorParam)
            authState = .failed(error: error)
            return .failure(error)
        }
        
        // Validate state parameter
        if let receivedState = queryItems.first(where: { $0.name == "state" })?.value {
            guard receivedState == currentOAuthState else {
                let error = OAuthError.stateValidationFailed
                authState = .failed(error: error)
                return .failure(error)
            }
        }
        
        // Extract authorization code
        guard let authorizationCode = queryItems.first(where: { $0.name == "code" })?.value else {
            let error = OAuthError.missingAuthorizationCode
            authState = .failed(error: error)
            return .failure(error)
        }
        
        // Exchange authorization code for access token
        return await exchangeAuthorizationCode(code: authorizationCode, provider: provider)
    }
    
    private func exchangeAuthorizationCode(code: String, provider: CalendarProvider) async -> Result<CalendarConnectionResponse, OAuthError> {
        authState = .exchangingCode
        
        do {
            // Use the API client to complete the OAuth flow
            let apiClient = APIClient.shared
            let response: CalendarConnectionResponse = try await apiClient.request(
                .calendarConnect(providerId: provider.id)
            )
            
            // Clear OAuth state
            currentOAuthState = nil
            authSession = nil
            
            // Update state
            authState = .completed(success: response.success, provider: provider)
            
            return .success(response)
            
        } catch {
            let oauthError = OAuthError.networkError(error.localizedDescription)
            authState = .failed(error: oauthError)
            return .failure(oauthError)
        }
    }
    
    private func mapAuthSessionError(_ error: Error) -> OAuthError {
        if let authError = error as? ASWebAuthenticationSessionError {
            switch authError.code {
            case .canceledLogin:
                return .userCancelled
            case .presentationContextNotProvided:
                return .unknownError("Presentation context not available")
            case .presentationContextInvalid:
                return .unknownError("Invalid presentation context")
            @unknown default:
                return .unknownError(authError.localizedDescription)
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Find the key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        // Fallback to first available window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        
        // Final fallback
        return UIWindow()
    }
}

// MARK: - OAuth State Management

extension OAuthService {
    
    /// Get human-readable status message
    var statusMessage: String {
        switch authState {
        case .idle:
            return "Ready to authenticate"
        case .initiating:
            return "Preparing authentication..."
        case .presentingWeb:
            return "Please complete authentication in browser"
        case .processingCallback:
            return "Processing authentication response..."
        case .exchangingCode:
            return "Finalizing connection..."
        case .completed(let success, let provider):
            return success ? "Successfully connected to \(provider.displayName)" : "Failed to connect to \(provider.displayName)"
        case .failed(let error):
            return error.localizedDescription
        }
    }
    
    /// Get current progress percentage (0.0 to 1.0)
    var progress: Double {
        switch authState {
        case .idle:
            return 0.0
        case .initiating:
            return 0.2
        case .presentingWeb:
            return 0.4
        case .processingCallback:
            return 0.7
        case .exchangingCode:
            return 0.9
        case .completed, .failed:
            return 1.0
        }
    }
    
    /// Whether retry is possible for current state
    var canRetry: Bool {
        switch authState {
        case .failed, .completed(false, _):
            return true
        default:
            return false
        }
    }
}

// MARK: - Convenience Methods

extension OAuthService {
    
    /// Quick authentication with built-in error handling
    func authenticateWithErrorHandling(provider: CalendarProvider) async -> CalendarConnectionResponse? {
        let result = await authenticate(provider: provider)
        
        switch result {
        case .success(let response):
            print("✅ OAuth Success: Connected to \(provider.displayName)")
            return response
            
        case .failure(let error):
            print("❌ OAuth Error: \(error.localizedDescription)")
            // Error is already set in authState, UI can observe it
            return nil
        }
    }
    
    /// Check if a provider is currently being authenticated
    func isAuthenticating(provider: CalendarProvider) -> Bool {
        return authState.isActive && pendingProvider?.id == provider.id
    }
}

// MARK: - Security Utilities

extension OAuthService {
    
    /// Validate callback URL scheme for security
    static func isValidCallbackUrl(_ url: URL) -> Bool {
        return url.scheme == OAuthConfig.callbackScheme
    }
    
    /// Extract provider ID from callback URL if present
    static func extractProviderFromCallback(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "provider" })?.value
    }
}