//
//  URLSchemeHandler.swift
//  BlueBoxy
//
//  URL scheme handler for OAuth callbacks and deep linking
//

import SwiftUI
import Foundation

@MainActor
class URLSchemeHandler: ObservableObject {
    
    // MARK: - Published State
    
    @Published var lastHandledURL: URL?
    @Published var handlingState: URLHandlingState = .idle
    
    // MARK: - URL Handling State
    
    enum URLHandlingState {
        case idle
        case processing(URL)
        case handled(URL, success: Bool)
        case failed(URL, error: URLHandlingError)
        
        var isProcessing: Bool {
            if case .processing = self {
                return true
            }
            return false
        }
    }
    
    // MARK: - URL Handling Errors
    
    enum URLHandlingError: LocalizedError {
        case invalidScheme
        case unsupportedPath
        case missingParameters
        case securityValidationFailed
        case handlerNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidScheme:
                return "Invalid URL scheme"
            case .unsupportedPath:
                return "Unsupported URL path"
            case .missingParameters:
                return "Required parameters missing"
            case .securityValidationFailed:
                return "Security validation failed"
            case .handlerNotFound:
                return "No handler found for URL"
            }
        }
    }
    
    // MARK: - Supported URL Schemes
    
    enum SupportedScheme: String, CaseIterable {
        case blueboxy = "blueboxy"
        
        var displayName: String {
            switch self {
            case .blueboxy:
                return "BlueBoxy"
            }
        }
    }
    
    // MARK: - Supported URL Paths
    
    enum SupportedPath: String, CaseIterable {
        case oauthCallback = "/oauth/callback"
        case calendarConnect = "/calendar/connect"
        case eventDeepLink = "/event"
        
        var displayName: String {
            switch self {
            case .oauthCallback:
                return "OAuth Callback"
            case .calendarConnect:
                return "Calendar Connection"
            case .eventDeepLink:
                return "Event Deep Link"
            }
        }
    }
    
    // MARK: - URL Handlers Registry
    
    private var urlHandlers: [String: URLHandler] = [:]
    
    // MARK: - Initialization
    
    init() {
        setupDefaultHandlers()
    }
    
    // MARK: - Public Methods
    
    /// Handle incoming URL
    func handleURL(_ url: URL) -> Bool {
        handlingState = .processing(url)
        lastHandledURL = url
        
        print("🔗 Handling URL: \(url.absoluteString)")
        
        // Validate URL scheme
        guard let scheme = url.scheme,
              let supportedScheme = SupportedScheme(rawValue: scheme) else {
            let error = URLHandlingError.invalidScheme
            handlingState = .failed(url, error: error)
            print("❌ Invalid scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        // Validate URL path
        let path = url.path.isEmpty ? "/" : url.path
        guard let supportedPath = SupportedPath(rawValue: path) else {
            let error = URLHandlingError.unsupportedPath
            handlingState = .failed(url, error: error)
            print("❌ Unsupported path: \(path)")
            return false
        }
        
        // Security validation
        guard performSecurityValidation(url: url) else {
            let error = URLHandlingError.securityValidationFailed
            handlingState = .failed(url, error: error)
            print("❌ Security validation failed for URL")
            return false
        }
        
        // Find and execute handler
        let handlerKey = "\(supportedScheme.rawValue)\(supportedPath.rawValue)"
        
        guard let handler = urlHandlers[handlerKey] else {
            let error = URLHandlingError.handlerNotFound
            handlingState = .failed(url, error: error)
            print("❌ No handler found for: \(handlerKey)")
            return false
        }
        
        // Execute handler
        Task {
            let result = await handler.handle(url)
            
            switch result {
            case .success:
                handlingState = .handled(url, success: true)
                print("✅ Successfully handled URL: \(url.absoluteString)")
                
            case .failure(let error):
                handlingState = .failed(url, error: error)
                print("❌ Failed to handle URL: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    /// Register a custom URL handler
    func registerHandler(scheme: SupportedScheme, path: SupportedPath, handler: URLHandler) {
        let key = "\(scheme.rawValue)\(path.rawValue)"
        urlHandlers[key] = handler
        print("📝 Registered URL handler for: \(key)")
    }
    
    /// Check if URL is supported
    func isSupported(url: URL) -> Bool {
        guard let scheme = url.scheme,
              SupportedScheme(rawValue: scheme) != nil else {
            return false
        }
        
        let path = url.path.isEmpty ? "/" : url.path
        return SupportedPath(rawValue: path) != nil
    }
    
    /// Get URL components for debugging
    func getURLComponents(_ url: URL) -> [String: String] {
        var components: [String: String] = [:]
        components["scheme"] = url.scheme
        components["host"] = url.host
        components["path"] = url.path
        components["fragment"] = url.fragment
        
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                components["query_\(item.name)"] = item.value
            }
        }
        
        return components
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultHandlers() {
        // OAuth Callback Handler
        registerHandler(
            scheme: .blueboxy,
            path: .oauthCallback,
            handler: OAuthCallbackHandler()
        )
        
        // Calendar Connect Handler
        registerHandler(
            scheme: .blueboxy,
            path: .calendarConnect,
            handler: CalendarConnectHandler()
        )
        
        // Event Deep Link Handler
        registerHandler(
            scheme: .blueboxy,
            path: .eventDeepLink,
            handler: EventDeepLinkHandler()
        )
    }
    
    private func performSecurityValidation(url: URL) -> Bool {
        // Basic security checks
        
        // 1. Check for suspicious parameters
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                // Check for script injection attempts
                if let value = item.value, value.contains("<script") || value.contains("javascript:") {
                    return false
                }
            }
        }
        
        // 2. Validate host (if present) - should be empty for our custom scheme
        if let host = url.host, !host.isEmpty {
            // For blueboxy:// scheme, host should be empty
            if url.scheme == "blueboxy" {
                return false
            }
        }
        
        // 3. Check URL length (prevent excessively long URLs)
        if url.absoluteString.count > 2048 {
            return false
        }
        
        return true
    }
}

// MARK: - URL Handler Protocol

protocol URLHandler {
    func handle(_ url: URL) async -> Result<Void, URLSchemeHandler.URLHandlingError>
}

// MARK: - Concrete URL Handlers

/// Handler for OAuth authentication callbacks
struct OAuthCallbackHandler: URLHandler {
    func handle(_ url: URL) async -> Result<Void, URLSchemeHandler.URLHandlingError> {
        guard await OAuthService.isValidCallbackUrl(url) else {
            return .failure(.securityValidationFailed)
        }
        
        // OAuth callback is handled by ASWebAuthenticationSession automatically
        // This handler just validates and logs the callback
        print("✅ OAuth callback validated: \(url.absoluteString)")
        
        return .success(())
    }
}

/// Handler for calendar connection deep links
struct CalendarConnectHandler: URLHandler {
    func handle(_ url: URL) async -> Result<Void, URLSchemeHandler.URLHandlingError> {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return .failure(.missingParameters)
        }
        
        // Extract provider ID if present
        if let providerId = queryItems.first(where: { $0.name == "provider" })?.value {
            print("📅 Calendar connect request for provider: \(providerId)")
            
            // Post notification for the app to handle
            NotificationCenter.default.post(
                name: .calendarConnectRequested,
                object: nil,
                userInfo: ["providerId": providerId]
            )
            
            return .success(())
        }
        
        return .failure(.missingParameters)
    }
}

/// Handler for event deep links
struct EventDeepLinkHandler: URLHandler {
    func handle(_ url: URL) async -> Result<Void, URLSchemeHandler.URLHandlingError> {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return .failure(.missingParameters)
        }
        
        // Extract event ID if present
        if let eventIdString = queryItems.first(where: { $0.name == "id" })?.value,
           let eventId = Int(eventIdString) {
            print("📅 Event deep link for event ID: \(eventId)")
            
            // Post notification for the app to handle
            NotificationCenter.default.post(
                name: .eventDeepLinkRequested,
                object: nil,
                userInfo: ["eventId": eventId]
            )
            
            return .success(())
        }
        
        return .failure(.missingParameters)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let calendarConnectRequested = Notification.Name("CalendarConnectRequested")
    static let eventDeepLinkRequested = Notification.Name("EventDeepLinkRequested")
    static let urlHandlingCompleted = Notification.Name("URLHandlingCompleted")
}

// MARK: - URL Scheme Utilities

extension URLSchemeHandler {
    
    /// Generate a calendar connection URL
    static func generateCalendarConnectURL(providerId: String) -> URL? {
        var components = URLComponents()
        components.scheme = SupportedScheme.blueboxy.rawValue
        components.path = SupportedPath.calendarConnect.rawValue
        components.queryItems = [
            URLQueryItem(name: "provider", value: providerId)
        ]
        
        return components.url
    }
    
    /// Generate an event deep link URL
    static func generateEventDeepLinkURL(eventId: Int) -> URL? {
        var components = URLComponents()
        components.scheme = SupportedScheme.blueboxy.rawValue
        components.path = SupportedPath.eventDeepLink.rawValue
        components.queryItems = [
            URLQueryItem(name: "id", value: String(eventId))
        ]
        
        return components.url
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension URLSchemeHandler {
    
    /// Test URL handling with sample URLs
    func testURLHandling() {
        let testURLs = [
            "blueboxy://oauth/callback?code=abc123&state=xyz789",
            "blueboxy://calendar/connect?provider=google",
            "blueboxy://event?id=123",
            "invalid://test",
            "blueboxy://unsupported/path"
        ]
        
        for urlString in testURLs {
            if let url = URL(string: urlString) {
                print("🧪 Testing URL: \(urlString)")
                let handled = handleURL(url)
                print("   Result: \(handled ? "Handled" : "Not handled")")
            }
        }
    }
}
#endif
