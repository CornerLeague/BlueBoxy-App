//
//  NavigationCoordinator.swift
//  BlueBoxy
//
//  Navigation coordinator for managing app-wide routing and navigation state
//  Handles complex navigation flows, deep linking, and state management
//

import SwiftUI
import Combine

@MainActor
final class NavigationCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentRoute: AppRoute = .onboarding
    @Published var onboardingStep: OnboardingStep = .welcome
    @Published var navigationPath = NavigationPath()
    @Published var navigationState: NavigationState = .idle
    @Published var showingModal: Bool = false
    @Published var modalRoute: AppRoute?
    
    // Tab navigation
    @Published var selectedTab: Int = 0
    @Published var tabRoutes: [AppRoute.MainRoute] = [.dashboard, .messages(.list), .calendar(.main), .profile(nil)]
    
    // Alert and action sheet state
    @Published var showingAlert: Bool = false
    @Published var alertConfig: AlertConfig?
    
    // MARK: - Dependencies
    
    private let sessionStore: SessionStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Navigation History
    
    private var navigationHistory: [AppRoute] = []
    private let maxHistorySize = 10
    
    // MARK: - Initialization
    
    init(sessionStore: SessionStore = SessionStore.shared) {
        self.sessionStore = sessionStore
        setupAuthenticationObservation()
        setupInitialRoute()
    }
    
    // MARK: - Route Navigation
    
    /// Navigate to a specific route
    func navigateTo(_ route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.3)) {
            addToHistory(route)
            currentRoute = route
            
            // Update tab selection if navigating to a main route
            if case .main(let mainRoute) = route {
                updateTabSelection(for: mainRoute)
            }
        }
    }
    
    /// Push a route onto the navigation stack
    func push(_ route: AppRoute) {
        navigationState = .navigating
        navigationPath.append(route)
        addToHistory(route)
    }
    
    /// Pop the current route from the navigation stack
    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    /// Pop to root of the navigation stack
    func popToRoot() {
        navigationPath = NavigationPath()
    }
    
    /// Present a route modally
    func presentModal(_ route: AppRoute) {
        modalRoute = route
        showingModal = true
    }
    
    /// Dismiss the current modal
    func dismissModal() {
        showingModal = false
        modalRoute = nil
    }
    
    // MARK: - Onboarding Navigation
    
    /// Move to next onboarding step
    func nextOnboardingStep() {
        guard let nextStep = onboardingStep.nextStep else {
            completeOnboarding()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            onboardingStep = nextStep
        }
    }
    
    /// Move to previous onboarding step
    func previousOnboardingStep() {
        guard let previousStep = onboardingStep.previousStep else { return }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            onboardingStep = previousStep
        }
    }
    
    /// Skip current onboarding step if allowed
    func skipOnboardingStep() {
        guard onboardingStep.canSkip else { return }
        nextOnboardingStep()
    }
    
    /// Complete onboarding flow
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        navigateTo(.main(.dashboard))
    }
    
    /// Restart onboarding flow
    func restartOnboarding() {
        onboardingStep = .welcome
        navigateTo(.onboarding)
    }
    
    // MARK: - Tab Navigation
    
    /// Switch to a specific tab
    func switchToTab(_ index: Int) {
        guard index < tabRoutes.count else { return }
        
        selectedTab = index
        let route = tabRoutes[index]
        navigateTo(.main(route))
    }
    
    /// Switch to tab by route
    func switchToTab(for route: AppRoute.MainRoute) {
        if let index = tabRoutes.firstIndex(of: route) {
            switchToTab(index)
        }
    }
    
    /// Update tab selection based on main route
    private func updateTabSelection(for mainRoute: AppRoute.MainRoute) {
        // Find the base route for tab selection
        let baseRoute: AppRoute.MainRoute
        switch mainRoute {
        case .messages: baseRoute = .messages(.list)
        case .calendar: baseRoute = .calendar(.main)
        case .profile: baseRoute = .profile(nil)
        case .activities: baseRoute = .activities(.list)
        case .assessment: baseRoute = .assessment(.start)
        case .settings: baseRoute = .settings(.main)
        default: baseRoute = mainRoute
        }
        
        if let index = tabRoutes.firstIndex(of: baseRoute) {
            selectedTab = index
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep link URL
    func handleDeepLink(_ url: URL) {
        guard let route = AppRoute.from(urlString: url.absoluteString) else {
            print("⚠️ Unable to parse deep link: \(url)")
            return
        }
        
        handleDeepLinkRoute(route)
    }
    
    /// Handle deep link from notification or external source
    func handleDeepLink(_ deepLink: DeepLink) {
        let route = deepLink.route
        handleDeepLinkRoute(route)
    }
    
    private func handleDeepLinkRoute(_ route: AppRoute) {
        // Check authentication requirements
        if route.requiresAuthentication && !sessionStore.isAuthenticated {
            // Store the intended route and redirect to auth
            UserDefaults.standard.set(route.urlString, forKey: "pendingDeepLinkRoute")
            navigateTo(.auth(.login))
            return
        }
        
        // Handle the route
        switch route {
        case .onboarding:
            if !hasCompletedOnboarding {
                navigateTo(route)
            } else {
                navigateTo(.main(.dashboard))
            }
        case .auth:
            if !sessionStore.isAuthenticated {
                navigateTo(route)
            } else {
                navigateTo(.main(.dashboard))
            }
        case .main:
            if sessionStore.isAuthenticated {
                navigateTo(route)
            } else {
                navigateTo(.auth(.login))
            }
        }
    }
    
    /// Process pending deep link after authentication
    func processPendingDeepLink() {
        guard let routeString = UserDefaults.standard.string(forKey: "pendingDeepLinkRoute"),
              let route = AppRoute.from(urlString: routeString) else {
            return
        }
        
        UserDefaults.standard.removeObject(forKey: "pendingDeepLinkRoute")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.navigateTo(route)
        }
    }
    
    // MARK: - Navigation History
    
    private func addToHistory(_ route: AppRoute) {
        navigationHistory.append(route)
        
        // Keep history size manageable
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
        }
    }
    
    /// Go back to previous route in history
    func goBack() {
        guard navigationHistory.count > 1 else { return }
        
        // Remove current route
        navigationHistory.removeLast()
        
        // Get previous route
        let previousRoute = navigationHistory.last!
        currentRoute = previousRoute
    }
    
    /// Check if can go back in history
    var canGoBack: Bool {
        return navigationHistory.count > 1
    }
    
    // MARK: - Alert Management
    
    /// Show an alert with configuration
    func showAlert(_ config: AlertConfig) {
        alertConfig = config
        showingAlert = true
    }
    
    /// Show a simple alert
    func showAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let config = AlertConfig(
            title: title,
            message: message,
            primaryButton: AlertConfig.Button(title: "OK", action: action)
        )
        showAlert(config)
    }
    
    /// Show a confirmation alert
    func showConfirmation(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmAction: @escaping () -> Void
    ) {
        let config = AlertConfig(
            title: title,
            message: message,
            primaryButton: AlertConfig.Button(title: confirmTitle, style: .destructive, action: confirmAction),
            secondaryButton: AlertConfig.Button(title: "Cancel", style: .cancel)
        )
        showAlert(config)
    }
    
    // MARK: - Computed Properties
    
    /// Whether user has completed onboarding
    var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    /// Whether current route shows tab bar
    var showsTabBar: Bool {
        return currentRoute.showsTabBar
    }
    
    /// Current navigation title
    var navigationTitle: String {
        return currentRoute.navigationTitle
    }
    
    /// Whether navigation is in loading state
    var isLoading: Bool {
        return navigationState == .loading
    }
    
    // MARK: - Private Setup
    
    private func setupAuthenticationObservation() {
        // Listen for authentication changes
        sessionStore.$isAuthenticated
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                self?.handleAuthenticationChange(isAuthenticated)
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialRoute() {
        // Determine initial route based on authentication and onboarding status
        if sessionStore.isAuthenticated {
            processPendingDeepLink()
            if hasCompletedOnboarding {
                currentRoute = .main(.dashboard)
            } else {
                currentRoute = .onboarding
            }
        } else {
            if hasCompletedOnboarding {
                currentRoute = .auth(.login)
            } else {
                currentRoute = .onboarding
            }
        }
    }
    
    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        if isAuthenticated {
            // User logged in
            if hasCompletedOnboarding {
                navigateTo(.main(.dashboard))
                processPendingDeepLink()
            } else {
                navigateTo(.onboarding)
            }
        } else {
            // User logged out
            navigationPath = NavigationPath()
            navigationHistory.removeAll()
            
            if hasCompletedOnboarding {
                navigateTo(.auth(.login))
            } else {
                navigateTo(.onboarding)
            }
        }
    }
}

