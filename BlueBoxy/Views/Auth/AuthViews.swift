//
//  AuthViews.swift
//  BlueBoxy
//
//  Comprehensive authentication views with form validation and error handling
//  Includes login, register, forgot password, and supporting auth components
//

import SwiftUI

// MARK: - Auth Flow View

struct AuthFlowView: View {
    let route: AppRoute.AuthRoute
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationStack {
            authContent
                .background(authBackground)
                .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    @ViewBuilder
    private var authContent: some View {
        switch route {
        case .login:
            LoginView(showingForgotPassword: $showingForgotPassword)
        case .register:
            RegisterView()
        case .forgotPassword:
            ForgotPasswordView()
        case .resetPassword(let token):
            ResetPasswordView(token: token)
        case .verifyEmail(let email):
            VerifyEmailView(email: email)
        }
    }
    
    private var authBackground: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.1),
                Color.purple.opacity(0.1),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Login View

struct LoginView: View {
    @Binding var showingForgotPassword: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Form state
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var rememberMe = false
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: LoginField?
    
    enum LoginField {
        case email, password
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 24) {
                        // Logo and branding
                        VStack(spacing: 16) {
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
                                
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("Welcome Back")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                
                                Text("Sign in to continue your relationship journey")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.top, 40)
                    
                    // Login form
                    VStack(spacing: 20) {
                        // Email field
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            focusState: $focusedField,
                            fieldType: .email,
                            validation: emailValidation
                        )
                        
                        // Password field
                        AuthSecureField(
                            title: "Password",
                            text: $password,
                            placeholder: "Enter your password",
                            showText: $showPassword,
                            focusState: $focusedField,
                            fieldType: .password,
                            validation: passwordValidation
                        )
                        
                        // Options row
                        HStack {
                            // Remember me toggle
                            Button(action: { rememberMe.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(rememberMe ? .blue : .secondary)
                                    
                                    Text("Remember me")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Forgot password link
                            Button("Forgot password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        
                        // Sign in button
                        AuthActionButton(
                            title: "Sign In",
                            isLoading: isLoading,
                            isEnabled: isFormValid,
                            action: handleLogin
                        )
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.quaternary)
                            
                            Text("or")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.vertical, 8)
                        
                        // Social login buttons
                        VStack(spacing: 12) {
                            SocialLoginButton(
                                provider: .apple,
                                action: handleAppleLogin
                            )
                            
                            SocialLoginButton(
                                provider: .google,
                                action: handleGoogleLogin
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Register prompt
                    VStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.secondary)
                            
                            Button("Sign up") {
                                navigationCoordinator.navigateToAuth(.register)
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        }
                        .font(.body)
                    }
                    .padding(.bottom, 32)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .alert("Sign In Failed", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            loadSavedCredentials()
        }
    }
    
    // MARK: - Validation
    
    private var emailValidation: ValidationResult {
        if email.isEmpty {
            return .empty
        } else if !isValidEmail(email) {
            return .invalid("Please enter a valid email address")
        } else {
            return .valid
        }
    }
    
    private var passwordValidation: ValidationResult {
        if password.isEmpty {
            return .empty
        } else if password.count < 6 {
            return .invalid("Password must be at least 6 characters")
        } else {
            return .valid
        }
    }
    
    private var isFormValid: Bool {
        emailValidation == .valid && passwordValidation == .valid
    }
    
    private var isLoading: Bool {
        authViewModel.authState.isLoading
    }
    
    // MARK: - Actions
    
    private func handleLogin() {
        Task {
            await authViewModel.login(email: email, password: password)
            
            if case .failed(let error) = authViewModel.authState {
                alertMessage = error.localizedDescription
                showingAlert = true
            } else if case .loaded = authViewModel.authState {
                // Save credentials if remember me is enabled
                if rememberMe {
                    saveCredentials()
                }
                
                // Navigation is handled by the navigation coordinator
                // observing the authentication state
            }
        }
    }
    
    private func handleAppleLogin() {
        // TODO: Implement Apple Sign In
        print("Apple Sign In tapped")
    }
    
    private func handleGoogleLogin() {
        // TODO: Implement Google Sign In
        print("Google Sign In tapped")
    }
    
    // MARK: - Persistence
    
    private func saveCredentials() {
        if rememberMe {
            UserDefaults.standard.set(email, forKey: "savedEmail")
        }
    }
    
    private func loadSavedCredentials() {
        if let savedEmail = UserDefaults.standard.string(forKey: "savedEmail") {
            email = savedEmail
            rememberMe = true
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Form state
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    
    // UI state
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: RegisterField?
    
    enum RegisterField {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 24) {
                        // Back button
                        HStack {
                            Button(action: { navigationCoordinator.navigateToAuth(.login) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Back")
                                }
                                .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Title and subtitle
                        VStack(spacing: 16) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            
                            Text("Join thousands of couples strengthening their relationships")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    // Registration form
                    VStack(spacing: 20) {
                        // Name field
                        AuthTextField(
                            title: "Full Name",
                            text: $name,
                            placeholder: "Enter your full name",
                            keyboardType: .default,
                            textContentType: .name,
                            focusState: $focusedField,
                            fieldType: .name,
                            validation: nameValidation
                        )
                        
                        // Email field
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            focusState: $focusedField,
                            fieldType: .email,
                            validation: emailValidation
                        )
                        
                        // Password field
                        AuthSecureField(
                            title: "Password",
                            text: $password,
                            placeholder: "Create a password",
                            showText: $showPassword,
                            focusState: $focusedField,
                            fieldType: .password,
                            validation: passwordValidation
                        )
                        
                        // Confirm password field
                        AuthSecureField(
                            title: "Confirm Password",
                            text: $confirmPassword,
                            placeholder: "Confirm your password",
                            showText: $showConfirmPassword,
                            focusState: $focusedField,
                            fieldType: .confirmPassword,
                            validation: confirmPasswordValidation
                        )
                        
                        // Password requirements
                        PasswordRequirementsView(password: password)
                        
                        // Terms and privacy
                        Button(action: { agreeToTerms.toggle() }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(agreeToTerms ? .blue : .secondary)
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("I agree to the Terms of Service and Privacy Policy")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    HStack(spacing: 16) {
                                        Button("Terms of Service") {
                                            // TODO: Show terms
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        
                                        Button("Privacy Policy") {
                                            // TODO: Show privacy policy
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Create account button
                        AuthActionButton(
                            title: "Create Account",
                            isLoading: isLoading,
                            isEnabled: isFormValid,
                            action: handleRegister
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Login prompt
                    VStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundStyle(.secondary)
                            
                            Button("Sign in") {
                                navigationCoordinator.navigateToAuth(.login)
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        }
                        .font(.body)
                    }
                    .padding(.bottom, 32)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .alert("Registration Failed", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // MARK: - Validation
    
    private var nameValidation: ValidationResult {
        if name.isEmpty {
            return .empty
        } else if name.count < 2 {
            return .invalid("Name must be at least 2 characters")
        } else {
            return .valid
        }
    }
    
    private var emailValidation: ValidationResult {
        if email.isEmpty {
            return .empty
        } else if !isValidEmail(email) {
            return .invalid("Please enter a valid email address")
        } else {
            return .valid
        }
    }
    
    private var passwordValidation: ValidationResult {
        if password.isEmpty {
            return .empty
        } else if password.count < 8 {
            return .invalid("Password must be at least 8 characters")
        } else if !isStrongPassword(password) {
            return .invalid("Password must contain uppercase, lowercase, and numbers")
        } else {
            return .valid
        }
    }
    
    private var confirmPasswordValidation: ValidationResult {
        if confirmPassword.isEmpty {
            return .empty
        } else if password != confirmPassword {
            return .invalid("Passwords don't match")
        } else {
            return .valid
        }
    }
    
    private var isFormValid: Bool {
        nameValidation == .valid &&
        emailValidation == .valid &&
        passwordValidation == .valid &&
        confirmPasswordValidation == .valid &&
        agreeToTerms
    }
    
    private var isLoading: Bool {
        authViewModel.authState.isLoading
    }
    
    // MARK: - Actions
    
    private func handleRegister() {
        Task {
            await authViewModel.register(
                email: email,
                password: password,
                name: name
            )
            
            if case .failed(let error) = authViewModel.authState {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            // Navigation is handled by the navigation coordinator
        }
    }
}

// MARK: - Field Types for Focus State

enum AuthFieldType: Hashable {
    case email
    case password
    case confirmPassword
    case name
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var emailSent = false
    @State private var isLoading = false
    @FocusState private var focusedField: AuthFieldType?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Header
                VStack(spacing: 24) {
                    Image(systemName: emailSent ? "checkmark.circle.fill" : "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(emailSent ? .green : .blue)
                    
                    VStack(spacing: 16) {
                        Text(emailSent ? "Email Sent!" : "Forgot Password?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(emailSent ?
                             "We've sent a password reset link to your email address. Check your inbox and follow the instructions to reset your password." :
                             "Enter your email address and we'll send you a link to reset your password."
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                
                if !emailSent {
                    // Email input form
                    VStack(spacing: 20) {
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            placeholder: "Enter your email",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            focusState: $focusedField,
                            fieldType: AuthFieldType.email,
                            validation: emailValidation
                        )
                        
                        AuthActionButton(
                            title: "Send Reset Link",
                            isLoading: isLoading,
                            isEnabled: isFormValid,
                            action: handleSendResetEmail
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if emailSent {
                        Button("Didn't receive email? Send again") {
                            emailSent = false
                        }
                        .font(.body)
                        .foregroundStyle(.blue)
                    }
                    
                    Button(emailSent ? "Back to Sign In" : "Cancel") {
                        if emailSent {
                            navigationCoordinator.navigateToAuth(.login)
                        }
                        dismiss()
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            focusedField = .email
        }
    }
    
    private var emailValidation: ValidationResult {
        if email.isEmpty {
            return .empty
        } else if !isValidEmail(email) {
            return .invalid("Please enter a valid email address")
        } else {
            return .valid
        }
    }
    
    private var isFormValid: Bool {
        emailValidation == .valid
    }
    
    private func handleSendResetEmail() {
        Task {
            isLoading = true
            
            // Simulate password reset email sending
            // In a real app, this would call a proper API endpoint
            do {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                // Mark as successful
                emailSent = true
                
            } catch {
                alertMessage = "Unable to send reset email. Please try again."
                showingAlert = true
            }
            
            isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct PasswordRequirementsView: View {
    let password: String
    
    private var requirements: [(String, Bool)] {
        [
            ("At least 8 characters", password.count >= 8),
            ("Contains uppercase letter", password.contains { $0.isUppercase }),
            ("Contains lowercase letter", password.contains { $0.isLowercase }),
            ("Contains number", password.contains { $0.isNumber })
        ]
    }
    
    var body: some View {
        if !password.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Password Requirements:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                ForEach(requirements, id: \.0) { requirement, met in
                    HStack(spacing: 8) {
                        Image(systemName: met ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(met ? .green : .secondary)
                        
                        Text(requirement)
                            .font(.caption)
                            .foregroundStyle(met ? .primary : .secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
}

// MARK: - Validation Helpers

enum ValidationResult: Equatable {
    case empty
    case valid
    case invalid(String)
}

private func isValidEmail(_ email: String) -> Bool {
    let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}

private func isStrongPassword(_ password: String) -> Bool {
    return password.count >= 8 &&
           password.contains { $0.isUppercase } &&
           password.contains { $0.isLowercase } &&
           password.contains { $0.isNumber }
}

// MARK: - Type Extensions

private extension LoginView.LoginField {
    static func == (lhs: LoginView.LoginField, rhs: any Hashable) -> Bool {
        guard let rhs = rhs as? LoginView.LoginField else { return false }
        return lhs == rhs
    }
}

private extension RegisterView.RegisterField {
    static func == (lhs: RegisterView.RegisterField, rhs: any Hashable) -> Bool {
        guard let rhs = rhs as? RegisterView.RegisterField else { return false }
        return lhs == rhs
    }
}