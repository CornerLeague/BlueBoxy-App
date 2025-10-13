//
//  BootstrapViews.swift
//  BlueBoxy
//
//  Supporting views and models for enhanced app bootstrap functionality
//  Includes splash screen, error states, maintenance, and app update prompts
//

import SwiftUI

// MARK: - Bootstrap State

enum BootstrapState: Equatable {
    case initializing
    case ready
    case error(Error)
    case maintenance
    
    static func == (lhs: BootstrapState, rhs: BootstrapState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.ready, .ready),
             (.maintenance, .maintenance):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - App Update Info

struct AppUpdateInfo {
    let version: String
    let releaseNotes: String
    let isRequired: Bool
    let downloadURL: URL?
    
    init(version: String, releaseNotes: String, isRequired: Bool, downloadURL: URL? = nil) {
        self.version = version
        self.releaseNotes = releaseNotes
        self.isRequired = isRequired
        self.downloadURL = downloadURL
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoRotation: Double = 0
    @State private var showingText = false
    @State private var loadingProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo section
                VStack(spacing: 24) {
                    // Animated logo
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(logoScale)
                        
                        // Heart icon
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(logoScale)
                            .rotationEffect(.degrees(logoRotation))
                    }
                    
                    // App name
                    if showingText {
                        VStack(spacing: 8) {
                            Text("BlueBoxy")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Your Dating Companion")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer().frame(height: 100)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo scale animation
        withAnimation(.easeOut(duration: 1.0)) {
            logoScale = 1.0
        }
        
        // Logo rotation animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            logoRotation = 360
        }
        
        // Text appearance
        withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
            showingText = true
        }
        
        // Simulate loading progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if loadingProgress < 1.0 {
                loadingProgress += 0.05
            } else {
                timer.invalidate()
            }
        }
    }
}


// MARK: - Maintenance View

struct MaintenanceView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Maintenance illustration
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                        .offset(x: animationOffset)
                }
                
                VStack(spacing: 16) {
                    Text("Under Maintenance")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("We're making some improvements to serve you better. Please check back in a few minutes.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            
            // Status info
            VStack(spacing: 12) {
                Text("Expected downtime: 10-15 minutes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button("Check Status") {
                    // Open status page
                    if let url = URL(string: "https://status.blueboxy.com") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.body)
                .foregroundStyle(.blue)
            }
            
            Spacer().frame(height: 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationOffset = 5
            }
        }
    }
}

// MARK: - App Update Prompt

struct AppUpdatePromptView: View {
    let updateInfo: AppUpdateInfo
    let onUpdate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !updateInfo.isRequired {
                        onDismiss()
                    }
                }
            
            // Update card
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(spacing: 8) {
                        Text(updateInfo.isRequired ? "Update Required" : "Update Available")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version \(updateInfo.version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Release notes
                if !updateInfo.releaseNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's New:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            Text(updateInfo.releaseNotes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary.opacity(0.5))
                    )
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Update Now") {
                        onUpdate()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    if !updateInfo.isRequired {
                        Button("Later") {
                            onDismiss()
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Network Status Banner

struct NetworkStatusBanner: View {
    @State private var isVisible = false
    let isConnected: Bool
    
    var body: some View {
        if !isConnected && isVisible {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 16, weight: .medium))
                
                Text("No internet connection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation {
                        isVisible = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.red.opacity(0.9))
            .foregroundStyle(.white)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String
    let progress: Double?
    
    var body: some View {
        VStack(spacing: 20) {
            if let progress = progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 2.0)
                    .padding(.horizontal, 40)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Debug Info View (Development Only)

#if DEBUG
struct DebugInfoView: View {
    @Environment(\.appEnvironment) var appEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.headline)
                .fontWeight(.semibold)
            
            Group {
                Text("Authenticated: \(appEnvironment?.isAuthenticated ?? false ? "Yes" : "No")")
                Text("User ID: \(appEnvironment?.currentUser?.id ?? 0)")
                Text("Session Valid: \(appEnvironment?.sessionStore.isSessionValid() ?? false ? "Yes" : "No")")
                
                if let expiry = appEnvironment?.sessionStore.sessionExpiryDate {
                    Text("Session Expires: \(expiry.formatted())")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
        .padding()
    }
}
#endif