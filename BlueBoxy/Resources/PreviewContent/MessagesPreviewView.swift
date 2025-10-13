//
//  MessagesPreviewView.swift
//  BlueBoxy
//
//  Example view demonstrating message generation with SwiftUI preview support
//

import SwiftUI

struct MessagesPreviewView: View {
    let response: MessageGenerationResponse
    
    var body: some View {
        NavigationView {
            List(response.messages, id: \.id) { message in
                MessageRowView(message: message)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .navigationTitle("Generated Messages")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct MessageRowView: View {
    let message: MessageItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Message content
            Text(message.content)
                .bodyStyle()
                .fixedSize(horizontal: false, vertical: true)
            
            // Message metadata
            HStack {
                // Category badge
                Text(message.category.replacingOccurrences(of: "_", with: " ").capitalized)
                    .captionStyle()
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .cornerRadius(DesignSystem.Radius.xs)
                
                Spacer()
                
                // Impact indicator
                HStack(spacing: 2) {
                    ForEach(0..<(message.impactScore ?? 1), id: \.self) { _ in
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(impactColor)
                    }
                    ForEach(0..<(3 - (message.impactScore ?? 1)), id: \.self) { _ in
                        Image(systemName: "heart")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.mutedForeground)
                    }
                }
                
                // Tone
                Text(message.tone.capitalized)
                    .captionStyle()
                    .mutedStyle()
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private var impactColor: Color {
        switch message.estimatedImpact.lowercased() {
        case "high":
            return DesignSystem.Colors.success
        case "medium":
            return DesignSystem.Colors.warning
        case "low":
            return DesignSystem.Colors.mutedForeground
        default:
            return DesignSystem.Colors.mutedForeground
        }
    }
}

// MARK: - Profile Display View

struct UserProfilePreviewView: View {
    let user: DomainUser
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Profile Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Avatar placeholder
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(user.name.prefix(1))
                                    .h1Style()
                                    .primaryStyle()
                            )
                        
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text(user.name)
                                .h2Style()
                            
                            if let partnerName = user.partnerName {
                                Text("Partner: \(partnerName)")
                                    .bodyStyle()
                                    .mutedStyle()
                            }
                            
                            if let duration = user.relationshipDuration {
                                Text("Together for \(duration)")
                                    .captionStyle()
                                    .mutedStyle()
                            }
                        }
                    }
                    
                    // Personality Section
                    if let personality = user.personalityInsight {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Personality Insight")
                                .h3Style()
                            
                            Text(personality.description)
                                .bodyStyle()
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                InfoRow(icon: "heart", title: "Love Language", description: personality.loveLanguage)
                                InfoRow(icon: "bubble.left.and.bubble.right", title: "Communication Style", description: personality.communicationStyle)
                                InfoRow(icon: "exclamationmark.triangle", title: "Stress Response", description: personality.stressResponse)
                            }
                        }
                        .defaultPadding()
                        .background(DesignSystem.Colors.systemBackground)
                        .cardRadius()
                        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
                    }
                    
                    // Profile Completion
                    ProfileCompletionView(user: user)
                }
                .defaultPadding()
            }
            .navigationTitle("Profile")
        }
    }
}


struct ProfileCompletionView: View {
    let user: DomainUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Profile Completion")
                .h3Style()
            
            Text("Complete your profile to get better message suggestions")
                .captionStyle()
                .mutedStyle()
            
            ProgressView(value: completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primary))
            
            Text("\(Int(completionPercentage * 100))% Complete")
                .captionStyle()
                .primaryStyle()
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    private var completionPercentage: Double {
        var completed = 0
        let total = 6
        
        if !user.name.isEmpty { completed += 1 }
        if user.partnerName != nil { completed += 1 }
        if user.relationshipDuration != nil { completed += 1 }
        if user.personalityType != nil { completed += 1 }
        if user.personalityInsight != nil { completed += 1 }
        if user.preferences != nil { completed += 1 }
        
        return Double(completed) / Double(total)
    }
}

// MARK: - Previews

#Preview("Messages Preview") {
    #if DEBUG
    let mockClient = MockAPIClient()
    return MessagesPreviewView(response: mockClient.generateMessages())
    #else
    return Text("Preview not available in release builds")
    #endif
}

#Preview("Complete Profile") {
    #if DEBUG
    return UserProfilePreviewView(user: MockAPIClient.sampleUser)
    #else
    return Text("Preview not available in release builds")
    #endif
}

#Preview("New User Profile") {
    #if DEBUG
    return UserProfilePreviewView(user: MockAPIClient.shared.newUser().user)
    #else
    return Text("Preview not available in release builds")
    #endif
}

#Preview("Single Message") {
    #if DEBUG
    return MessageRowView(message: MockAPIClient.sampleMessages[0])
        .padding()
    #else
    return Text("Preview not available in release builds")
    #endif
}
