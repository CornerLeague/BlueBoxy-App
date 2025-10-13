//
//  EmptyStateView.swift
//  BlueBoxy
//
//  Empty state view component that provides engaging empty states for the messaging interface
//  with clear calls-to-action and helpful guidance.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }
            
            // Text content
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Action button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.rays")
                            .font(.headline)
                        
                        Text(actionTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
            }
            
            // Helpful tips
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    
                    Text("Tips to get started")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(
                        systemImage: "heart",
                        tip: "Choose a category that matches your mood"
                    )
                    
                    TipRow(
                        systemImage: "bubble.left",
                        tip: "Add context about your day or recent events"
                    )
                    
                    TipRow(
                        systemImage: "sparkles",
                        tip: "Let AI personalize messages for your partner"
                    )
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary.opacity(0.3))
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
    }
}

struct TipRow: View {
    let systemImage: String
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Specialized Empty States

struct NoMessagesEmptyState: View {
    let onGenerateMessages: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "No Messages Yet",
            subtitle: "Start by selecting a category and generating your first personalized message.",
            systemImage: "message.badge",
            actionTitle: "Generate Messages",
            action: onGenerateMessages
        )
    }
}

struct NoHistoryEmptyState: View {
    let onGoToGeneration: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "No Message History",
            subtitle: "Your generated messages will appear here once you start creating them.",
            systemImage: "clock.badge",
            actionTitle: "Create Messages",
            action: onGoToGeneration
        )
    }
}

struct NoFavoritesEmptyState: View {
    let onGoToGeneration: () -> Void
    
    var body: some View {
        EmptyStateView(
            title: "No Favorite Messages",
            subtitle: "Mark messages as favorites by tapping the heart icon on any generated message.",
            systemImage: "heart.slash",
            actionTitle: "Generate Messages",
            action: onGoToGeneration
        )
    }
}

struct LoadingCategoriesEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading message categories...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 60)
    }
}

struct ErrorEmptyState: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    
    init(
        title: String = "Something went wrong",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if let retryAction = retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 200)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Onboarding Empty State

struct OnboardingEmptyState: View {
    let onCompleteOnboarding: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated illustration
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 30))
                        .foregroundStyle(.purple)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.pink)
                        .offset(y: -5)
                }
            }
            
            VStack(spacing: 16) {
                Text("Welcome to AI Messages")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To get personalized message suggestions, we need to know a bit about your relationship.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button("Complete Your Profile") {
                onCompleteOnboarding()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 280)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("This helps us create messages that:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    BenefitRow(text: "Match your communication style")
                    BenefitRow(text: "Fit your relationship stage")
                    BenefitRow(text: "Resonate with your partner's personality")
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
    }
}

struct BenefitRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    EmptyStateView(
        title: "Ready to Generate Messages",
        subtitle: "Select a category and add some context to create personalized messages for your partner.",
        systemImage: "wand.and.rays",
        actionTitle: "Generate Messages"
    ) {
        // Action
    }
}

#Preview("No Messages") {
    NoMessagesEmptyState {
        // Action
    }
}

#Preview("Error State") {
    ErrorEmptyState(
        message: "Unable to load message categories. Please check your connection and try again."
    ) {
        // Retry action
    }
}

#Preview("Onboarding") {
    OnboardingEmptyState {
        // Complete onboarding
    }
}