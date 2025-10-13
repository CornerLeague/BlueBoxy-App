//
//  MessagingErrorViews.swift
//  BlueBoxy
//
//  Enhanced error handling views specifically for messaging features
//  Provides contextual error messages, retry actions, and fallback states
//

import SwiftUI

// MARK: - Messaging Error View

/// Comprehensive error view for messaging operations with contextual messages and actions
struct MessagingErrorView: View {
    let error: NetworkError
    let context: MessagingErrorContext
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon with animation
            errorIcon
                .scaleEffect(isRetrying ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.3).repeatCount(isRetrying ? .max : 0), value: isRetrying)
            
            // Error Content
            VStack(spacing: 12) {
                Text(contextualTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(contextualMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            // Action Buttons
            actionButtons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
    
    // MARK: - Components
    
    private var errorIcon: some View {
        Group {
            switch context {
            case .messageGeneration:
                Image(systemName: error.isRetryable ? "brain.head.profile" : "exclamationmark.triangle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(error.isRetryable ? .blue : .orange)
            case .categoryLoading:
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.orange)
            case .messageSaving:
                Image(systemName: "square.and.arrow.down.trianglebadge.exclamationmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.red)
            case .historyLoading:
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.orange)
            case .networkConnectivity:
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.red)
            case .authentication:
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.red)
            }
        }
    }
    
    private var contextualTitle: String {
        switch context {
        case .messageGeneration:
            return error.isRetryable ? "Generation Temporarily Unavailable" : "Generation Failed"
        case .categoryLoading:
            return "Categories Unavailable"
        case .messageSaving:
            return "Save Failed"
        case .historyLoading:
            return "History Unavailable"
        case .networkConnectivity:
            return "No Connection"
        case .authentication:
            return "Authentication Required"
        }
    }
    
    private var contextualMessage: String {
        switch (context, error) {
        case (.messageGeneration, .connectivity):
            return "We couldn't connect to generate your message. Check your internet connection and try again."
        case (.messageGeneration, .server):
            return "Our message generation service is temporarily down. We're working to fix this."
        case (.messageGeneration, .rateLimited):
            return "You're generating messages too quickly. Please wait a moment before trying again."
        case (.categoryLoading, _):
            return "We couldn't load message categories. You can still use the service, but you might see limited options."
        case (.messageSaving, _):
            return "Your message couldn't be saved to your history, but you can still copy and use it."
        case (.historyLoading, _):
            return "We couldn't load your message history right now. Your recent messages are still available."
        case (.networkConnectivity, _):
            return "Please check your internet connection and try again."
        case (.authentication, _):
            return "Please sign in to continue using BlueBoxy messaging features."
        default:
            return error.localizedDescription
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Dismiss button (always available)
            if let onDismiss = onDismiss {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            
            // Retry button (conditional)
            if let retryAction = onRetry, error.isRetryable {
                Button(action: {
                    performRetry(retryAction)
                }) {
                    HStack(spacing: 6) {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isRetrying ? "Retrying..." : "Try Again")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetrying)
            }
        }
    }
    
    // MARK: - Actions
    
    private func performRetry(_ retryAction: @escaping () -> Void) {
        isRetrying = true
        
        // Add a small delay to show the retry animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            retryAction()
            isRetrying = false
        }
    }
}

// MARK: - Messaging Error Context

enum MessagingErrorContext {
    case messageGeneration
    case categoryLoading
    case messageSaving
    case historyLoading
    case networkConnectivity
    case authentication
}

// MARK: - Compact Error Banner

/// Compact error banner for inline error display
struct MessagingErrorBanner: View {
    let error: NetworkError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if let onRetry = onRetry, error.isRetryable {
                        Button("Retry", action: onRetry)
                            .font(.caption)
                            .buttonStyle(.borderless)
                    }
                    
                    Button("Dismiss") {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Loading Error State

/// Loading view with built-in error handling
struct MessagingLoadingView: View {
    let message: String
    let progress: Double?
    let error: NetworkError?
    let onRetry: (() -> Void)?
    let onCancel: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            if let error = error {
                // Show error state
                MessagingErrorView(
                    error: error,
                    context: .messageGeneration,
                    onRetry: onRetry,
                    onDismiss: onCancel
                )
            } else {
                // Show loading state
                VStack(spacing: 16) {
                    if let progress = progress {
                        VStack(spacing: 8) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(maxWidth: 200)
                            
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let onCancel = onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

// MARK: - Fallback Content View

/// Provides fallback content when primary content fails to load
struct MessagingFallbackView<PrimaryContent: View, FallbackContent: View>: View {
    let loadableState: Loadable<Any>
    @ViewBuilder let primaryContent: () -> PrimaryContent
    @ViewBuilder let fallbackContent: () -> FallbackContent
    let onRetry: (() -> Void)?
    
    var body: some View {
        Group {
            switch loadableState {
            case .loaded:
                primaryContent()
            case .loading:
                MessagingLoadingView(
                    message: "Loading content...",
                    progress: nil,
                    error: nil,
                    onRetry: nil,
                    onCancel: nil
                )
            case .failed(let error):
                if error.isRetryable {
                    MessagingErrorView(
                        error: error,
                        context: .categoryLoading,
                        onRetry: onRetry,
                        onDismiss: nil
                    )
                } else {
                    // Show fallback content for non-retryable errors
                    VStack(spacing: 16) {
                        Text("Using offline content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        
                        fallbackContent()
                    }
                }
            case .idle:
                ProgressView("Preparing...")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Network Status Indicator

/// Shows current network connectivity status
struct NetworkStatusIndicator: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        Group {
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text("Offline")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Network Monitor
// Using NetworkMonitor from EnhancedDashboardViewModel.swift

// MARK: - Preview Helpers

#if DEBUG
struct MessagingErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Connectivity error
            MessagingErrorView(
                error: .connectivity("No internet connection"),
                context: .messageGeneration,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Connectivity Error")
            
            // Server error
            MessagingErrorView(
                error: .server(message: "Service temporarily unavailable"),
                context: .messageGeneration,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Server Error")
            
            // Rate limited error
            MessagingErrorView(
                error: .rateLimited,
                context: .messageGeneration,
                onRetry: {},
                onDismiss: nil
            )
            .previewDisplayName("Rate Limited")
            
            // Error banner
            VStack {
                MessagingErrorBanner(
                    error: .connectivity("Connection lost"),
                    onRetry: {},
                    onDismiss: {}
                )
                
                Spacer()
            }
            .padding()
            .previewDisplayName("Error Banner")
        }
    }
}
#endif