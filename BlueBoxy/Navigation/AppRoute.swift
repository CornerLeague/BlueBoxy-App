//
//  AppRoute.swift
//  BlueBoxy
//
//  App-level routing definitions and navigation flows
//  Defines top-level navigation structure with enum-based routing
//

import SwiftUI

// MARK: - Main App Routes

enum AppRoute: Hashable {
    case onboarding
    case auth(AuthRoute)
    case main(MainRoute)
    
    // MARK: - Authentication Routes
    
    enum AuthRoute: Hashable {
        case login
        case register
        case forgotPassword
        case resetPassword(token: String)
        case verifyEmail(email: String)
    }
    
    // MARK: - Main App Routes
    
    enum MainRoute: Hashable {
        case dashboard
        case profile(ProfileRoute?)
        case messages(MessagesRoute?)
        case calendar(CalendarRoute?)
        case activities(ActivitiesRoute?)
        case assessment(AssessmentRoute?)
        case settings(SettingsRoute?)
        case notifications
    }
}

// MARK: - Nested Route Definitions

extension AppRoute {
    
    // MARK: - Profile Routes
    
    enum ProfileRoute: Hashable {
        case edit
        case preferences
        case personalityResults
        case relationshipGoals
        case photos
        case prompts
        case privacy
        case subscription
    }
    
    // MARK: - Messages Routes
    
    enum MessagesRoute: Hashable {
        case list
        case conversation(userId: Int)
        case newMessage
        case templates
        case categories
        case generator(category: String?)
        case history
        case favorites
    }
    
    // MARK: - Calendar Routes
    
    enum CalendarRoute: Hashable {
        case main
        case createEvent
        case editEvent(eventId: Int)
        case eventDetails(eventId: Int)
        case providers
        case syncSettings
        case dateRangePicker
    }
    
    // MARK: - Activities Routes
    
    enum ActivitiesRoute: Hashable {
        case list
        case details(activityId: Int)
        case create
        case edit(activityId: Int)
        case categories
        case history
        case recommendations
        case favorites
        case search
    }
    
    // MARK: - Assessment Routes
    
    enum AssessmentRoute: Hashable {
        case start
        case question(step: Int)
        case results
        case history
        case retake
        case comparison(userId: Int)
        case insights
    }
    
    // MARK: - Settings Routes
    
    enum SettingsRoute: Hashable {
        case main
        case account
        case notifications
        case privacy
        case subscription
        case support
        case about
        case deleteAccount
    }
}

// MARK: - Onboarding Flow

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case personalInfo
    case assessment
    case preferences
    case notifications
    case complete
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to BlueBoxy"
        case .personalInfo: return "Tell us about yourself"
        case .assessment: return "Personality Assessment"
        case .preferences: return "Your Preferences"
        case .notifications: return "Stay Connected"
        case .complete: return "All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome: return "Your personalized dating companion"
        case .personalInfo: return "Help us create your perfect profile"
        case .assessment: return "Discover your unique personality traits"
        case .preferences: return "Set your dating preferences"
        case .notifications: return "Never miss important moments"
        case .complete: return "Ready to find meaningful connections"
        }
    }
    
    var systemImage: String {
        switch self {
        case .welcome: return "heart.fill"
        case .personalInfo: return "person.fill"
        case .assessment: return "brain.head.profile"
        case .preferences: return "slider.horizontal.3"
        case .notifications: return "bell.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var canSkip: Bool {
        switch self {
        case .welcome, .personalInfo, .complete: return false
        case .assessment, .preferences, .notifications: return true
        }
    }
    
    var nextStep: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue + 1)
    }
    
    var previousStep: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue - 1)
    }
}

// MARK: - Navigation State

enum NavigationState: Equatable {
    case idle
    case navigating
    case loading
    case error(String)
}

// MARK: - Deep Link Support

enum DeepLink: Hashable {
    case profile(userId: Int)
    case message(conversationId: Int)
    case event(eventId: Int)
    case activity(activityId: Int)
    case assessment(type: String)
    case notification(notificationId: Int)
    case invite(code: String)
    case resetPassword(token: String)
    case verifyEmail(token: String)
    
    var route: AppRoute {
        switch self {
        case .profile(let userId):
            return .main(.profile(.edit)) // Navigate to edit if it's current user
        case .message(let conversationId):
            return .main(.messages(.conversation(userId: conversationId)))
        case .event(let eventId):
            return .main(.calendar(.eventDetails(eventId: eventId)))
        case .activity(let activityId):
            return .main(.activities(.details(activityId: activityId)))
        case .assessment(let type):
            return .main(.assessment(.start))
        case .notification:
            return .main(.notifications)
        case .invite:
            return .auth(.register)
        case .resetPassword(let token):
            return .auth(.resetPassword(token: token))
        case .verifyEmail(let email):
            return .auth(.verifyEmail(email: email))
        }
    }
}

