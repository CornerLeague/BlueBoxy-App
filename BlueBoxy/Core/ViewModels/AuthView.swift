//
//  AuthView.swift
//  BlueBoxy
//
//  Example authentication view demonstrating SessionViewModel usage
//  This shows how to create login/register flows with the session management
//

import SwiftUI

struct AuthView: View {
    @StateObject private var sessionViewModel = SessionViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var partnerName = ""
    @State private var personalityType = ""
    @State private var isRegisterMode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("BlueBoxy")
                        .h1Style()
                        .primaryStyle()
                    
                    Text(isRegisterMode ? "Create Your Account" : "Welcome Back")
                        .h3Style()
                        .mutedStyle()
                }
                
                // Form Fields
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Email Field
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Email")
                            .captionStyle()
                            .mutedStyle()
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Password")
                            .captionStyle()
                            .mutedStyle()
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if isRegisterMode {
                        // Name Field (Registration only)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Your Name")
                                .captionStyle()
                                .mutedStyle()
                            
                            TextField("Enter your name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Partner Name Field (Registration only, optional)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Partner's Name (Optional)")
                                .captionStyle()
                                .mutedStyle()
                            
                            TextField("Enter partner's name", text: $partnerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Personality Type Field (Registration only, optional)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Personality Type (Optional)")
                                .captionStyle()
                                .mutedStyle()
                            
                            TextField("e.g., ENFP", text: $personalityType)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textInputAutocapitalization(.characters)
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Primary Action Button
                    DSButton(
                        isRegisterMode ? "Create Account" : "Sign In",
                        style: .primary,
                        isLoading: sessionViewModel.isLoading
                    ) {
                        Task {
                            if isRegisterMode {
                                await register()
                            } else {
                                await login()
                            }
                        }
                    }
                    .disabled(!isFormValid)
                    
                    // Mode Toggle Button
                    Button(isRegisterMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        withAnimation(DesignSystem.Animation.easeInOut) {
                            isRegisterMode.toggle()
                            clearForm()
                        }
                    }
                    .ghostStyle()
                }
                
                // Status Display
                if !sessionViewModel.status.isEmpty && sessionViewModel.status != "Idle" {
                    Text(sessionViewModel.status)
                        .captionStyle()
                        .foregroundColor(sessionViewModel.error != nil ? DesignSystem.Colors.error : DesignSystem.Colors.success)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .defaultPadding()
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = sessionViewModel.validateEmail(email)
        let passwordValid = sessionViewModel.validatePassword(password)
        let nameValid = !isRegisterMode || sessionViewModel.validateName(name)
        
        return emailValid && passwordValid && nameValid
    }
    
    // MARK: - Actions
    
    private func login() async {
        await sessionViewModel.login(email: email, password: password)
    }
    
    private func register() async {
        await sessionViewModel.register(
            email: email,
            password: password,
            name: name,
            partnerName: partnerName.isEmpty ? nil : partnerName,
            personalityType: personalityType.isEmpty ? nil : personalityType
        )
    }
    
    private func clearForm() {
        email = ""
        password = ""
        name = ""
        partnerName = ""
        personalityType = ""
        sessionViewModel.clearError()
    }
}

// MARK: - Previews

#Preview("Authentication") {
    #if DEBUG
    AuthView()
    #else
    Text("Preview not available in release builds")
    #endif
}

#Preview("Loading State") {
    #if DEBUG
    AuthView()
        .environmentObject(SessionViewModel.previewLoading)
    #else
    Text("Preview not available in release builds")
    #endif
}

#Preview("Error State") {
    #if DEBUG
    AuthView()
        .environmentObject(SessionViewModel.previewError)
    #else
    Text("Preview not available in release builds")
    #endif
}
