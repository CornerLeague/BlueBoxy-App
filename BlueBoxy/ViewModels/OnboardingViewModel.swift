//
//  OnboardingViewModel.swift
//  BlueBoxy
//
//  Onboarding view model for managing state and business logic
//  Handles data collection, validation, API calls, and progression logic
//

import SwiftUI
import CoreLocation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var onboardingData = OnboardingData()
    @Published var isLoading = false
    @Published var animationScale: CGFloat = 1.0
    @Published var isShowingAssessment = false
    @Published var currentQuestionIndex = 0
    @Published var assessmentProgress: Double = 0.0
    @Published var hasRequestedLocationPermission = false
    @Published var hasRequestedNotificationPermission = false
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    private let onboardingService: OnboardingService
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let assessmentQuestions = AssessmentData.questions
    private let maxRetries = 3
    
    // MARK: - Initialization
    
    init(apiClient: APIClient = APIClient.shared, onboardingService: OnboardingService? = nil) {
        self.apiClient = apiClient
        self.onboardingService = onboardingService ?? OnboardingService(apiClient: apiClient)
        setupLocationManager()
    }
    
    // MARK: - Computed Properties
    
    var isPersonalInfoValid: Bool {
        return !onboardingData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasCompletedAssessment: Bool {
        return onboardingData.hasCompletedAssessment
    }
    
    var hasSetPreferences: Bool {
        return onboardingData.hasSetPreferences
    }
    
    var shouldRequestLocationPermission: Bool {
        return !hasRequestedLocationPermission && 
               locationManager.authorizationStatus == .notDetermined
    }
    
    var shouldRequestNotificationPermission: Bool {
        return !hasRequestedNotificationPermission
    }
    
    var currentQuestion: AssessmentQuestion? {
        guard currentQuestionIndex < assessmentQuestions.count else { return nil }
        return assessmentQuestions[currentQuestionIndex]
    }
    
    var assessmentTitle: String {
        if currentQuestionIndex >= assessmentQuestions.count {
            return "Assessment Complete!"
        }
        return "Question \(currentQuestionIndex + 1) of \(assessmentQuestions.count)"
    }
    
    // MARK: - Lifecycle Methods
    
    func initializeOnboarding() async {
        // Load any saved onboarding data
        loadSavedData()
        
        // Initialize analytics
        trackOnboardingStart()
    }
    
    func trackStepChange(to step: OnboardingStep) {
        // Track analytics for step progression
        print("📊 Onboarding step: \(step.title)")
        
        // Update assessment state if entering assessment
        if step == .assessment {
            isShowingAssessment = true
            resetAssessment()
        } else {
            isShowingAssessment = false
        }
    }
    
    // MARK: - Welcome Step
    
    func startWelcomeAnimation() {
        // Start the breathing animation for the heart icon
        animationScale = 1.1
    }
    
    // MARK: - Personal Info Step
    
    func savePersonalInfo() async {
        guard isPersonalInfoValid else {
            print("⚠️ Personal info validation failed")
            return
        }
        
        isLoading = true
        
        do {
            // Save personal info locally for persistence
            UserDefaults.standard.set(onboardingData.name, forKey: "onboarding.name")
            UserDefaults.standard.set(onboardingData.partnerName, forKey: "onboarding.partnerName")
            UserDefaults.standard.set(onboardingData.relationshipDuration, forKey: "onboarding.relationshipDuration")
            UserDefaults.standard.set(onboardingData.partnerAge, forKey: "onboarding.partnerAge")
            
            // Submit personal info to backend immediately
            try await onboardingService.updateUserProfile(from: onboardingData)
            
            print("✅ Personal info saved successfully")
        } catch {
            print("❌ Failed to save personal info: \(error)")
            // Note: We continue with onboarding even if backend submission fails
            // Data will be re-submitted during final completion
        }
        
        isLoading = false
    }
    
    // MARK: - Assessment Step
    
    func resetAssessment() {
        currentQuestionIndex = 0
        assessmentProgress = 0.0
        onboardingData.assessmentResponses.removeAll()
        onboardingData.personalityType = ""
    }
    
    func selectAssessmentAnswer(_ answer: String) {
        guard let question = currentQuestion else { return }
        
        // Save the answer
        onboardingData.assessmentResponses[question.id] = answer
        
        // Move to next question or complete assessment
        if currentQuestionIndex < assessmentQuestions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
                assessmentProgress = Double(currentQuestionIndex) / Double(assessmentQuestions.count)
            }
        } else {
            // Complete assessment
            completeAssessment()
        }
    }
    
    private func completeAssessment() {
        // Calculate personality type based on responses
        onboardingData.personalityType = calculatePersonalityType()
        
        // Update progress to 100%
        withAnimation(.easeInOut(duration: 0.5)) {
            assessmentProgress = 1.0
        }
        
        // Save assessment results
        Task {
            await saveAssessmentResults()
        }
        
        print("✅ Assessment completed: \(onboardingData.personalityType)")
    }
    
    private func calculatePersonalityType() -> String {
        let responses = onboardingData.assessmentResponses
        
        // Simplified personality type calculation
        // In production, this would use a more sophisticated algorithm
        
        var scores = [String: Int]()
        
        for (questionId, answer) in responses {
            if let question = assessmentQuestions.first(where: { $0.id == questionId }) {
                // Map answers to personality traits
                switch questionId {
                case "communication":
                    if answer.contains("Deep") || answer.contains("meaningful") {
                        scores["thoughtful", default: 0] += 2
                    } else if answer.contains("Quick") || answer.contains("actions") {
                        scores["practical", default: 0] += 2
                    }
                    
                case "activities":
                    if answer.contains("Quiet") || answer.contains("intimate") {
                        scores["thoughtful", default: 0] += 2
                    } else if answer.contains("Adventures") || answer.contains("Social") {
                        scores["adventurous", default: 0] += 2
                    } else if answer.contains("Practical") {
                        scores["practical", default: 0] += 2
                    }
                    
                case "stress":
                    if answer.contains("Talk") || answer.contains("immediately") {
                        scores["direct", default: 0] += 1
                    } else if answer.contains("time to process") {
                        scores["thoughtful", default: 0] += 1
                    } else if answer.contains("solutions") {
                        scores["practical", default: 0] += 1
                    }
                    
                default:
                    break
                }
            }
        }
        
        // Determine dominant personality type
        let dominantType = scores.max { $0.value < $1.value }?.key ?? "balanced"
        
        switch dominantType {
        case "thoughtful":
            return "Thoughtful Harmonizer"
        case "adventurous":
            return "Adventure Seeker"
        case "practical":
            return "Practical Supporter"
        case "direct":
            return "Direct Communicator"
        default:
            return "Balanced Explorer"
        }
    }
    
    private func saveAssessmentResults() async {
        // Save assessment results locally
        let assessmentData = [
            "responses": onboardingData.assessmentResponses,
            "personalityType": onboardingData.personalityType,
            "completedAt": ISO8601DateFormatter().string(from: Date())
        ] as [String: Any]
        
        UserDefaults.standard.set(assessmentData, forKey: "onboarding.assessment")
        
        // Submit assessment results to backend
        do {
            try await onboardingService.submitAssessment(from: onboardingData)
            print("✅ Assessment results submitted to backend")
        } catch {
            print("❌ Failed to submit assessment results: \(error)")
            // Continue with onboarding - will retry during final completion
        }
    }
    
    // MARK: - Preferences Step
    
    func updatePreferences(_ preferences: [String: Any]) {
        onboardingData.preferences = preferences
    }
    
    func savePreferences() async {
        isLoading = true
        
        do {
            // Save preferences locally
            UserDefaults.standard.set(onboardingData.preferences, forKey: "onboarding.preferences")
            
            // Submit preferences to backend
            try await onboardingService.savePreferences(from: onboardingData)
            
            print("✅ Preferences saved successfully")
        } catch {
            print("❌ Failed to save preferences: \(error)")
            // Continue with onboarding - will retry during final completion
        }
        
        isLoading = false
    }
    
    // MARK: - Location Permission
    
    func requestLocationPermission() {
        hasRequestedLocationPermission = true
        locationManager.requestWhenInUseAuthorization()
        
        // Get current location if authorized
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = LocationManagerDelegate(viewModel: self)
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
    }
    
    func handleLocationUpdate(_ location: CLLocation) {
        onboardingData.location = GeoLocationPayload(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        print("📍 Location updated: \(location.coordinate)")
    }
    
    // MARK: - Notification Permission
    
    func requestNotificationPermission() async {
        hasRequestedNotificationPermission = true
        
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ Notification permission granted")
                
                // Schedule welcome notification
                await scheduleWelcomeNotification()
            } else {
                print("❌ Notification permission denied")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }
    
    private func scheduleWelcomeNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Welcome to BlueBoxy! 💙"
        content.body = "Ready to discover your perfect date ideas? Let's get started!"
        content.sound = .default
        
        // Schedule for 1 hour from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "welcome", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Welcome notification scheduled")
        } catch {
            print("❌ Failed to schedule welcome notification: \(error)")
        }
    }
    
    // MARK: - Completion
    
    func completeOnboarding() async {
        isLoading = true
        
        do {
            // Validate onboarding data before submission
            try onboardingData.validateForSubmission()
            
            // Print data summary for logging
            print(onboardingData.generateSummary())
            
            // Submit all onboarding data to backend
            try await onboardingService.submitOnboardingData(onboardingData)
            
            // Save completion data locally
            let completionData = [
                "name": onboardingData.name,
                "partnerName": onboardingData.partnerName,
                "relationshipDuration": onboardingData.relationshipDuration,
                "partnerAge": onboardingData.partnerAge,
                "personalityType": onboardingData.personalityType,
                "preferences": onboardingData.preferences,
                "location": onboardingData.location?.toDictionary() ?? [:],
                "completedAt": ISO8601DateFormatter().string(from: Date())
            ] as [String: Any]
            
            UserDefaults.standard.set(completionData, forKey: "onboarding.completed")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            print("🎉 Onboarding completed successfully!")
            
            // Track completion analytics
            trackOnboardingComplete()
            
        } catch {
            print("❌ Failed to complete onboarding: \(error)")
            // Note: We still mark onboarding as completed locally to avoid blocking the user
            // They can update their profile later if needed
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        
        isLoading = false
    }
    
    // MARK: - Data Persistence
    
    private func loadSavedData() {
        // Load saved personal info
        onboardingData.name = UserDefaults.standard.string(forKey: "onboarding.name") ?? ""
        onboardingData.partnerName = UserDefaults.standard.string(forKey: "onboarding.partnerName") ?? ""
        onboardingData.relationshipDuration = UserDefaults.standard.string(forKey: "onboarding.relationshipDuration") ?? ""
        onboardingData.partnerAge = UserDefaults.standard.string(forKey: "onboarding.partnerAge") ?? ""
        
        // Load saved assessment
        if let assessmentData = UserDefaults.standard.dictionary(forKey: "onboarding.assessment") {
            onboardingData.assessmentResponses = assessmentData["responses"] as? [String: String] ?? [:]
            onboardingData.personalityType = assessmentData["personalityType"] as? String ?? ""
        }
        
        // Load saved preferences
        if let preferences = UserDefaults.standard.dictionary(forKey: "onboarding.preferences") {
            onboardingData.preferences = preferences
        }
    }
    
    private func trackOnboardingStart() {
        // Analytics tracking
        print("📊 Onboarding started")
    }
    
    private func trackOnboardingComplete() {
        // Analytics tracking
        print("📊 Onboarding completed with personality type: \(onboardingData.personalityType)")
    }
}