// MARK: - Route Extensions

extension AppRoute {
    
    /// Whether this route requires authentication
    var requiresAuthentication: Bool {
        switch self {
        case .onboarding, .auth:
            return false
        case .main:
            return true
        }
    }
    
    /// Whether this route should show tab bar
    var showsTabBar: Bool {
        switch self {
        case .main(let mainRoute):
            switch mainRoute {
            case .dashboard, .messages(.list), .calendar(.main), .profile(nil):
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    /// Navigation title for the route
    var navigationTitle: String {
        switch self {
        case .onboarding:
            return "Welcome"
        case .auth(let authRoute):
            return authRoute.title
        case .main(let mainRoute):
            return mainRoute.title
        }
    }
}

extension AppRoute.AuthRoute {
    var title: String {
        switch self {
        case .login: return "Sign In"
        case .register: return "Create Account"
        case .forgotPassword: return "Forgot Password"
        case .resetPassword: return "Reset Password"
        case .verifyEmail: return "Verify Email"
        }
    }
}

extension AppRoute.MainRoute {
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .profile: return "Profile"
        case .messages: return "Messages"
        case .calendar: return "Calendar"
        case .activities: return "Activities"
        case .assessment: return "Assessment"
        case .settings: return "Settings"
        case .notifications: return "Notifications"
        }
    }
    
    var tabBarIcon: String {
        switch self {
        case .dashboard: return "house"
        case .messages: return "message"
        case .calendar: return "calendar"
        case .profile: return "person"
        case .activities: return "heart.circle"
        case .assessment: return "brain.head.profile"
        case .settings: return "gearshape"
        case .notifications: return "bell"
        }
    }
}

// MARK: - URL Handling

extension AppRoute {
    
    /// Convert route to URL string for deep linking
    var urlString: String {
        switch self {
        case .onboarding:
            return "blueboxy://onboarding"
        case .auth(let authRoute):
            return "blueboxy://auth/\(authRoute.urlPath)"
        case .main(let mainRoute):
            return "blueboxy://main/\(mainRoute.urlPath)"
        }
    }
    
    /// Parse URL string into route
    static func from(urlString: String) -> AppRoute? {
        guard let url = URL(string: urlString),
              url.scheme == "blueboxy" else {
            return nil
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        guard let rootPath = pathComponents.first else {
            return .main(.dashboard) // Default route
        }
        
        switch rootPath {
        case "onboarding":
            return .onboarding
        case "auth":
            guard pathComponents.count > 1,
                  let authRoute = AppRoute.AuthRoute.from(path: pathComponents[1], url: url) else {
                return .auth(.login)
            }
            return .auth(authRoute)
        case "main":
            guard pathComponents.count > 1,
                  let mainRoute = AppRoute.MainRoute.from(path: pathComponents[1], url: url) else {
                return .main(.dashboard)
            }
            return .main(mainRoute)
        default:
            return .main(.dashboard)
        }
    }
}

extension AppRoute.AuthRoute {
    var urlPath: String {
        switch self {
        case .login: return "login"
        case .register: return "register"
        case .forgotPassword: return "forgot-password"
        case .resetPassword(let token): return "reset-password?token=\(token)"
        case .verifyEmail(let email): return "verify-email?email=\(email)"
        }
    }
    
    static func from(path: String, url: URL) -> AppRoute.AuthRoute? {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        
        switch path {
        case "login": return .login
        case "register": return .register
        case "forgot-password": return .forgotPassword
        case "reset-password":
            if let token = queryItems?.first(where: { $0.name == "token" })?.value {
                return .resetPassword(token: token)
            }
            return .forgotPassword
        case "verify-email":
            if let email = queryItems?.first(where: { $0.name == "email" })?.value {
                return .verifyEmail(email: email)
            }
            return .login
        default:
            return nil
        }
    }
}

extension AppRoute.MainRoute {
    var urlPath: String {
        switch self {
        case .dashboard: return "dashboard"
        case .profile: return "profile"
        case .messages: return "messages"
        case .calendar: return "calendar"
        case .activities: return "activities"
        case .assessment: return "assessment"
        case .settings: return "settings"
        case .notifications: return "notifications"
        }
    }
    
    static func from(path: String, url: URL) -> AppRoute.MainRoute? {
        switch path {
        case "dashboard": return .dashboard
        case "profile": return .profile(nil)
        case "messages": return .messages(.list)
        case "calendar": return .calendar(.main)
        case "activities": return .activities(.list)
        case "assessment": return .assessment(.start)
        case "settings": return .settings(.main)
        case "notifications": return .notifications
        default:
            return nil
        }
    }
}