// MARK: - Alert Configuration

struct AlertConfig {
    let title: String
    let message: String
    let primaryButton: Button
    let secondaryButton: Button?
    
    init(
        title: String,
        message: String,
        primaryButton: Button,
        secondaryButton: Button? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
    
    struct Button {
        let title: String
        let style: Style
        let action: (() -> Void)?
        
        enum Style {
            case `default`
            case cancel
            case destructive
        }
        
        init(
            title: String,
            style: Style = .default,
            action: (() -> Void)? = nil
        ) {
            self.title = title
            self.style = style
            self.action = action
        }
    }
}

// MARK: - Navigation Extensions

extension NavigationCoordinator {
    
    /// Convenience method for authentication flow navigation
    func navigateToAuth(_ authRoute: AppRoute.AuthRoute = .login) {
        navigateTo(.auth(authRoute))
    }
    
    /// Convenience method for main app navigation
    func navigateToMain(_ mainRoute: AppRoute.MainRoute) {
        navigateTo(.main(mainRoute))
    }
    
    /// Reset navigation state (useful for testing)
    func reset() {
        currentRoute = hasCompletedOnboarding ? .main(.dashboard) : .onboarding
        onboardingStep = .welcome
        navigationPath = NavigationPath()
        navigationState = .idle
        showingModal = false
        modalRoute = nil
        selectedTab = 0
        navigationHistory.removeAll()
    }
}
