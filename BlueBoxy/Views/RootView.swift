//
//  RootView.swift
//  BlueBoxy
//
//  Enhanced root view with comprehensive session bootstrap and onboarding flow
//  Handles session restoration, authentication state, and app initialization
//

import SwiftUI
import Combine

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.appEnvironment) var appEnvironment
    
    // Bootstrap state
    @State private var bootstrapState: BootstrapState = .initializing
    @State private var hasCompletedOnboarding = false
    @State private var showingUpdatePrompt = false
    @State private var appUpdateInfo: AppUpdateInfo?
    
    var body: some View {
        ZStack {
            // Main content based on bootstrap state
            Group {
                switch bootstrapState {
                case .initializing:
                    SplashView()
                    
                case .ready:
                    mainContent
                    
                case .error(let error):
                    ErrorView(error: error, onRetry: {
                        Task {
                            await bootstrap()
                        }
                    })
                    
                case .maintenance:
                    MaintenanceView()
                }
            }
            .animation(.easeInOut(duration: 0.4), value: bootstrapState)
            
            // Overlay views
            if showingUpdatePrompt, let updateInfo = appUpdateInfo {
                AppUpdatePromptView(
                    updateInfo: updateInfo,
                    onUpdate: { handleAppUpdate() },
                    onDismiss: { showingUpdatePrompt = false }
                )
            }
        }
        .alert(
            navigationCoordinator.alertConfig?.title ?? "",
            isPresented: $navigationCoordinator.showingAlert
        ) {
            alertButtons
        } message: {
            if let message = navigationCoordinator.alertConfig?.message {
                Text(message)
            }
        }
        .sheet(
            isPresented: $navigationCoordinator.showingModal
        ) {
            if let modalRoute = navigationCoordinator.modalRoute {
                ModalView(route: modalRoute)
            }
        }
        .task {
            await bootstrap()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await refreshAppState()
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if authViewModel.isAuthenticated {
                if hasCompletedOnboarding {
                    authenticatedContent
                } else {
                    OnboardingView()
                }
            } else {
                unauthenticatedContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
    
    @ViewBuilder
    private var authenticatedContent: some View {
        switch navigationCoordinator.currentRoute {
        case .main(let mainRoute):
            MainAppView(route: mainRoute)
        default:
            MainAppView(route: .dashboard)
        }
    }
    
    @ViewBuilder
    private var unauthenticatedContent: some View {
        switch navigationCoordinator.currentRoute {
        case .auth(let authRoute):
            AuthFlowView(route: authRoute)
        case .onboarding:
            OnboardingView()
        default:
            AuthFlowView(route: .login)
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        if let config = navigationCoordinator.alertConfig {
            Button(config.primaryButton.title, role: buttonRole(for: config.primaryButton.style)) {
                config.primaryButton.action?()
            }
            
            if let secondaryButton = config.secondaryButton {
                Button(secondaryButton.title, role: buttonRole(for: secondaryButton.style)) {
                    secondaryButton.action?()
                }
            }
        }
    }
    
    private func buttonRole(for style: AlertConfig.Button.Style) -> ButtonRole? {
        switch style {
        case .cancel: return .cancel
        case .destructive: return .destructive
        case .default: return nil
        }
    }
    
    // MARK: - Bootstrap Logic
    
    @MainActor
    private func bootstrap() async {
        bootstrapState = .initializing
        
        // Step 1: Check app version and maintenance status
        await checkAppStatus()
        
        // Step 2: Initialize core services
        await initializeCoreServices()
        
        // Step 3: Restore user session if available
        await restoreUserSession()
        
        // Step 4: Load user preferences and onboarding status
        await loadUserPreferences()
        
        // Step 5: Check for app updates (non-blocking)
        Task {
            await checkForAppUpdates()
        }
        
        // Step 6: Set initial navigation state
        await determineInitialRoute()
        
        // Mark bootstrap as complete
        bootstrapState = .ready
    }
    
    private func checkAppStatus() async {
        // Check if app is in maintenance mode or needs forced update
        // This would typically call a backend endpoint
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // For now, just proceed normally
        // In production, you might check:
        // - Server maintenance status
        // - Minimum required app version
        // - Feature flags
    }
    
    private func initializeCoreServices() async {
        // Initialize analytics, crash reporting, etc.
        print("🚀 Initializing core services...")
        
        // Initialize any required services
        guard let appEnvironment = appEnvironment else { return }
        await appEnvironment.authViewModel.initializeAuth()
        
        // Set up notification observers
        setupNotificationObservers()
    }
    
    private func restoreUserSession() async {
        print("🔐 Restoring user session...")
        
        // Check if user has a valid session
        guard let appEnvironment = appEnvironment else { return }
        if appEnvironment.sessionStore.isAuthenticated {
            // Attempt to refresh the user session
            await appEnvironment.authViewModel.refreshUser()
            
            // If session is still valid after refresh, load user data
            if appEnvironment.sessionStore.isAuthenticated {
                await loadAuthenticatedUserData()
            }
        }
    }
    
    private func loadAuthenticatedUserData() async {
        print("📊 Loading authenticated user data...")
        
        // Load essential user data in parallel
        guard let appEnvironment = appEnvironment else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await appEnvironment.dashboardViewModel.loadDashboard()
            }
            
            group.addTask {
                await appEnvironment.messagesViewModel.loadCategories()
            }
            
            group.addTask {
                await appEnvironment.calendarViewModel.loadProviders()
            }
        }
    }
    
    private func loadUserPreferences() async {
        print("⚙️ Loading user preferences...")
        
        // Load onboarding status
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Load other user preferences
        loadAppPreferences()
    }
    
    private func loadAppPreferences() {
        // Load theme preferences
        if let themeName = UserDefaults.standard.string(forKey: "selectedTheme") {
            // Apply theme
            print("🎨 Applying theme: \(themeName)")
        }
        
        // Load notification preferences
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        print("🔔 Notifications enabled: \(notificationsEnabled)")
        
        // Load other app-wide preferences
    }
    
    private func checkForAppUpdates() async {
        // Check app store for available updates
        // This is non-blocking and runs in the background
        
        do {
            // Simulate checking for updates
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // For demo purposes, randomly show update prompt
            if Bool.random() && Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10) < 2 {
                appUpdateInfo = AppUpdateInfo(
                    version: "2.1.0",
                    releaseNotes: "• New personality insights\n• Improved date recommendations\n• Bug fixes and performance improvements",
                    isRequired: false
                )
                showingUpdatePrompt = true
            }
        } catch {
            print("⚠️ Failed to check for app updates: \(error)")
        }
    }
    
    private func determineInitialRoute() async {
        guard let appEnvironment = appEnvironment else { return }
        if appEnvironment.sessionStore.isAuthenticated {
            if hasCompletedOnboarding {
                // Check for pending deep links
                navigationCoordinator.processPendingDeepLink()
                
                // Navigate to main app
                if navigationCoordinator.currentRoute.requiresAuthentication {
                    // Already on a valid authenticated route
                } else {
                    navigationCoordinator.navigateTo(.main(.dashboard))
                }
            } else {
                navigationCoordinator.navigateTo(.onboarding)
            }
        } else {
            if hasCompletedOnboarding {
                // After completing onboarding, direct users to signup instead of login
                navigationCoordinator.navigateTo(.auth(.register))
            } else {
                navigationCoordinator.navigateTo(.onboarding)
            }
        }
    }
    
    private func refreshAppState() async {
        // Called when app returns to foreground
        guard let appEnvironment = appEnvironment else { return }
        if appEnvironment.sessionStore.isAuthenticated {
            // Refresh session validity
            let isStillValid = await appEnvironment.sessionStore.refreshSessionIfNeeded()
            
            if !isStillValid {
                // Session expired, redirect to appropriate auth screen based on onboarding status
                let authRoute: AppRoute.AuthRoute = hasCompletedOnboarding ? .register : .login
                navigationCoordinator.navigateToAuth(authRoute)
            } else {
                // Refresh critical data
                await appEnvironment.dashboardViewModel.loadDashboard()
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for authentication state changes
        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    await loadAuthenticatedUserData()
                    // Navigate to main app after successful authentication
                    await navigateToMainAppAfterAuth()
                }
            }
            .store(in: &cancellables)
        
        // Listen for new user registrations
        NotificationCenter.default.publisher(for: .userDidRegister)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                Task {
                    // Refresh onboarding state from UserDefaults (registration clears this flag)
                    await refreshOnboardingState()
                    await loadAuthenticatedUserData()
                    // Navigate to onboarding for new registrations
                    await navigateToOnboardingAfterRegistration()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // Clear cached data and reset state
                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            }
            .store(in: &cancellables)
    }
    
    private func handleAppUpdate() {
        // Handle app update action
        if let updateInfo = appUpdateInfo {
            if updateInfo.isRequired {
                // Force update - redirect to App Store
                openAppStore()
            } else {
                // Optional update - redirect to App Store
                openAppStore()
            }
        }
        showingUpdatePrompt = false
    }
    
    private func openAppStore() {
        // Open App Store for update
        if let url = URL(string: "https://apps.apple.com/app/blueboxy/id123456789") {
            UIApplication.shared.open(url)
        }
    }
    
    @MainActor
    private func navigateToMainAppAfterAuth() async {
        // Navigate to main app after successful authentication
        if hasCompletedOnboarding {
            navigationCoordinator.navigateTo(.main(.dashboard))
            print("🎯 Navigated to main dashboard after authentication")
        } else {
            navigationCoordinator.navigateTo(.onboarding)
            print("🎯 Navigated to onboarding after authentication")
        }
    }
    
    @MainActor
    private func refreshOnboardingState() async {
        // Refresh the onboarding completion state from UserDefaults
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("🔄 Refreshed onboarding state: hasCompletedOnboarding = \(hasCompletedOnboarding)")
    }
    
    @MainActor
    private func navigateToOnboardingAfterRegistration() async {
        // Always navigate new registrations to onboarding
        // The registration process clears the hasCompletedOnboarding flag
        navigationCoordinator.navigateTo(.onboarding)
        print("🎯 Navigated new registration to onboarding flow")
    }
    
    // Store cancellables
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Onboarding Flow View

struct OnboardingFlowView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack {
            OnboardingStepView(step: navigationCoordinator.onboardingStep)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
        }
    }
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress indicator
            ProgressView(
                value: Double(step.rawValue),
                total: Double(OnboardingStep.allCases.count - 1)
            )
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.horizontal)
            
            Spacer()
            
            // Step icon
            Image(systemName: step.systemImage)
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            // Step content
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Step-specific content
            stepContent
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding()
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            // Welcome content
            VStack(spacing: 16) {
                Text("Find meaningful connections with personalized date ideas and conversation starters.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("✨ AI-powered matching")
                Text("📅 Smart date planning") 
                Text("💬 Conversation assistance")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
        case .personalInfo:
            // Personal info form placeholder
            Text("We'll help you create an amazing profile that showcases your unique personality.")
                .multilineTextAlignment(.center)
                .padding()
            
        case .assessment:
            // Assessment preview
            VStack(spacing: 12) {
                Text("Discover your dating style with our scientifically-backed personality assessment.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("⚡ Takes 5 minutes")
                Text("🧠 Backed by psychology")
                Text("🎯 Improves your matches")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
        case .preferences:
            // Preferences selection placeholder
            Text("Set your preferences for the perfect match and ideal date experiences.")
                .multilineTextAlignment(.center)
                .padding()
            
        case .notifications:
            // Notification permissions
            VStack(spacing: 16) {
                Text("Stay updated with match notifications, date reminders, and conversation tips.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Enable Notifications") {
                    // Request notification permissions
                }
                .buttonStyle(.borderedProminent)
            }
            
        case .complete:
            // Completion confirmation
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 48))
                
                Text("You're all set to start your dating journey!")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if step != .welcome {
                Button("Back") {
                    navigationCoordinator.previousOnboardingStep()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            // Skip button
            if step.canSkip {
                Button("Skip") {
                    navigationCoordinator.skipOnboardingStep()
                }
                .buttonStyle(.plain)
            }
            
            // Next/Complete button
            Button(step == .complete ? "Get Started" : "Continue") {
                if step == .complete {
                    navigationCoordinator.completeOnboarding()
                } else {
                    navigationCoordinator.nextOnboardingStep()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}


// MARK: - Main App View

struct MainAppView: View {
    let route: AppRoute.MainRoute
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            ForEach(Array(navigationCoordinator.tabRoutes.enumerated()), id: \.offset) { index, tabRoute in
                NavigationStack(path: $navigationCoordinator.navigationPath) {
                    mainContent(for: tabRoute)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Label(tabRoute.title, systemImage: tabRoute.tabBarIcon)
                }
                .tag(index)
            }
        }
        .tint(.blue)
    }
    
    @ViewBuilder
    private func mainContent(for route: AppRoute.MainRoute) -> some View {
        switch route {
        case .dashboard:
            DashboardView()
        case .messages(_):
            MessagesView()
        case .calendar(_):
            CalendarMainView()
        case .profile(_):
            ProfileView()
        case .activities(_):
            ActivitiesView()
        case .assessment(_):
            AssessmentView()
        case .settings(_):
            SettingsPlaceholderView()
        case .notifications:
            NotificationsPlaceholderView()
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .main(let mainRoute):
            mainContent(for: mainRoute)
        default:
            EmptyView()
        }
    }
}

// MARK: - Modal View

struct ModalView: View {
    let route: AppRoute
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack {
            modalContent
                .navigationTitle(route.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            navigationCoordinator.dismissModal()
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private var modalContent: some View {
        switch route {
        case .main(let mainRoute):
            switch mainRoute {
            case .calendar(.createEvent):
                CreateEventView()
            case .messages(.newMessage):
                NewMessageView()
            case .activities(.create):
                CreateActivityView()
            default:
                Text("Modal Content Coming Soon")
                    .foregroundColor(.secondary)
            }
        default:
            Text("Modal Content Coming Soon")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Modal-specific Views

struct CreateEventView: View {
    var body: some View { 
        VStack(spacing: 20) {
            Text("Create Event")
                .font(.title)
                .fontWeight(.semibold)
            Text("Plan your perfect date")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct NewMessageView: View {
    var body: some View { 
        VStack(spacing: 20) {
            Text("New Message")
                .font(.title)
                .fontWeight(.semibold)
            Text("Generate the perfect conversation starter")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct CreateActivityView: View {
    var body: some View { 
        VStack(spacing: 20) {
            Text("Create Activity")
                .font(.title)
                .fontWeight(.semibold)
            Text("Discover new date ideas")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Placeholder Views

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .fontWeight(.semibold)
            Text("Settings view coming soon")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct NotificationsPlaceholderView: View {
    var body: some View {
        VStack {
            Text("Notifications")
                .font(.title)
                .fontWeight(.semibold)
            Text("Notifications view coming soon")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
