//
//  Button+DesignSystem.swift
//  BlueBoxy
//
//  Design system button components following the design tokens
//

import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.primary)
            .cornerRadius(DesignSystem.Radius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.easeOut, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.easeOut, value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .frame(minHeight: DesignSystem.Layout.minTouchTarget)
            .background(DesignSystem.Colors.destructive)
            .cornerRadius(DesignSystem.Radius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.easeOut, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.primary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xs)
                    .fill(configuration.isPressed ? DesignSystem.Colors.muted : Color.clear)
            )
            .animation(DesignSystem.Animation.easeOut, value: configuration.isPressed)
    }
}

// MARK: - Button Extensions

extension Button {
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func destructiveStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
    
    func ghostStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
}

// MARK: - Custom Button Components

struct DSButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonVariant
    let isLoading: Bool
    let isDisabled: Bool
    
    enum ButtonVariant {
        case primary, secondary, destructive, ghost
    }
    
    init(
        _ title: String,
        style: ButtonVariant = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1.0)
        .modifier(ButtonStyleModifier(style: style))
    }
}

private struct ButtonStyleModifier: ViewModifier {
    let style: DSButton.ButtonVariant
    
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.primaryStyle()
        case .secondary:
            content.secondaryStyle()
        case .destructive:
            content.destructiveStyle()
        case .ghost:
            content.ghostStyle()
        }
    }
}