//
//  OnboardingStepViews.swift
//  BlueBoxy
//
//  Additional onboarding step views for assessment, preferences, and notifications
//  Implements interactive personality assessment, preference selection, and permission requests
//

import SwiftUI

// MARK: - Assessment Step View

struct AssessmentStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("Personality Assessment")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Help us understand your dating style and preferences")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            
            if viewModel.hasCompletedAssessment {
                // Assessment completed view
                AssessmentCompletedView(insight: nil, onSubmit: {}, isSubmitting: false)
                    .environmentObject(viewModel)
            } else {
                // Assessment questions
                AssessmentQuestionsView()
                    .environmentObject(viewModel)
            }
            
            Spacer()
        }
    }
}

struct AssessmentQuestionsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedAnswerIndex: Int?
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.assessmentTitle)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                ProgressView(value: viewModel.assessmentProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2.0)
            }
            .padding(.horizontal, 24)
            
            // Current question
            if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    Text(question.text)
                        .font(.headline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // Answer options
                    VStack(spacing: 12) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            AssessmentOptionButton(
                                option: option.text,
                                isSelected: selectedAnswerIndex == index,
                                action: {
                                    selectedAnswerIndex = index
                                    
                                    // Add slight delay for visual feedback
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        viewModel.selectAssessmentAnswer(option.text)
                                        selectedAnswerIndex = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
}

struct AssessmentOptionButton: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .blue : Color.gray.opacity(0.1))
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


struct PersonalityDescriptionView: View {
    let personalityType: String
    
    private var description: String {
        switch personalityType {
        case "Thoughtful Harmonizer":
            return "You value deep connections and meaningful conversations. You prefer intimate settings and thoughtful approaches to relationships."
        case "Adventure Seeker":
            return "You thrive on new experiences and exciting activities. You enjoy exploring the world together and creating memorable adventures."
        case "Practical Supporter":
            return "You focus on building strong foundations through practical actions. You show love through helpful gestures and reliable support."
        case "Direct Communicator":
            return "You believe in open, honest communication. You address issues head-on and value transparency in your relationships."
        case "Balanced Explorer":
            return "You adapt well to different situations and enjoy variety in your relationships. You're flexible and open to new experiences."
        default:
            return "You have a unique approach to relationships that combines different styles depending on the situation."
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("About Your Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Preferences Step View

struct PreferencesStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedBudget = "medium"
    @State private var selectedActivities: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var preferredTimeOfDay: Set<String> = []
    
    private let budgetOptions = [
        ("low", "Budget-Friendly", "$"),
        ("medium", "Moderate", "$$"),
        ("high", "Premium", "$$$")
    ]
    
    private let activityTypes = [
        ("dining", "Dining", "fork.knife"),
        ("outdoor", "Outdoor", "leaf"),
        ("cultural", "Cultural", "building.columns"),
        ("active", "Active", "figure.run"),
        ("relaxed", "Relaxed", "sofa"),
        ("social", "Social", "person.2")
    ]
    
    private let locationTypes = [
        ("indoor", "Indoor", "house"),
        ("outdoor", "Outdoor", "sun.max"),
        ("home", "At Home", "house.lodge"),
        ("travel", "Travel", "airplane")
    ]
    
    private let timeOptions = [
        ("morning", "Morning", "sun.rise"),
        ("afternoon", "Afternoon", "sun.max"),
        ("evening", "Evening", "sun.and.horizon"),
        ("night", "Night", "moon.stars")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Your Preferences")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tell us what you enjoy so we can personalize your recommendations")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                
                // Budget preference
                PreferenceSectionView(title: "Budget Range", icon: "creditcard") {
                    HStack(spacing: 12) {
                        ForEach(budgetOptions, id: \.0) { value, label, symbol in
                            BudgetOptionButton(
                                value: value,
                                label: label,
                                symbol: symbol,
                                isSelected: selectedBudget == value,
                                action: { selectedBudget = value }
                            )
                        }
                    }
                }
                
                // Activity types
                PreferenceSectionView(title: "Activity Types", icon: "heart.circle") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(activityTypes, id: \.0) { value, label, icon in
                            PreferenceTagButton(
                                value: value,
                                label: label,
                                icon: icon,
                                isSelected: selectedActivities.contains(value),
                                action: { toggleSelection(&selectedActivities, value) }
                            )
                        }
                    }
                }
                
                // Location preferences
                PreferenceSectionView(title: "Location Preferences", icon: "location") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(locationTypes, id: \.0) { value, label, icon in
                            PreferenceTagButton(
                                value: value,
                                label: label,
                                icon: icon,
                                isSelected: selectedLocations.contains(value),
                                action: { toggleSelection(&selectedLocations, value) }
                            )
                        }
                    }
                }
                
                // Time preferences
                PreferenceSectionView(title: "Preferred Time", icon: "clock") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(timeOptions, id: \.0) { value, label, icon in
                            PreferenceTagButton(
                                value: value,
                                label: label,
                                icon: icon,
                                isSelected: preferredTimeOfDay.contains(value),
                                action: { toggleSelection(&preferredTimeOfDay, value) }
                            )
                        }
                    }
                }
                
                // Minimum selections note
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    
                    Text("Select at least one option from each category for personalized recommendations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: selectedBudget) { _, _ in updatePreferences() }
        .onChange(of: selectedActivities) { _, _ in updatePreferences() }
        .onChange(of: selectedLocations) { _, _ in updatePreferences() }
        .onChange(of: preferredTimeOfDay) { _, _ in updatePreferences() }
        .onAppear {
            loadSavedPreferences()
        }
    }
    
    private func toggleSelection(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
    
    private func updatePreferences() {
        let preferences: [String: Any] = [
            "budget": selectedBudget,
            "activityTypes": Array(selectedActivities),
            "locationTypes": Array(selectedLocations),
            "timeOfDay": Array(preferredTimeOfDay)
        ]
        
        viewModel.updatePreferences(preferences)
    }
    
    private func loadSavedPreferences() {
        if let preferences = viewModel.onboardingData.preferences as? [String: Any] {
            selectedBudget = preferences["budget"] as? String ?? "medium"
            selectedActivities = Set(preferences["activityTypes"] as? [String] ?? [])
            selectedLocations = Set(preferences["locationTypes"] as? [String] ?? [])
            preferredTimeOfDay = Set(preferences["timeOfDay"] as? [String] ?? [])
        }
    }
}

