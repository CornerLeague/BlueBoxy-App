//
//  AuthViewModel+Bootstrap.swift
//  BlueBoxy
//
//  Extension methods for AuthViewModel to support enhanced bootstrap functionality
//  Handles initialization, session restoration, and background refresh operations
//

import Foundation
import SwiftUI
import Combine

extension AuthViewModel {
    
    // MARK: - Bootstrap Methods
    
    /// Initialize authentication system during app bootstrap
    func initializeAuth() async {
        print("🔐 Initializing authentication system...")
        
        // Set up initial state
        authState = .idle
        
        // Load any cached user data
        loadCachedUserData()
        
        // Set up session monitoring
        setupSessionMonitoring()
        
        print("✅ Authentication system initialized")
    }
    
    /// Enhanced refresh user session and data with additional validation
    @MainActor
    func enhancedRefreshUser() async {
        guard sessionStore.isAuthenticated else {
            print("ℹ️ No active session to refresh")
            return
        }
        
        print("🔄 Refreshing user session...")
        authState = .loading
        
        do {
            // First, validate the current session
            let isValid = await sessionStore.refreshSessionIfNeeded()
            
            if !isValid {
                print("⚠️ Session expired during refresh")
                await handleSessionExpiry()
                return
            }
            
            // Fetch latest user data
            let user: User = try await apiClient.request(.userProfile)
            
            // Update session store with fresh user data
            sessionStore.updateUser(user)
            
            // Update auth state
            authState = .loaded(user)
            
            print("✅ User session refreshed successfully")
            
        } catch {
            print("❌ Failed to refresh user session: \(error)")
            
            // Handle different error types
            if let networkError = error as? NetworkError {
                switch networkError {
                case .unauthorized, .forbidden:
                    // Token is invalid, logout user
                    await handleSessionExpiry()
                case .noConnection:
                    // Network issue, keep user logged in but show cached data
                    if let cachedUser = loadCachedUserData() {
                        authState = .loaded(cachedUser)
                    } else {
                        authState = .failed(networkError)
                    }
                default:
                    authState = .failed(networkError)
                }
            } else {
                authState = .failed(error)
            }
        }
    }
    
    /// Handle session expiry during app usage
    @MainActor
    private func handleSessionExpiry() async {
        print("🚨 Handling session expiry...")
        
        // Clear all session data
        sessionStore.logout()
        
        // Reset auth state
        authState = .idle
        
        // Clear any cached sensitive data
        clearCachedData()
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(name: .sessionDidExpire, object: nil)
        
        print("🔓 Session expired, user logged out")
    }
    
    // MARK: - Session Management
    
