//
//  OAuthProgressView.swift
//  BlueBoxy
//
//  OAuth authentication progress view with visual feedback and error handling
//

import SwiftUI

struct OAuthProgressView: View {
    @ObservedObject var oauthService: OAuthService
    let provider: CalendarProvider
    let onComplete: (Bool) -> Void
    let onCancel: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.systemBackground
                    .ignoresSafeArea()
                
                content
            }
            .navigationTitle("Connecting")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if oauthService.authState.isActive {
                        Button("Cancel") {
                            oauthService.cancelAuthentication()
                            onCancel()
                        }
                    } else {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onChange(of: oauthService.authState) { _, newState in
                handleStateChange(newState)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch oauthService.authState {
        case .idle, .initiating:
            preparingView
            
        case .presentingWeb:
            webAuthView
            
        case .processingCallback:
            processingView
            
        case .exchangingCode:
            exchangingView
            
        case .completed(let success, let provider):
            completedView(success: success, provider: provider)
            
        case .failed(let error):
            errorView(error: error)
        }
    }
    
    // MARK: - State Views
    
    private var preparingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Provider icon and info
            providerHeader
            
            // Progress indicator
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                
                Text("Preparing authentication...")
                    .bodyStyle()
                    .mutedStyle()
            }
            
            // Instructions
            instructionsCard
            
            Spacer()
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var webAuthView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Provider icon and info
            providerHeader
            
            // Progress with steps
            progressStepsView
            
            // Current step info
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "safari")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Complete in Browser")
                    .h2Style()
                
                Text("Please sign in to \(provider.displayName) in the browser window that opened.")
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
            
            // Security notice
            securityNoticeCard
            
            Spacer()
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var processingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            providerHeader
            
            progressStepsView
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                
                Text("Processing Response")
                    .h2Style()
                
                Text("Validating your authentication with \(provider.displayName)...")
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var exchangingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            providerHeader
            
            progressStepsView
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                
                Text("Finalizing Connection")
                    .h2Style()
                
                Text("Establishing secure connection to your calendar...")
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func completedView(success: Bool, provider: CalendarProvider) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Success/Failure icon
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(success ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                
                // Title and message
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(success ? "Connected!" : "Connection Failed")
                        .h1Style()
                        .foregroundColor(success ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                    
                    Text(success ? 
                         "Successfully connected to \(provider.displayName). Your events will now sync automatically." :
                         "Unable to connect to \(provider.displayName). Please try again."
                    )
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
                }
            }
            
            if success {
                // Success features
                successFeaturesCard
            }
            
            Spacer()
            
            // Action button
            DSButton(
                success ? "Continue" : "Try Again",
                style: success ? .primary : .secondary
            ) {
                if success {
                    onComplete(true)
                } else {
                    Task {
                        _ = await oauthService.authenticate(provider: provider)
                    }
                }
            }
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: OAuthService.OAuthError) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(DesignSystem.Colors.error)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Authentication Error")
                        .h1Style()
                        .foregroundColor(DesignSystem.Colors.error)
                    
                    Text(error.localizedDescription)
                        .bodyStyle()
                        .foregroundColor(DesignSystem.Colors.systemSecondary)
                        .multilineTextAlignment(.center)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .captionStyle()
                            .mutedStyle()
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Error details card
            errorDetailsCard(error: error)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignSystem.Spacing.sm) {
                if oauthService.canRetry {
                    DSButton("Try Again", style: .primary) {
                        oauthService.resetState()
                        Task {
                            _ = await oauthService.authenticate(provider: provider)
                        }
                    }
                }
                
                DSButton("Cancel", style: .secondary) {
                    onCancel()
                }
            }
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Supporting Views
    
    private var providerHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: provider.icon)
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 80, height: 80)
                .background(DesignSystem.Colors.primary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(provider.displayName)
                    .h2Style()
                
                Text(provider.description)
                    .captionStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var progressStepsView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Progress bar
            ProgressView(value: oauthService.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primary))
            
            // Progress steps
            HStack {
                ForEach(progressSteps.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(stepColor(for: index))
                            .frame(width: 12, height: 12)
                        
                        Text(progressSteps[index])
                            .font(.system(size: 10))
                            .foregroundColor(stepColor(for: index))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
    }
    
    private var progressSteps: [String] {
        ["Prepare", "Authenticate", "Validate", "Connect"]
    }
    
    private func stepColor(for index: Int) -> Color {
        let currentStep = Int(oauthService.progress * Double(progressSteps.count - 1))
        
        if index < currentStep {
            return DesignSystem.Colors.success
        } else if index == currentStep {
            return DesignSystem.Colors.primary
        } else {
            return DesignSystem.Colors.muted
        }
    }
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("What happens next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                InstructionStep(number: 1, text: "Browser window will open")
                InstructionStep(number: 2, text: "Sign in to \(provider.displayName)")
                InstructionStep(number: 3, text: "Grant calendar access permission")
                InstructionStep(number: 4, text: "Return to BlueBoxy automatically")
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    private var securityNoticeCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(DesignSystem.Colors.success)
                
                Text("Security Notice")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.success)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("• Your credentials are never stored by BlueBoxy")
                Text("• Connection uses industry-standard OAuth 2.0")
                Text("• You can revoke access at any time")
            }
            .font(.system(size: 12))
            .foregroundColor(DesignSystem.Colors.muted)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.success.opacity(0.1))
        .cardRadius()
    }
    
    private var successFeaturesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("What you can do now")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                FeatureRow(icon: "calendar.badge.clock", text: "View your calendar events")
                FeatureRow(icon: "arrow.clockwise", text: "Automatic event synchronization")
                FeatureRow(icon: "calendar.badge.plus", text: "Create events in BlueBoxy")
                FeatureRow(icon: "bell", text: "Get event reminders")
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    private func errorDetailsCard(error: OAuthService.OAuthError) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignSystem.Colors.error)
                
                Text("Error Details")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.error)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Error Type: \(errorTypeName(for: error))")
                    .font(.system(size: 12, weight: .medium))
                
                Text("Provider: \(provider.displayName)")
                    .font(.system(size: 12))
                
                Text("Timestamp: \(formattedTimestamp)")
                    .font(.system(size: 12))
            }
            .foregroundColor(DesignSystem.Colors.muted)
        }
        .defaultPadding()
        .background(DesignSystem.Colors.error.opacity(0.1))
        .cardRadius()
    }
    
    // MARK: - Helper Views
    
    private struct InstructionStep: View {
        let number: Int
        let text: String
        
        var body: some View {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(Circle())
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.systemSecondary)
                
                Spacer()
            }
        }
    }
    
    private struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 16)
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.systemSecondary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleStateChange(_ state: OAuthService.OAuthState) {
        switch state {
        case .completed(let success, _):
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete(success)
            }
            
        case .failed:
            // Keep showing error until user takes action
            break
            
        default:
            break
        }
    }
    
    private func errorTypeName(for error: OAuthService.OAuthError) -> String {
        switch error {
        case .invalidProvider: return "Invalid Provider"
        case .missingAuthUrl: return "Missing Auth URL"
        case .invalidAuthUrl: return "Invalid Auth URL"
        case .userCancelled: return "User Cancelled"
        case .invalidCallback: return "Invalid Callback"
        case .missingAuthorizationCode: return "Missing Auth Code"
        case .stateValidationFailed: return "State Validation Failed"
        case .networkError: return "Network Error"
        case .unknownError: return "Unknown Error"
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Preview

#Preview {
    let oauthService = OAuthService()
    let provider = CalendarProvider(
        id: "google",
        name: "Google",
        displayName: "Google Calendar",
        icon: "calendar.badge.plus",
        description: "Connect to your Google Calendar",
        isConnected: false,
        status: "available",
        authUrl: "https://accounts.google.com/oauth/authorize",
        lastSync: nil,
        errorMessage: nil
    )
    
    return OAuthProgressView(
        oauthService: oauthService,
        provider: provider,
        onComplete: { _ in },
        onCancel: { }
    )
}