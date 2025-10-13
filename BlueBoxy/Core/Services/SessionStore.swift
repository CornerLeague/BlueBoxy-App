//
//  SessionStore.swift
//  BlueBoxy
//
//  Enhanced user session management with Keychain support and reactive auth state
//

import Foundation
import Combine
import Security

final class SessionStore: ObservableObject {
    static let shared = SessionStore()
    
    // MARK: - Published State
    
    @Published var userId: Int? {
        didSet {
            if userId != oldValue {
                persistUserId()
                updateAuthenticationState()
                publishAuthenticationChanges()
            }
        }
    }
    
    @Published var currentUser: User? {
        didSet {
            if currentUser != oldValue {
                persistUserData()
                publishUserDataChanges()
            }
        }
    }
    
    @Published var authToken: String? {
        didSet {
            if authToken != oldValue {
                persistAuthToken()
                updateAuthenticationState()
            }
        }
    }
    
    @Published var refreshToken: String? {
        didSet {
            if refreshToken != oldValue {
                persistRefreshToken()
            }
        }
    }
    
    @Published var isAuthenticated: Bool = false
    @Published var sessionExpiryDate: Date?
    
    // MARK: - Configuration
    
    private let defaults = UserDefaults.standard
    private let useKeychain = true // Set to false to use UserDefaults only
    
    // Storage keys
    private let userIdKey = "blueboxy.userId"
    private let userDataKey = "blueboxy.userData"
    private let authTokenKey = "blueboxy.authToken"
    private let refreshTokenKey = "blueboxy.refreshToken"
    private let sessionExpiryKey = "blueboxy.sessionExpiry"
    
    // Keychain service
    private let keychainService = "com.blueboxy.app"
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedSession()
        updateAuthenticationState()
        setupSessionValidation()
    }
    
    // MARK: - Session Management
    
    /// Set user session with all authentication data
    func setUserSession(
        userId: Int,
        user: User,
        authToken: String,
        refreshToken: String,
        expiryDate: Date? = nil
    ) {
        self.userId = userId
        self.currentUser = user
        self.authToken = authToken
        self.refreshToken = refreshToken
        self.sessionExpiryDate = expiryDate
        
        updateAuthenticationState()
    }
    
    /// Update user information without affecting tokens
    func updateUser(_ user: User) {
        self.currentUser = user
    }
    
    /// Update auth tokens and expiry
    func updateTokens(authToken: String, refreshToken: String, expiryDate: Date? = nil) {
        self.authToken = authToken
        self.refreshToken = refreshToken
        self.sessionExpiryDate = expiryDate
        
        updateAuthenticationState()
    }
    
    /// Clear all session data and logout
    func logout() {
        // Clear published properties
        userId = nil
        currentUser = nil
        authToken = nil
        refreshToken = nil
        sessionExpiryDate = nil
        isAuthenticated = false
        
        // Clear persisted data
        clearAllPersistedData()
        
        // Post logout notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .userDidLogout, object: nil)
        }
    }
    
    /// Check if current session is valid
    func isSessionValid() -> Bool {
        guard userId != nil,
              authToken != nil else {
            return false
        }
        
        // Check expiry if available
        if let expiryDate = sessionExpiryDate {
            return Date() < expiryDate
        }
        
        return true
    }
    
    /// Refresh session if needed
    func refreshSessionIfNeeded() async -> Bool {
        guard let refreshToken = refreshToken else {
            return false
        }
        
        // Check if refresh is needed (within 5 minutes of expiry)
        if let expiryDate = sessionExpiryDate,
           Date().addingTimeInterval(300) > expiryDate {
            // Implement token refresh logic here
            // This would typically call your API to refresh tokens
            return await performTokenRefresh(refreshToken: refreshToken)
        }
        
        return isSessionValid()
    }
    
    // MARK: - Private Helpers
    
    private func loadPersistedSession() {
        // Load user ID
        if useKeychain {
            userId = loadFromKeychain(key: userIdKey).flatMap { Int($0) }
        } else {
            let stored = defaults.integer(forKey: userIdKey)
            userId = (stored == 0) ? nil : stored
        }
        
        // Load user data
        if let userData = defaults.data(forKey: userDataKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
        }
        
        // Load tokens from Keychain (sensitive data)
        if useKeychain {
            authToken = loadFromKeychain(key: authTokenKey)
            refreshToken = loadFromKeychain(key: refreshTokenKey)
        }
        
        // Load session expiry
        if let expiryData = defaults.data(forKey: sessionExpiryKey),
           let expiry = try? JSONDecoder().decode(Date.self, from: expiryData) {
            sessionExpiryDate = expiry
        }
    }
    
    private func persistUserId() {
        if let id = userId {
            if useKeychain {
                saveToKeychain(key: userIdKey, value: String(id))
            } else {
                defaults.set(id, forKey: userIdKey)
            }
        } else {
            if useKeychain {
                deleteFromKeychain(key: userIdKey)
            } else {
                defaults.removeObject(forKey: userIdKey)
            }
        }
    }
    
    private func persistUserData() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            defaults.set(userData, forKey: userDataKey)
        } else {
            defaults.removeObject(forKey: userDataKey)
        }
    }
    
    private func persistAuthToken() {
        if let token = authToken {
            if useKeychain {
                saveToKeychain(key: authTokenKey, value: token)
            }
        } else {
            if useKeychain {
                deleteFromKeychain(key: authTokenKey)
            }
        }
    }
    
    private func persistRefreshToken() {
        if let token = refreshToken {
            if useKeychain {
                saveToKeychain(key: refreshTokenKey, value: token)
            }
        } else {
            if useKeychain {
                deleteFromKeychain(key: refreshTokenKey)
            }
        }
    }
    
    private func updateAuthenticationState() {
        let wasAuthenticated = isAuthenticated
        isAuthenticated = isSessionValid()
        
        // Post authentication change notification if state changed
        if isAuthenticated != wasAuthenticated {
            DispatchQueue.main.async { [weak self] in
                if self?.isAuthenticated == true {
                    NotificationCenter.default.post(
                        name: .userDidLogin,
                        object: self?.currentUser
                    )
                }
            }
        }
    }
    
    private func publishAuthenticationChanges() {
        // Additional reactive notifications can be added here
        objectWillChange.send()
    }
    
    private func publishUserDataChanges() {
        objectWillChange.send()
    }
    
    private func clearAllPersistedData() {
        // Clear UserDefaults
        defaults.removeObject(forKey: userIdKey)
        defaults.removeObject(forKey: userDataKey)
        defaults.removeObject(forKey: sessionExpiryKey)
        
        // Clear Keychain
        if useKeychain {
            deleteFromKeychain(key: userIdKey)
            deleteFromKeychain(key: authTokenKey)
            deleteFromKeychain(key: refreshTokenKey)
        }
    }
    
    private func setupSessionValidation() {
        // Set up timer to periodically validate session
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let self = self, self.isAuthenticated {
                    let stillValid = await self.refreshSessionIfNeeded()
                    if !stillValid {
                        self.logout()
                    }
                }
            }
        }
    }
    
    private func performTokenRefresh(refreshToken: String) async -> Bool {
        // This would implement actual token refresh logic
        // For now, return current validity
        return isSessionValid()
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("⚠️ Failed to save to Keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let userDataDidUpdate = Notification.Name("userDataDidUpdate")
    static let sessionWillExpire = Notification.Name("sessionWillExpire")
    static let sessionDidExpire = Notification.Name("sessionDidExpire")
}