struct PreferenceSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            
            content
                .padding(.horizontal, 24)
        }
    }
}

struct BudgetOptionButton: View {
    let value: String
    let label: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(symbol)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .blue : Color.gray.opacity(0.1))
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PreferenceTagButton: View {
    let value: String
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? .blue : Color.gray.opacity(0.1))
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Step View

struct NotificationStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showingPermissionRequest = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon and title
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
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "bell.badge")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 16) {
                    Text("Stay Connected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Get personalized date reminders, conversation tips, and relationship insights delivered right to your device.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            
            // Benefits list
            VStack(spacing: 16) {
                NotificationBenefit(
                    icon: "calendar.badge.plus",
                    title: "Date Reminders",
                    description: "Never miss a special date or planned activity"
                )
                
                NotificationBenefit(
                    icon: "lightbulb",
                    title: "Smart Suggestions",
                    description: "Get personalized date ideas based on your preferences"
                )
                
                NotificationBenefit(
                    icon: "heart.text.square",
                    title: "Relationship Tips",
                    description: "Receive helpful advice to strengthen your connection"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button("Enable Notifications") {
                    Task {
                        await viewModel.requestNotificationPermission()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading)
                
                Button("Maybe Later") {
                    // User can skip notifications
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct NotificationBenefit: View {
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

// MARK: - Complete Step View

struct CompleteStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success celebration
            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 80))
                
                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Welcome to your personalized BlueBoxy experience")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Summary cards
            VStack(spacing: 16) {
                OnboardingSummaryCard(
                    icon: "person.circle",
                    title: "Profile Created",
                    detail: viewModel.onboardingData.name
                )
                
                OnboardingSummaryCard(
                    icon: "brain.head.profile",
                    title: "Personality Type",
                    detail: viewModel.onboardingData.personalityType
                )
                
                OnboardingSummaryCard(
                    icon: "slider.horizontal.3",
                    title: "Preferences Set",
                    detail: "\(viewModel.onboardingData.preferences.count) categories configured"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Ready message
            VStack(spacing: 12) {
                Text("Ready to discover amazing date ideas?")
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text("Your personalized recommendations are waiting for you!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct OnboardingSummaryCard: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(detail)
                    .font(.body)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}