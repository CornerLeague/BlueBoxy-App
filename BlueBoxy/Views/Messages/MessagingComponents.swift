//
//  MessagingComponents.swift
//  BlueBoxy
//
//  Supporting UI components for the messaging interface including message cards,
//  loading states, contextual suggestions, and interactive elements.
//

import SwiftUI

// MARK: - Enhanced Message Card

struct EnhancedMessageCard: View {
    let message: ComprehensiveGeneratedMessage
    let messagingService: EnhancedMessagingService
    let onTap: (ComprehensiveGeneratedMessage) -> Void
    
    @State private var isExpanded = false
    @State private var showingCopyFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Impact indicator
                ImpactIndicator(impact: message.estimatedImpact)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(message.category.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ToneBadge(tone: message.tone)
                    }
                    
                    Text("Tailored for \(message.personalityMatch)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        copyMessage()
                    } label: {
                        Image(systemName: showingCopyFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(showingCopyFeedback ? .green : .blue)
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Message content
            VStack(alignment: .leading, spacing: 16) {
                // Main message
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary.opacity(0.5))
                    }
                    .onTapGesture {
                        onTap(message)
                    }
                
                // Expandable content
                if isExpanded {
                    VStack(spacing: 16) {
                        // Message metadata
                        MessageMetadataView(message: message)
                        
                        // Contextual factors
                        if !message.contextualFactors.userPersonalityType.isNilOrEmpty {
                            ContextualFactorsView(factors: message.contextualFactors)
                        }
                        
                        // Actions
                        MessageActionsView(message: message, messagingService: messagingService)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(message.estimatedImpact.color.opacity(0.3), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.content
        showingCopyFeedback = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCopyFeedback = false
        }
    }
}

// MARK: - Impact Indicator

struct ImpactIndicator: View {
    let impact: MessageImpact
    
    var body: some View {
        ZStack {
            Circle()
                .fill(impact.color.opacity(0.1))
                .frame(width: 40, height: 40)
            
            VStack(spacing: 2) {
                Circle()
                    .fill(impact.color)
                    .frame(width: 8, height: 8)
                
                Text("\(impact.numericValue)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(impact.color)
            }
        }
    }
}

// MARK: - Tone Badge

struct ToneBadge: View {
    let tone: MessageTone
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tone.emoji)
                .font(.caption2)
            
            Text(tone.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(tone.color.opacity(0.1))
                .stroke(tone.color.opacity(0.3), lineWidth: 1)
        }
        .foregroundStyle(tone.color)
    }
}

// MARK: - Message Metadata View

struct MessageMetadataView: View {
    let message: ComprehensiveGeneratedMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text("Message Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 20) {
                MetadataItem(
                    label: "Words",
                    value: "\(message.metadata.wordCount)",
                    systemImage: "text.alignleft"
                )
                
                MetadataItem(
                    label: "Reading Time",
                    value: "\(message.metadata.readingTimeSeconds)s",
                    systemImage: "clock"
                )
                
                if let deliveryTime = message.metadata.suggestedDeliveryTime {
                    MetadataItem(
                        label: "Best Time",
                        value: deliveryTime,
                        systemImage: "alarm"
                    )
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
                .stroke(.blue.opacity(0.1), lineWidth: 1)
        }
    }
}

struct MetadataItem: View {
    let label: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Contextual Factors View

struct ContextualFactorsView: View {
    let factors: ComprehensiveGeneratedMessage.MessageContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.purple)
                
                Text("Personalization")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let partnerName = factors.partnerName {
                    FactorRow(label: "Partner", value: partnerName)
                }
                
                if let personalityType = factors.userPersonalityType {
                    FactorRow(label: "Personality", value: personalityType)
                }
                
                FactorRow(label: "Time of Day", value: factors.timeOfDay.displayName)
                
                if let duration = factors.relationshipDuration {
                    FactorRow(label: "Together for", value: duration)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.purple.opacity(0.05))
                .stroke(.purple.opacity(0.1), lineWidth: 1)
        }
    }
}

struct FactorRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Message Actions View