    /// Set up session monitoring for automatic refresh
    private func setupSessionMonitoring() {
        // Monitor session expiry
        Timer.publish(every: 300, on: .main, in: .common) // Check every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkSessionExpiry()
                }
            }
            .store(in: &cancellables)
        
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAppBecameActive()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if session is about to expire and refresh if needed
    private func checkSessionExpiry() async {
        guard sessionStore.isAuthenticated else { return }
        
        // Check if session needs refresh (within 10 minutes of expiry)
        if let expiryDate = sessionStore.sessionExpiryDate,
           Date().addingTimeInterval(600) > expiryDate {
            
            print("⏰ Session expiring soon, attempting refresh...")
            await enhancedRefreshUser()
        }
    }
    
    /// Handle app becoming active (foreground)
    private func handleAppBecameActive() async {
        guard sessionStore.isAuthenticated else { return }
        
        // Refresh session if it's been more than 15 minutes since last refresh
        if let lastRefresh = lastSessionRefresh,
           Date().timeIntervalSince(lastRefresh) > 900 { // 15 minutes
            
            print("📱 App became active, refreshing session...")
            await enhancedRefreshUser()
        }
    }
    
    // MARK: - Data Caching
    
    /// Load cached user data from local storage
    @discardableResult
    private func loadCachedUserData() -> User? {
        guard let userData = UserDefaults.standard.data(forKey: "cachedUserData"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return nil
        }
        
        print("📱 Loaded cached user data")
        return user
    }
    
    /// Cache user data to local storage
    private func cacheUserData(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "cachedUserData")
            print("💾 Cached user data")
        }
    }
    
    /// Clear cached sensitive data
    private func clearCachedData() {
        UserDefaults.standard.removeObject(forKey: "cachedUserData")
        print("🗑️ Cleared cached user data")
    }
    
    // MARK: - Enhanced Authentication Methods
    
    /// Enhanced login with additional session setup
    @MainActor
    func enhancedLogin(email: String, password: String) async {
        print("🔐 Attempting login for: \(email)")
        authState = .loading
        lastSessionRefresh = Date()
        
        do {
            let request = LoginRequest(email: email, password: password)
            let response: LoginResponse = try await apiClient.request(.login(request))
            
            // Set up complete session
            sessionStore.setUserSession(
                userId: response.user.id,
                user: response.user,
                authToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiryDate: response.expiresAt
            )
            
            // Cache user data
            cacheUserData(response.user)
            
            // Update auth state
            authState = .loaded(response.user)
            
            // Track successful login
            trackLoginSuccess()
            
            print("✅ Login successful for user: \(response.user.id)")
            
        } catch {
            print("❌ Login failed: \(error)")
            authState = .failed(error)
            
            // Track failed login attempt
            trackLoginFailure(error: error)
        }
    }
    
    /// Register with enhanced session setup
    @MainActor
    func enhancedRegister(email: String, password: String, name: String) async {
        print("📝 Attempting registration for: \(email)")
        authState = .loading
        lastSessionRefresh = Date()
        
        do {
            let request = RegisterRequest(
                email: email,
                password: password,
                name: name,
                deviceInfo: getDeviceInfo()
            )
            
            let response: RegisterResponse = try await apiClient.request(.register(request))
            
            // Set up complete session
            sessionStore.setUserSession(
                userId: response.user.id,
                user: response.user,
                authToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiryDate: response.expiresAt
            )
            
            // Cache user data
            cacheUserData(response.user)
            
            // Update auth state
            authState = .loaded(response.user)
            
            // Track successful registration
            trackRegistrationSuccess()
            
            print("✅ Registration successful for user: \(response.user.id)")
            
        } catch {
            print("❌ Registration failed: \(error)")
            authState = .failed(error)
            
            // Track failed registration attempt
            trackRegistrationFailure(error: error)
        }
    }
    
    /// Enhanced logout with cleanup
    @MainActor
    func enhancedLogout() async {
        print("🔓 Logging out user...")
        
        // Track logout event
        trackLogout()
        
        // Clear cached data
        clearCachedData()
        
        // Reset auth state
        authState = .idle
        
        // Clear session (this will trigger notification)
        sessionStore.logout()
        
        print("✅ Logout completed")
    }
    
    // MARK: - Additional Auth Methods
    
    // MARK: - Additional Auth Methods (Commented out - require additional properties)
    /*
    /// Send password reset email
    func sendPasswordReset(email: String) async {
        print("📧 Sending password reset email to: \(email)")
        // forgotPasswordState = .loading
        
        do {
            let request = ForgotPasswordRequest(email: email)
            let _: Empty = try await apiClient.request(.forgotPassword(request))
            
            // forgotPasswordState = .loaded(())
            print("✅ Password reset email sent")
            
        } catch {
            print("❌ Failed to send password reset email: \(error)")
            // forgotPasswordState = .failed(error)
        }
    }
    
    /// Reset password with token
    func resetPassword(token: String, newPassword: String) async {
        print("🔑 Resetting password with token")
        // resetPasswordState = .loading
        
        do {
            let request = ResetPasswordRequest(token: token, newPassword: newPassword)
            let _: Empty = try await apiClient.request(.resetPassword(request))
            
            // resetPasswordState = .loaded(())
            print("✅ Password reset successful")
            
        } catch {
            print("❌ Password reset failed: \(error)")
            // resetPasswordState = .failed(error)
        }
    }
    
    /// Resend email verification
    func resendVerificationEmail(email: String) async {
        print("📧 Resending verification email to: \(email)")
        // verificationState = .loading
        
        do {
            let request = ResendVerificationRequest(email: email)
            let _: Empty = try await apiClient.request(.resendVerification(request))
            
            // verificationState = .loaded(())
            print("✅ Verification email resent")
            
        } catch {
            print("❌ Failed to resend verification email: \(error)")
            // verificationState = .failed(error)
        }
    }
    
    /// Check email verification status
    func checkEmailVerification() async {
        print("✅ Checking email verification status")
        // verificationState = .loading
        
        do {
            let response: VerificationStatusResponse = try await apiClient.request(.checkVerification)
            
            if response.isVerified {
                // verificationState = .loaded(())
                
                // Update user data if verification status changed
                if var currentUser = sessionStore.currentUser {
                    currentUser.isEmailVerified = true
                    sessionStore.updateUser(currentUser)
                    authState = .loaded(currentUser)
                }
                
                print("✅ Email verification confirmed")
            } else {
                // verificationState = .failed(NetworkError.badRequest(message: "Email not yet verified"))
            }
            
        } catch {
            print("❌ Email verification check failed: \(error)")
            // verificationState = .failed(error)
        }
    }
    */
    
    // MARK: - Analytics & Tracking
    
    private func trackLoginSuccess() {
        // Track successful login for analytics
        print("📊 Tracking login success")
    }
    
    private func trackLoginFailure(error: Error) {
        // Track failed login for analytics
        print("📊 Tracking login failure: \(error.localizedDescription)")
    }
    
    private func trackRegistrationSuccess() {
        // Track successful registration for analytics
        print("📊 Tracking registration success")
    }
    
    private func trackRegistrationFailure(error: Error) {
        // Track failed registration for analytics
        print("📊 Tracking registration failure: \(error.localizedDescription)")
    }
    
    private func trackLogout() {
        // Track logout event for analytics
        print("📊 Tracking logout")
    }
    
    // MARK: - Device Info
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            deviceType: "iOS",
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
    
    // MARK: - Properties
    // Note: These properties should be defined in the main AuthViewModel class
    // as extensions cannot contain @Published or stored properties
}

// MARK: - Supporting Models

struct DeviceInfo: Codable {
    let deviceType: String
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let token: String
    let newPassword: String
}

struct ResendVerificationRequest: Codable {
    let email: String
}

struct VerificationStatusResponse: Codable {
    let isVerified: Bool
    let verifiedAt: Date?
}