// MARK: - Location Manager Delegate

private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    weak var viewModel: OnboardingViewModel?
    
    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            viewModel?.handleLocationUpdate(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                print("📍 Location permission denied")
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Onboarding Data

struct OnboardingData {
    var name: String = ""
    var partnerName: String = ""
    var relationshipDuration: String = ""
    var partnerAge: String = ""
    var assessmentResponses: [String: String] = [:]
    var personalityType: String = ""
    var preferences: [String: Any] = [:]
    var location: GeoLocationPayload?
    
    var hasCompletedAssessment: Bool {
        return !assessmentResponses.isEmpty && !personalityType.isEmpty
    }
    
    var hasSetPreferences: Bool {
        return !preferences.isEmpty
    }
}

// MARK: - Assessment Data

struct AssessmentData {
    static let questions = [
        AssessmentQuestion(
            id: "communication",
            text: "How do you prefer to communicate with your partner?",
            type: .singleChoice,
            options: [
                AssessmentOption(id: "deep", text: "Deep, meaningful conversations"),
                AssessmentOption(id: "quick", text: "Quick check-ins throughout the day"),
                AssessmentOption(id: "actions", text: "Through actions rather than words"),
                AssessmentOption(id: "situational", text: "Depends on the situation")
            ],
            category: "communication"
        ),
        AssessmentQuestion(
            id: "activities",
            text: "What type of activities do you enjoy most together?",
            type: .singleChoice,
            options: [
                AssessmentOption(id: "intimate", text: "Quiet, intimate settings"),
                AssessmentOption(id: "adventure", text: "Adventures and new experiences"),
                AssessmentOption(id: "social", text: "Social gatherings with friends"),
                AssessmentOption(id: "practical", text: "Practical projects at home")
            ],
            category: "activities"
        ),
        AssessmentQuestion(
            id: "stress",
            text: "How do you handle relationship stress?",
            type: .singleChoice,
            options: [
                AssessmentOption(id: "immediate", text: "Talk it through immediately"),
                AssessmentOption(id: "process", text: "Take time to process alone first"),
                AssessmentOption(id: "advice", text: "Seek advice from friends/family"),
                AssessmentOption(id: "solutions", text: "Focus on finding solutions")
            ],
            category: "stress"
        ),
        AssessmentQuestion(
            id: "romance",
            text: "What makes you feel most loved and appreciated?",
            type: .singleChoice,
            options: [
                AssessmentOption(id: "words", text: "Words of affirmation and compliments"),
                AssessmentOption(id: "touch", text: "Physical touch and closeness"),
                AssessmentOption(id: "time", text: "Quality time together"),
                AssessmentOption(id: "gestures", text: "Thoughtful gestures and surprises")
            ],
            category: "romance"
        ),
        AssessmentQuestion(
            id: "conflict",
            text: "When you disagree with your partner, you typically:",
            type: .singleChoice,
            options: [
                AssessmentOption(id: "direct", text: "Address it immediately and directly"),
                AssessmentOption(id: "cooldown", text: "Take time to cool down first"),
                AssessmentOption(id: "compromise", text: "Try to find a compromise quickly"),
                AssessmentOption(id: "avoid", text: "Avoid confrontation if possible")
            ],
            category: "conflict"
        )
    ]
}

// Using AssessmentQuestion from Models/AssessmentModels.swift

// MARK: - Extensions

private extension GeoLocationPayload {
    func toDictionary() -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude
        ]
    }
}