struct MessageActionsView: View {
    let message: ComprehensiveGeneratedMessage
    let messagingService: EnhancedMessagingService
    
    @State private var showingShareSheet = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 12) {
                Button {
                    Task {
                        isProcessing = true
                        defer { isProcessing = false }
                        
                        do {
                            try await messagingService.saveMessage(message)
                        } catch {
                            // Handle error
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                        Text("Save")
                    }
                }
                .buttonStyle(CompactButtonStyle(variant: .secondary, isLoading: isProcessing))
                
                Button {
                    showingShareSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                .buttonStyle(CompactButtonStyle(variant: .primary))
                
                Button {
                    Task {
                        isProcessing = true
                        defer { isProcessing = false }
                        
                        do {
                            try await messagingService.favoriteMessage(message.id)
                        } catch {
                            // Handle error
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                        Text("Favorite")
                    }
                }
                .buttonStyle(CompactButtonStyle(variant: .secondary, isLoading: isProcessing))
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(
                activityItems: [messagingService.shareMessage(message)]
            )
        }
    }
}

// MARK: - Generation Loading View

struct GenerationLoadingView: View {
    @State private var animationOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wand.and.rays")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(animationOffset / 2))
            }
            
            VStack(spacing: 8) {
                Text("Generating Messages")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Creating personalized messages using AI...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.gradient)
                        .frame(width: max(0, animationOffset + 200), height: 8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationOffset)
                }
                .frame(width: 200)
            }
        }
        .padding(30)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animationOffset = 200
            }
        }
    }
}

// MARK: - Message Context Card

struct MessageContextCard: View {
    let context: ComprehensiveMessageResponse.MessageGenerationContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text("Generated for \(context.partnerName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ContextRow(label: "Category", value: context.category.capitalized)
                ContextRow(label: "Personality", value: context.personalityType)
                ContextRow(label: "Time", value: context.timeOfDay.displayName)
                
                if let stage = context.relationshipStage {
                    ContextRow(label: "Together for", value: stage)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.05))
                .stroke(.green.opacity(0.2), lineWidth: 1)
        }
    }
}

struct ContextRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Generation Metadata View

struct GenerationMetadataView: View {
    let metadata: ComprehensiveMessageResponse.ResponseMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text("Generation Stats")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Alternatives",
                    value: "\(metadata.totalAlternatives)",
                    icon: "doc.on.doc"
                )
                
                if let confidence = metadata.personalityMatchConfidence {
                    StatItem(
                        title: "Match",
                        value: "\(Int(confidence * 100))%",
                        icon: "target"
                    )
                }
                
                if metadata.canGenerateMore {
                    StatItem(
                        title: "More Available",
                        value: "✓",
                        icon: "plus.circle"
                    )
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.05))
                .stroke(.orange.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Contextual Suggestions View

struct ContextualSuggestionsView: View {
    let suggestions: [String]
    let onSuggestionTapped: (String) -> Void
    
    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120))
                ], spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSuggestionTapped(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    Capsule()
                                        .fill(.blue.opacity(0.1))
                                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                                }
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Time of Day Selector

struct TimeOfDaySelector: View {
    @Binding var selectedTime: TimeOfDay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time of Day")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                    Button {
                        selectedTime = timeOfDay
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timeOfDay.systemImageName)
                                .font(.caption2)
                            
                            Text(timeOfDay.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTime == timeOfDay {
                                Capsule()
                                    .fill(.blue.gradient)
                            } else {
                                Capsule()
                                    .fill(.quaternary.opacity(0.5))
                            }
                        }
                        .foregroundStyle(selectedTime == timeOfDay ? .white : .primary)
                    }
                }
            }
        }
    }
}

// MARK: - Message History Preview Card

struct MessageHistoryPreviewCard: View {
    let historyItem: MessageHistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ImpactIndicator(impact: MessageImpact(rawValue: historyItem.message.estimatedImpact.rawValue) ?? .medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(historyItem.message.content)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(historyItem.message.category.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(RelativeDateTimeFormatter().localizedString(for: historyItem.savedAt, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if historyItem.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Helper Extensions

extension String? {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}