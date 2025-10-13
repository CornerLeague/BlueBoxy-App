//
//  AuthComponents.swift
//  BlueBoxy
//
//  Reusable authentication UI components with custom styling and validation
//  Includes text fields, buttons, social login, and supporting components
//

import SwiftUI

// MARK: - Auth Text Field

struct AuthTextField<FieldType: Hashable>: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    @FocusState.Binding var focusState: FieldType?
    let fieldType: FieldType
    let validation: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field label
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                if case .invalid = validation {
                    Spacer()
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            // Text field
            TextField(placeholder, text: $text)
                .font(.body)
                .textFieldStyle(AuthTextFieldStyle(
                    isFocused: focusState == fieldType,
                    validationState: validation
                ))
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocorrectionDisabled()
                .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                .focused($focusState, equals: fieldType)
                .submitLabel(.next)
            
            // Validation message
            if case .invalid(let message) = validation {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validation)
    }
}

// MARK: - Auth Secure Field

struct AuthSecureField<FieldType: Hashable>: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var showText: Bool
    @FocusState.Binding var focusState: FieldType?
    let fieldType: FieldType
    let validation: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field label
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                if case .invalid = validation {
                    Spacer()
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            // Secure field with toggle
            ZStack(alignment: .trailing) {
                Group {
                    if showText {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.body)
                .textFieldStyle(AuthTextFieldStyle(
                    isFocused: focusState == fieldType,
                    validationState: validation,
                    hasTrailingContent: true
                ))
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .focused($focusState, equals: fieldType)
                .submitLabel(.next)
                
                // Show/hide password button
                Button(action: { showText.toggle() }) {
                    Image(systemName: showText ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 12)
            }
            
            // Validation message
            if case .invalid(let message) = validation {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validation)
    }
}

// MARK: - Auth Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    let isFocused: Bool
    let validationState: ValidationResult
    var hasTrailingContent: Bool = false
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.trailing, hasTrailingContent ? 40 : 0)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: validationState)
    }
    
    private var strokeColor: Color {
        switch validationState {
        case .invalid:
            return .red
        case .valid:
            return isFocused ? .blue : .green.opacity(0.5)
        case .empty:
            return isFocused ? .blue : Color.gray.opacity(0.3)
        }
    }
    
    private var strokeWidth: CGFloat {
        switch validationState {
        case .invalid:
            return 2
        case .valid:
            return isFocused ? 2 : 1
        case .empty:
            return isFocused ? 2 : 1
        }
    }
}

// MARK: - Auth Action Button

struct AuthActionButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .opacity(isLoading ? 0.7 : 1.0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: isEnabled ? [.blue, .purple] : [.gray, .gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isEnabled && !isLoading ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.1), value: isEnabled)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Social Login Button

enum SocialProvider {
    case apple, google, facebook
    
    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .facebook: return "Facebook"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "globe"
        case .facebook: return "f.circle.fill"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .apple: return .black
        case .google: return .white
        case .facebook: return Color(red: 0.26, green: 0.40, blue: 0.70)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .apple: return .white
        case .google: return .black
        case .facebook: return .white
        }
    }
}

struct SocialLoginButton: View {
    let provider: SocialProvider
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 18, weight: .medium))
                
                Text("Continue with \(provider.displayName)")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(provider.foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(provider.backgroundColor)
                    .stroke(provider == .google ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(SocialButtonStyle())
    }
}

struct SocialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    let token: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var passwordResetSuccess = false
    @FocusState private var focusedField: ResetPasswordField?
    
    enum ResetPasswordField {
        case password, confirmPassword
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header
            VStack(spacing: 24) {
                Image(systemName: passwordResetSuccess ? "checkmark.circle.fill" : "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(passwordResetSuccess ? .green : .blue)
                
                VStack(spacing: 16) {
                    Text(passwordResetSuccess ? "Password Reset!" : "Create New Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(passwordResetSuccess ?
                         "Your password has been successfully reset. You can now sign in with your new password." :
                         "Enter your new password below."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            
            if !passwordResetSuccess {
                // Password form
                VStack(spacing: 20) {
                    AuthSecureField(
                        title: "New Password",
                        text: $password,
                        placeholder: "Enter new password",
                        showText: $showPassword,
                        focusState: $focusedField,
                        fieldType: .password,
                        validation: passwordValidation
                    )
                    
                    AuthSecureField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        placeholder: "Confirm new password",
                        showText: $showConfirmPassword,
                        focusState: $focusedField,
                        fieldType: .confirmPassword,
                        validation: confirmPasswordValidation
                    )
                    
                    PasswordRequirementsView(password: password)
                    
                    AuthActionButton(
                        title: "Reset Password",
                        isLoading: isLoading,
                        isEnabled: isFormValid,
                        action: handleResetPassword
                    )
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Action button
            if passwordResetSuccess {
                Button("Sign In") {
                    navigationCoordinator.navigateToAuth(.login)
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onTapGesture {
            focusedField = nil
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
        passwordValidation == .valid && confirmPasswordValidation == .valid
    }
    
    private var isLoading: Bool {
        authViewModel.resetPasswordState.isLoading
    }
    
    private func handleResetPassword() {
        Task {
            await authViewModel.resetPassword(token: token, newPassword: password)
            
            if case .loaded = authViewModel.resetPasswordState {
                passwordResetSuccess = true
            } else if case .failed(let error) = authViewModel.resetPasswordState {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}

// MARK: - Verify Email View

struct VerifyEmailView: View {
    let email: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var emailVerified = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header
            VStack(spacing: 24) {
                Image(systemName: emailVerified ? "checkmark.circle.fill" : "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(emailVerified ? .green : .blue)
                
                VStack(spacing: 16) {
                    Text(emailVerified ? "Email Verified!" : "Check Your Email")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text(emailVerified ?
                             "Your email has been successfully verified. You can now access your account." :
                             "We've sent a verification email to:"
                        )
                        
                        if !emailVerified {
                            Text(email)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        Text(emailVerified ? "" : "Click the link in the email to verify your account.")
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            
            if !emailVerified {
                VStack(spacing: 16) {
                    Button("Resend Verification Email") {
                        handleResendVerification()
                    }
                    .font(.body)
                    .foregroundStyle(.blue)
                    
                    Button("I've verified my email") {
                        handleCheckVerification()
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                }
            }
            
            Spacer()
            
            // Action button
            Button(emailVerified ? "Continue to App" : "Back to Sign In") {
                if emailVerified {
                    // User is now verified, proceed to main app
                    navigationCoordinator.navigateToMain(.dashboard)
                } else {
                    navigationCoordinator.navigateToAuth(.login)
                }
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(emailVerified ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                emailVerified ?
                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleResendVerification() {
        Task {
            await authViewModel.resendVerificationEmail(email: email)
            
            if case .failed(let error) = authViewModel.verificationState {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func handleCheckVerification() {
        Task {
            await authViewModel.checkEmailVerification()
            
            if case .loaded = authViewModel.verificationState {
                emailVerified = true
            } else if case .failed(let error) = authViewModel.verificationState {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}