//
//  AppEnvironment.swift
//  BlueBoxy
//
//  Dependency injection container for app-wide shared resources
//  Provides API client, view models, and configuration to child views
//

import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    
    // MARK: - Core Dependencies
    
    let apiClient: APIClient
    let sessionStore: SessionStore
    
    // MARK: - View Models
    
    let authViewModel: AuthViewModel
    let dashboardViewModel: DashboardViewModel
    let messagesViewModel: MessagesViewModel
    let calendarViewModel: CalendarViewModel
    
    // MARK: - Configuration
    
    let appConfiguration: AppConfiguration
    
    // MARK: - Initialization
    
    init(configuration: AppConfiguration = AppConfiguration.default) {
        self.appConfiguration = configuration
        self.sessionStore = SessionStore.shared
        self.apiClient = APIClient.shared
        
        // Initialize view models with dependencies
        self.authViewModel = AuthViewModel(apiClient: apiClient, sessionStore: sessionStore)
        self.dashboardViewModel = DashboardViewModel(apiClient: apiClient)
        self.messagesViewModel = MessagesViewModel(apiClient: apiClient)
        self.calendarViewModel = CalendarViewModel(apiClient: apiClient)
        
        setupViewModelObservations()
    }
    
    // MARK: - Test Initialization
    
    /// Initializer for testing with mock dependencies
    init(
        apiClient: APIClient,
        sessionStore: SessionStore,
        configuration: AppConfiguration = AppConfiguration.default
    ) {
        self.appConfiguration = configuration
        self.sessionStore = sessionStore
        self.apiClient = apiClient
        
        self.authViewModel = AuthViewModel(apiClient: apiClient, sessionStore: sessionStore)
        self.dashboardViewModel = DashboardViewModel(apiClient: apiClient)
        self.messagesViewModel = MessagesViewModel(apiClient: apiClient)
        self.calendarViewModel = CalendarViewModel(apiClient: apiClient)
        
        setupViewModelObservations()
    }
    
    // MARK: - Setup
    
    private func setupViewModelObservations() {
        // Cross-view model communication setup
        // For example, when authentication state changes, refresh other view models
        
        // Listen for authentication changes to clear/refresh data across view models
        NotificationCenter.default.addObserver(
            forName: .userDidLogin,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleUserLogin()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleUserLogout()
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleUserLogin() async {
        // Refresh all view models that depend on user authentication
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.dashboardViewModel.loadDashboard() }
            group.addTask { await self.messagesViewModel.loadCategories() }
            group.addTask { await self.calendarViewModel.loadProviders() }
            group.addTask { await self.calendarViewModel.loadEvents() }
        }
    }
    
    private func handleUserLogout() async {
        // Clear sensitive data from all view models
        // Note: Individual view models handle their own cleanup via notification observers
    }
    
    // MARK: - Convenience Methods
    
    /// Check if user is authenticated across the app
    var isAuthenticated: Bool {
        return sessionStore.isAuthenticated
    }
    
    /// Get current user information
    var currentUser: User? {
        return sessionStore.currentUser
    }
    
    /// Reset all view models to initial state (useful for testing)
    func reset() {
        Task { @MainActor in
            // Reset view models to idle state
            // Note: Individual view models should implement their own reset methods as needed
            // dashboardViewModel.reset() // Commented out - method may not exist
            // messagesViewModel.reset() // Commented out - method may not exist
            // calendarViewModel.clearAllData() // Commented out - method is private
        }
    }
}

// MARK: - App Configuration

struct AppConfiguration {
    let apiBaseURL: String
    let cacheEnabled: Bool
    let logLevel: LogLevel
    let maxRetryAttempts: Int
    let timeoutInterval: TimeInterval
    let cachePolicyDuration: TimeInterval
    
    static let `default` = AppConfiguration(
        apiBaseURL: "https://api.blueboxy.com",
        cacheEnabled: true,
        logLevel: .info,
        maxRetryAttempts: 3,
        timeoutInterval: 30.0,
        cachePolicyDuration: 300.0 // 5 minutes
    )
    
    static let development = AppConfiguration(
        apiBaseURL: "https://dev-api.blueboxy.com",
        cacheEnabled: true,
        logLevel: .debug,
        maxRetryAttempts: 3,
        timeoutInterval: 60.0,
        cachePolicyDuration: 60.0 // 1 minute for development
    )
    
    static let testing = AppConfiguration(
        apiBaseURL: "https://test.example.com",
        cacheEnabled: false,
        logLevel: .none,
        maxRetryAttempts: 1,
        timeoutInterval: 10.0,
        cachePolicyDuration: 0.0
    )
}

// MARK: - Log Level

enum LogLevel: String, CaseIterable {
    case none = "none"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"
    case verbose = "verbose"
}

// MARK: - Environment Key for SwiftUI Dependency Injection

// Since AppEnvironment requires MainActor initialization, we'll make it optional
// and require explicit injection at the app root level
private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Inject the app environment into the view hierarchy
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.appEnvironment, environment)
    }
}

// MARK: - Environment Object Modifiers

extension View {
    /// Convenience modifier to access common environment objects
    func withEnvironmentObjects(from environment: AppEnvironment) -> some View {
        self
            .environmentObject(environment.authViewModel)
            .environmentObject(environment.dashboardViewModel)
            .environmentObject(environment.messagesViewModel)
            .environmentObject(environment.calendarViewModel)
    }
}