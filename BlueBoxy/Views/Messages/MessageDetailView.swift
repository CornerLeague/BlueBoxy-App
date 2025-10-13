//
//  MessageDetailView.swift
//  BlueBoxy
//
//  Detailed view for individual messages with comprehensive metadata,
//  sharing options, and storage management capabilities
//

import SwiftUI

// MARK: - Message Detail View

struct MessageDetailView: View {
    
    // MARK: - Properties
    
    let message: ComprehensiveGeneratedMessage
    let storageService: MessageStorageService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var isFavorited = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var copied = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Message content
                    MessageContentSection(message: message)
                    
                    // Message metadata
                    MessageMetadataSection(message: message)
                    
                    // Context information
                    MessageContextSection(message: message)
                    
                    // Actions
                    MessageActionsSection(
                        message: message,
                        isFavorited: isFavorited,
                        onCopy: copyMessage,
                        onShare: shareMessage,
                        onFavorite: toggleFavorite,
                        onDelete: {
                            showingDeleteConfirmation = true
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            copyMessage()
                        } label: {
                            Label("Copy Message", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            shareMessage()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button {
                            toggleFavorite()
                        } label: {
                            Label(
                                isFavorited ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: isFavorited ? "heart.slash" : "heart"
                            )
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await loadFavoriteStatus()
        }
        .alert("Delete Message", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMessage()
            }
        } message: {
            Text("Are you sure you want to delete this message? This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [createShareText()])
        }
    }
    
    // MARK: - Actions
    
    private func loadFavoriteStatus() async {
        let favoriteMessages = await storageService.loadFavoriteMessages(limit: 1000)
        isFavorited = favoriteMessages?.contains { $0.id == message.id } ?? false
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.content
        
        // Show copied feedback
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func shareMessage() {
        showingShareSheet = true
        
        Task {
            await storageService.markMessageAsShared(message.id)
        }
    }
    
    private func toggleFavorite() {
        isFavorited.toggle()
        
        Task {
            if isFavorited {
                await storageService.favoriteMessage(message.id)
            } else {
                // In a real implementation, you'd have an unfavorite method
                await storageService.favoriteMessage(message.id) // Placeholder
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func deleteMessage() {
        Task {
            await storageService.deleteMessage(message.id)
        }
        
        dismiss()
    }
    
    private func createShareText() -> String {
        var shareText = message.content
        
        // Add context if available
        if let partnerName = message.contextualFactors.partnerName {
            shareText += "\n\n💕 For \(partnerName)"
        }
        
        shareText += "\n\nCreated with BlueBoxy"
        
        return shareText
    }
}

// MARK: - Supporting Views

struct MessageContentSection: View {
    let message: ComprehensiveGeneratedMessage
    
    var body: some View {
        VStack(spacing: 16) {
            // Category and impact header
            HStack {
                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: message.category.systemImageName)
                        .font(.caption)
                    Text(message.category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(message.category.displayColor.opacity(0.2))
                .foregroundColor(message.category.displayColor)
                .clipShape(Capsule())
                
                Spacer()
                
                // Impact indicator
                HStack(spacing: 4) {
                    ForEach(0..<message.estimatedImpact.numericValue, id: \.self) { _ in
                        Circle()
                            .fill(message.estimatedImpact.color)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            
            // Message content
            Text(message.content)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tone badge
            HStack {
                HStack(spacing: 6) {
                    Text(message.tone.emoji)
                    Text(message.tone.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(message.tone.color.opacity(0.2))
                .foregroundColor(message.tone.color)
                .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MessageMetadataSection: View {
    let message: ComprehensiveGeneratedMessage
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Message Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                MetadataRow(
                    label: "Generated",
                    value: DateFormatter.localizedString(
                        from: message.generatedAt,
                        dateStyle: .medium,
                        timeStyle: .short
                    ),
                    systemImage: "clock"
                )
                
                MetadataRow(
                    label: "Word Count",
                    value: "\(message.metadata.wordCount) words",
                    systemImage: "textformat"
                )
                
                MetadataRow(
                    label: "Reading Time",
                    value: "\(message.metadata.readingTimeSeconds)s",
                    systemImage: "timer"
                )
                
                if let sentimentScore = message.metadata.sentimentScore {
                    MetadataRow(
                        label: "Sentiment",
                        value: String(format: "%.0f%% positive", sentimentScore * 100),
                        systemImage: "heart"
                    )
                }
                
                if let confidenceScore = message.metadata.confidenceScore {
                    MetadataRow(
                        label: "AI Confidence",
                        value: String(format: "%.0f%%", confidenceScore * 100),
                        systemImage: "brain.head.profile"
                    )
                }
                
                if let deliveryTime = message.metadata.suggestedDeliveryTime {
                    MetadataRow(
                        label: "Best Time to Send",
                        value: deliveryTime,
                        systemImage: "paperplane"
                    )
                }
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MessageContextSection: View {
    let message: ComprehensiveGeneratedMessage
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Generation Context")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                if let partnerName = message.contextualFactors.partnerName {
                    MetadataRow(
                        label: "Partner",
                        value: partnerName,
                        systemImage: "person.fill"
                    )
                }
                
                MetadataRow(
                    label: "Time of Day",
                    value: message.contextualFactors.timeOfDay.displayName,
                    systemImage: message.contextualFactors.timeOfDay.systemImageName
                )
                
                if let duration = message.contextualFactors.relationshipDuration {
                    MetadataRow(
                        label: "Relationship Duration",
                        value: duration,
                        systemImage: "heart.circle"
                    )
                }
                
                if let recentContext = message.contextualFactors.recentContext, !recentContext.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Recent Context")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Text(recentContext)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 20)
                    }
                }
                
                if let specialOccasion = message.contextualFactors.specialOccasion, !specialOccasion.isEmpty {
                    MetadataRow(
                        label: "Special Occasion",
                        value: specialOccasion,
                        systemImage: "party.popper"
                    )
                }
                
                MetadataRow(
                    label: "Personality Match",
                    value: message.personalityMatch.capitalized,
                    systemImage: "person.crop.circle.badge.checkmark"
                )
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MessageActionsSection: View {
    let message: ComprehensiveGeneratedMessage
    let isFavorited: Bool
    let onCopy: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ActionButton(
                    title: "Copy Message",
                    subtitle: "Copy to clipboard",
                    systemImage: "doc.on.doc",
                    color: .blue,
                    action: onCopy
                )
                
                ActionButton(
                    title: "Share Message",
                    subtitle: "Send via messages, email, or social",
                    systemImage: "square.and.arrow.up",
                    color: .green,
                    action: onShare
                )
                
                ActionButton(
                    title: isFavorited ? "Remove from Favorites" : "Add to Favorites",
                    subtitle: isFavorited ? "Remove from saved messages" : "Save to favorites",
                    systemImage: isFavorited ? "heart.slash" : "heart.fill",
                    color: .red,
                    action: onFavorite
                )
                
                Divider()
                
                ActionButton(
                    title: "Delete Message",
                    subtitle: "Remove from storage",
                    systemImage: "trash",
                    color: .red,
                    isDestructive: true,
                    action: onDelete
                )
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .center)
            
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? color : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Preview

#Preview {
    let sampleMessage = ComprehensiveGeneratedMessage(
        id: "sample-1",
        content: "You make every day brighter just by being in it. I love you! 💕",
        category: .romantic,
        personalityMatch: "high",
        tone: .romantic,
        estimatedImpact: .high,
        context: ComprehensiveGeneratedMessage.MessageContext(
            timeOfDay: .evening,
            relationshipDuration: "2 years",
            recentContext: "After our wonderful dinner date",
            specialOccasion: "Anniversary",
            userPersonalityType: "romantic",
            partnerName: "Sarah"
        ),
        generatedAt: Date()
    )
    
    return MessageDetailView(
        message: sampleMessage,
        storageService: MessageStorageService.preview
    )
}