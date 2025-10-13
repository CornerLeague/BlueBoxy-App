//
//  UIComponents.swift
//  BlueBoxy
//
//  Comprehensive UI components for consistent error and loading states
//  Includes button styles, error displays, loading indicators, and reusable components
//

import SwiftUI

// MARK: - Button Styles
// Using ButtonStyles from Core/DesignSystem/Button+DesignSystem.swift

struct CompactButtonStyle: ButtonStyle {
    let isLoading: Bool
    let variant: Variant
    
    enum Variant {
        case primary, secondary, destructive
        
        var colors: [Color] {
            switch self {
            case .primary: return [.blue, .purple]
            case .secondary: return [.gray, .gray.opacity(0.8)]
            case .destructive: return [.red, .pink]
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .destructive: return .white
            case .secondary: return .primary
            }
        }
    }
    
    init(variant: Variant = .primary, isLoading: Bool = false) {
        self.variant = variant
        self.isLoading = isLoading
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: variant.foregroundColor))
                    .scaleEffect(0.7)
            }
            
            configuration.label
                .opacity(isLoading ? 0.7 : 1.0)
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(variant.foregroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            variant == .secondary ? 
            AnyShapeStyle(.ultraThinMaterial) :
            AnyShapeStyle(LinearGradient(colors: variant.colors, startPoint: .leading, endPoint: .trailing))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            variant == .secondary ?
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1) : nil
        )
        .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .disabled(isLoading)
    }
}

struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isLoading: Bool
    
    init(isSelected: Bool, isLoading: Bool = false) {
        self.isSelected = isSelected
        self.isLoading = isLoading
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : .primary))
                    .scaleEffect(0.8)
            }
            
            configuration.label
                .opacity(isLoading ? 0.7 : 1.0)
            
            Spacer()
            
            if isSelected && !isLoading {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
        }
        .font(.body)
        .fontWeight(.medium)
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .stroke(
                    isSelected ? Color.blue : Color.gray.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .disabled(isLoading)
    }
}

struct TagButtonStyle: ButtonStyle {
    let isSelected: Bool
    let size: Size
    
    enum Size {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return .caption
            case .medium: return .subheadline
            case .large: return .body
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .medium: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            case .large: return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 18
            case .large: return 20
            }
        }
    }
    
    init(isSelected: Bool, size: Size = .medium) {
        self.isSelected = isSelected
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Loading Components

struct LoadingView: View {
    let message: String
    let style: Style
    
    enum Style {
        case fullScreen, card, inline, minimal
    }
    
    init(message: String = "Loading...", style: Style = .fullScreen) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .fullScreen:
                fullScreenView
            case .card:
                cardView
            case .inline:
                inlineView
            case .minimal:
                minimalView
            }
        }
    }
    
    private var fullScreenView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: Rectangle())
    }
    
    private var cardView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var inlineView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.9)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
        )
    }
    
    private var minimalView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.7)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LoadingOverlay: View {
    let isVisible: Bool
    let message: String
    
    init(isVisible: Bool, message: String = "Loading...") {
        self.isVisible = isVisible
        self.message = message
    }
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Error Components

struct ErrorView: View {
    let error: Error
    let title: String
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: Error,
        title: String = "Something went wrong",
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.title = title
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            ZStack {
                Circle()
                    .fill(.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
            }
            
            // Error content
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                if let onDismiss = onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(24)
    }
    
    private var errorMessage: String {
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? "An error occurred"
        }
        return error.localizedDescription
    }
}

struct ErrorBanner: View {
    let error: Error
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: Error,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(CompactButtonStyle(variant: .secondary))
                }
                
                if let onDismiss = onDismiss {
                    Button("✕") {
                        onDismiss()
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.opacity(0.1))
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var errorMessage: String {
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? "An error occurred"
        }
        return error.localizedDescription
    }
}

struct InlineErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let onRetry = onRetry {
                Button("Retry") {
                    onRetry()
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.red.opacity(0.1))
        )
    }
}

// MARK: - State Management Components

struct StateView<Content: View, LoadingView: View, ErrorView: View>: View {
    let state: Loadable<Content>
    let content: (Content) -> Content
    let loadingView: LoadingView
    let errorView: (Error) -> ErrorView
    
    init(
        state: Loadable<Content>,
        @ViewBuilder content: @escaping (Content) -> Content,
        @ViewBuilder loadingView: () -> LoadingView,
        @ViewBuilder errorView: @escaping (Error) -> ErrorView
    ) {
        self.state = state
        self.content = content
        self.loadingView = loadingView()
        self.errorView = errorView
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                Color.clear
            case .loading:
                loadingView
            case .loaded(let data):
                content(data)
            case .failed(let error):
                errorView(error)
            }
        }
    }
}

struct ConditionalLoadingView<Content: View>: View {
    let isLoading: Bool
    let content: Content
    let loadingMessage: String
    
    init(isLoading: Bool, loadingMessage: String = "Loading...", @ViewBuilder content: () -> Content) {
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1.0)
            
            if isLoading {
                LoadingOverlay(isVisible: true, message: loadingMessage)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Utility Components

struct DividerWithLabel: View {
    let label: String
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.quaternary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.quaternary)
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let accent: Color
    
    init(icon: String, title: String, subtitle: String? = nil, accent: Color = .blue) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(0.05))
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - NetworkError Extension

extension NetworkError {
    var userFriendlyMessage: String {
        switch self {
        case .connectivity(let details):
            return details.isEmpty ? "Please check your internet connection and try again." : details
        case .unauthorized:
            return "You need to sign in to access this content."
        case .forbidden:
            return "You don't have permission to access this content."
        case .notFound:
            return "The requested content could not be found."
        case .server(let message):
            return message.isEmpty ? "Our servers are experiencing issues. Please try again later." : message
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .badRequest(let message):
            return message.isEmpty ? "Invalid request. Please try again." : message
        case .decoding(let details):
            return "There was an issue processing the response. Please try again."
        case .cancelled:
            return "Request was cancelled."
        case .unknown(let status):
            if let status = status {
                return "An unexpected error occurred (\(status)). Please try again."
            } else {
                return "An unexpected error occurred. Please try again."
            }
        }
    }
}

// MARK: - Common UI Components

/// Reusable stat card component for displaying metrics
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Reusable detail row component for displaying key-value pairs
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.subheadline)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

/// Reusable share sheet component for sharing content
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
