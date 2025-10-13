//
//  OnboardingView.swift
//  BlueBoxy
//
//  Comprehensive onboarding flow with multi-step screens, form validation, and smooth transitions
//  Handles user data collection, personality assessment, and preference setup
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var showingLocationPermission = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Progress indicator
                    OnboardingProgressView(
                        currentStep: navigationCoordinator.onboardingStep,
                        geometry: geometry
                    )
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 0) {
                            stepContentView
                                .frame(minHeight: geometry.size.height * 0.7)
                        }
                    }
                    .scrollDisabled(navigationCoordinator.onboardingStep == .assessment && viewModel.isShowingAssessment)
                    
                    // Navigation controls
                    OnboardingNavigationView(
                        canProceed: canProceed,
                        isLoading: viewModel.isLoading,
                        onBack: handleBackAction,
                        onNext: handleNextAction,
                        onSkip: handleSkipAction
                    )
                }
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .alert("Location Permission", isPresented: $showingLocationPermission) {
                Button("Allow") {
                    viewModel.requestLocationPermission()
                }
                Button("Skip", role: .cancel) { }
            } message: {
                Text("Allow BlueBoxy to access your location for better date recommendations in your area.")
            }
            .onChange(of: navigationCoordinator.onboardingStep) { _, newStep in
                viewModel.trackStepChange(to: newStep)
            }
            .task {
                await viewModel.initializeOnboarding()
            }
        }
    }
    
    @ViewBuilder
    private var stepContentView: some View {
        switch navigationCoordinator.onboardingStep {
        case .welcome:
            WelcomeStepView()
                .environmentObject(viewModel)
            
        case .personalInfo:
            PersonalInfoStepView()
                .environmentObject(viewModel)
            
        case .assessment:
            AssessmentStepView()
                .environmentObject(viewModel)
            
        case .preferences:
            PreferencesStepView()
                .environmentObject(viewModel)
            
        case .notifications:
            NotificationStepView()
                .environmentObject(viewModel)
            
        case .complete:
            CompleteStepView()
                .environmentObject(viewModel)
        }
    }
    
    private var canProceed: Bool {
        switch navigationCoordinator.onboardingStep {
        case .welcome:
            return true
        case .personalInfo:
            return viewModel.isPersonalInfoValid
        case .assessment:
            return viewModel.hasCompletedAssessment
        case .preferences:
            return viewModel.hasSetPreferences
        case .notifications:
            return true // Always can proceed, notifications are optional
        case .complete:
            return true
        }
    }
    
    private func handleBackAction() {
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationCoordinator.previousOnboardingStep()
        }
    }
    
    private func handleNextAction() {
        switch navigationCoordinator.onboardingStep {
        case .personalInfo:
            // Validate and save personal info
            Task {
                await viewModel.savePersonalInfo()
                proceedToNextStep()
            }
            
        case .preferences:
            // Request location permission before completing preferences
            if viewModel.shouldRequestLocationPermission {
                showingLocationPermission = true
            } else {
                Task {
                    await viewModel.savePreferences()
                    proceedToNextStep()
                }
            }
            
        case .complete:
            // Complete onboarding and save all data
            Task {
                await viewModel.completeOnboarding()
                navigationCoordinator.completeOnboarding()
            }
            
        default:
            proceedToNextStep()
        }
    }
    
    private func handleSkipAction() {
        guard navigationCoordinator.onboardingStep.canSkip else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationCoordinator.skipOnboardingStep()
        }
    }
    
    private func proceedToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationCoordinator.nextOnboardingStep()
        }
    }
}

// MARK: - Progress View

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    let geometry: GeometryProxy
    
    private var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            GeometryReader { progressGeometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressGeometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
            
            // Step indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(currentStep.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Step icon
                Image(systemName: currentStep.systemImage)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
    }
}

// MARK: - Navigation View

