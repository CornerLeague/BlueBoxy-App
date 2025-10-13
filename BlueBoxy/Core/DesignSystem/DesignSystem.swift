//
//  DesignSystem.swift
//  BlueBoxy
//
//  Central design system with colors, typography, spacing, and design tokens
//  Maps from Tailwind/CSS variables for consistency across platforms
//

import SwiftUI

enum DesignSystem {
    
    // MARK: - Colors
    enum Colors {
        // Base Colors (from Assets.xcassets or define dynamically)
        static let background = Color("Background") // add in Assets or define dynamically
        static let foreground = Color("Foreground")
        static let primary = Color("Primary")
        static let accent = Color("Accent")
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let error = Color("Error")
        
        // Semantic Colors
        static let cardBackground = Color("CardBackground")
        static let border = Color("Border")
        static let muted = Color("Muted")
        static let mutedForeground = Color("MutedForeground")
        
        // System Colors (fallbacks if Assets don't exist)
        static let systemBackground = Color(.systemBackground)
        static let systemForeground = Color(.label)
        static let systemSecondary = Color(.secondaryLabel)
        static let systemTertiary = Color(.tertiaryLabel)
        
        // Status Colors
        static let destructive = Color("Destructive")
        static let info = Color("Info")
    }
    
    // MARK: - Border Radius
    enum Radius {
        static let lg: CGFloat = 16
        static let md: CGFloat = 14
        static let sm: CGFloat = 12
        static let xs: CGFloat = 8
        static let full: CGFloat = 9999
    }
    
    // MARK: - Spacing (following Tailwind scale)
    enum Spacing {
        static let xs: CGFloat = 4      // 1
        static let sm: CGFloat = 8      // 2
        static let md: CGFloat = 12     // 3
        static let lg: CGFloat = 16     // 4
        static let xl: CGFloat = 20     // 5
        static let xxl: CGFloat = 24    // 6
        static let xxxl: CGFloat = 32   // 8
    }
    
    // MARK: - Typography
    enum Typography {
        // Font Sizes (following Tailwind text scale)
        enum Size {
            static let xs: CGFloat = 12
            static let sm: CGFloat = 14
            static let base: CGFloat = 16
            static let lg: CGFloat = 18
            static let xl: CGFloat = 20
            static let xxl: CGFloat = 24
            static let xxxl: CGFloat = 30
            static let xxxxl: CGFloat = 36
        }
        
        // Font Weights
        enum Weight {
            static let light = Font.Weight.light
            static let normal = Font.Weight.regular
            static let medium = Font.Weight.medium
            static let semibold = Font.Weight.semibold
            static let bold = Font.Weight.bold
        }
        
        // Predefined Font Styles
        static let h1 = Font.system(size: Size.xxxxl, weight: Weight.bold)
        static let h2 = Font.system(size: Size.xxxl, weight: Weight.bold)
        static let h3 = Font.system(size: Size.xxl, weight: Weight.semibold)
        static let h4 = Font.system(size: Size.xl, weight: Weight.semibold)
        static let body = Font.system(size: Size.base, weight: Weight.normal)
        static let bodyMedium = Font.system(size: Size.base, weight: Weight.medium)
        static let caption = Font.system(size: Size.sm, weight: Weight.normal)
        static let footnote = Font.system(size: Size.xs, weight: Weight.normal)
    }
    
    // MARK: - Shadows
    enum Shadow {
        static let sm = Color.black.opacity(0.1)
        static let md = Color.black.opacity(0.15)
        static let lg = Color.black.opacity(0.2)
    }
    
    // MARK: - Animation Durations
    enum Animation {
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.35
        
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: normal)
        static let easeIn = SwiftUI.Animation.easeIn(duration: fast)
        static let easeOut = SwiftUI.Animation.easeOut(duration: fast)
    }
    
    // MARK: - Layout
    enum Layout {
        static let minTouchTarget: CGFloat = 44
        static let maxContentWidth: CGFloat = 600
        static let defaultPadding: CGFloat = Spacing.lg
    }
}

// MARK: - Design System Extensions

extension View {
    // Apply design system colors
    func primaryStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    func mutedStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.mutedForeground)
    }
    
    // Apply design system typography
    func h1Style() -> some View {
        self.font(DesignSystem.Typography.h1)
    }
    
    func h2Style() -> some View {
        self.font(DesignSystem.Typography.h2)
    }
    
    func h3Style() -> some View {
        self.font(DesignSystem.Typography.h3)
    }
    
    func bodyStyle() -> some View {
        self.font(DesignSystem.Typography.body)
    }
    
    func captionStyle() -> some View {
        self.font(DesignSystem.Typography.caption)
    }
    
    // Apply design system spacing
    func defaultPadding() -> some View {
        self.padding(DesignSystem.Layout.defaultPadding)
    }
    
    // Apply design system corner radius
    func cardRadius() -> some View {
        self.cornerRadius(DesignSystem.Radius.md)
    }
    
    func buttonRadius() -> some View {
        self.cornerRadius(DesignSystem.Radius.sm)
    }
}