struct OnboardingNavigationView: View {
    let canProceed: Bool
    let isLoading: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack(spacing: 16) {
                // Back button
                if navigationCoordinator.onboardingStep != .welcome {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isLoading)
                } else {
                    // Spacer to maintain layout
                    Color.clear
                        .frame(minWidth: 80, maxHeight: 44)
                }
                
                Spacer()
                
                // Skip button (if applicable)
                if navigationCoordinator.onboardingStep.canSkip {
                    Button("Skip", action: onSkip)
                        .buttonStyle(PlainButtonStyle())
                        .foregroundStyle(.secondary)
                        .disabled(isLoading)
                }
                
                // Next/Complete button
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        
                        Text(buttonTitle)
                        
                        if !isLoading && navigationCoordinator.onboardingStep != .complete {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
    }
    
    private var buttonTitle: String {
        switch navigationCoordinator.onboardingStep {
        case .complete:
            return "Get Started"
        case .notifications:
            return "Finish"
        default:
            return "Continue"
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero animation
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(viewModel.animationScale)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: viewModel.animationScale
                        )
                }
                
                VStack(spacing: 16) {
                    Text("Welcome to BlueBoxy")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Discover personalized activities and strengthen your relationship with AI-powered recommendations.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            
            // Feature highlights
            VStack(spacing: 20) {
                FeatureHighlight(
                    icon: "brain.head.profile",
                    title: "Personality Insights",
                    description: "Understand your dating style with our assessment"
                )
                
                FeatureHighlight(
                    icon: "calendar.badge.plus",
                    title: "Smart Date Planning",
                    description: "Get personalized date ideas and reminders"
                )
                
                FeatureHighlight(
                    icon: "message.badge",
                    title: "Conversation Starters",
                    description: "Never run out of things to talk about"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .onAppear {
            viewModel.startWelcomeAnimation()
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Personal Info Step

struct PersonalInfoStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @FocusState private var focusedField: PersonalInfoField?
    
    enum PersonalInfoField {
        case name, partnerName, relationshipDuration, partnerAge
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("Tell us about yourself")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Help us personalize your BlueBoxy experience")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            
            // Form fields
            VStack(spacing: 20) {
                CustomTextField(
                    title: "Your Name",
                    text: $viewModel.onboardingData.name,
                    placeholder: "Enter your name",
                    isRequired: true,
                    focusState: $focusedField,
                    fieldType: .name
                )
                
                CustomTextField(
                    title: "Partner's Name",
                    text: $viewModel.onboardingData.partnerName,
                    placeholder: "Enter partner's name (optional)",
                    focusState: $focusedField,
                    fieldType: .partnerName
                )
                
                CustomTextField(
                    title: "Relationship Duration",
                    text: $viewModel.onboardingData.relationshipDuration,
                    placeholder: "e.g., 2 years, 6 months",
                    focusState: $focusedField,
                    fieldType: .relationshipDuration
                )
                
                CustomTextField(
                    title: "Partner's Age",
                    text: $viewModel.onboardingData.partnerAge,
                    placeholder: "Enter age (optional)",
                    keyboardType: .numberPad,
                    focusState: $focusedField,
                    fieldType: .partnerAge
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Info note
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                
                Text("Only your name is required. Additional details help us provide better recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isRequired: Bool = false
    var keyboardType: UIKeyboardType = .default
    @FocusState.Binding var focusState: PersonalInfoStepView.PersonalInfoField?
    let fieldType: PersonalInfoStepView.PersonalInfoField
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(CustomTextFieldStyle(isFocused: focusState == fieldType))
                .keyboardType(keyboardType)
                .focused($focusState, equals: fieldType)
                .submitLabel(.next)
                .onSubmit {
                    moveToNextField()
                }
        }
    }
    
    private func moveToNextField() {
        switch fieldType {
        case .name:
            focusState = .partnerName
        case .partnerName:
            focusState = .relationshipDuration
        case .relationshipDuration:
            focusState = .partnerAge
        case .partnerAge:
            focusState = nil
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .stroke(
                        isFocused ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// Using ButtonStyles from Core/DesignSystem/Button+DesignSystem.swift
