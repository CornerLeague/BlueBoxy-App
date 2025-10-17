import SwiftUI

struct AIMessageCard: View {
    let message: AIGeneratedMessage
    @State private var isExpanded = false
    @State private var isCopied = false
    @State private var showingCustomization = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // AI indicator
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("AI Generated")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        // Confidence indicator
                        if let confidence = message.confidenceScore {
                            ConfidenceIndicator(score: confidence)
                        }
                    }
                    
                    Text(message.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Expand/collapse button
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Message content
            VStack(alignment: .leading, spacing: 16) {
                // Main message
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Copy button
                        Button {
                            copyMessage()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                Text(isCopied ? "Copied" : "Copy")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary.opacity(0.5))
                        )
                }
                
                // Expandable content
                if isExpanded {
                    VStack(spacing: 16) {
                        // Context/reasoning
                        if let context = message.context, !context.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text("Why this works")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Text(context)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.yellow.opacity(0.1))
                            )
                        }
                        
                        // Alternative suggestions
                        if !message.alternatives.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text("Alternative Options")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                VStack(spacing: 6) {
                                    ForEach(Array(message.alternatives.enumerated()), id: \.offset) { index, alternative in
                                        AlternativeMessageRow(
                                            message: alternative,
                                            index: index + 1
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Customization tips
                        if !message.customizationTips.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                    Text("Customization Tips")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(message.customizationTips, id: \.self) { tip in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(.purple)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 6)
                                            
                                            Text(tip)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.purple.opacity(0.1))
                            )
                        }
                    }
                }
            }
            .padding(16)
            
            // Action buttons
            if isExpanded {
                Divider()
                
                HStack(spacing: 12) {
                    Button("Regenerate") {
                        // Regenerate message
                    }
                    .buttonStyle(CompactButtonStyle(variant: .secondary))
                    
                    Button("Customize") {
                        showingCustomization = true
                    }
                    .buttonStyle(CompactButtonStyle(variant: .primary))
                    
                    Spacer()
                    
                    // Rating buttons
                    HStack(spacing: 8) {
                        Button {
                            // Rate thumbs up
                        } label: {
                            Image(systemName: "hand.thumbsup")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        Button {
                            // Rate thumbs down
                        } label: {
                            Image(systemName: "hand.thumbsdown")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingCustomization) {
            MessageCustomizationView(message: message)
        }
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.content
        isCopied = true
        
        // Reset copy state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

struct ConfidenceIndicator: View {
    let score: Double
    
    private var color: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }
    
    private var description: String {
        switch score {
        case 0.8...1.0: return "High"
        case 0.6..<0.8: return "Medium"
        default: return "Low"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(description)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

struct AlternativeMessageRow: View {
    let message: String
    let index: Int
    @State private var isCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Index indicator
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(.green.opacity(0.1))
                )
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            
            Spacer()
            
            Button {
                copyAlternative()
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func copyAlternative() {
        UIPasteboard.general.string = message
        isCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

// MARK: - Message Customization View

struct MessageCustomizationView: View {
    let message: AIGeneratedMessage
    @Environment(\.dismiss) private var dismiss
    
    @State private var tone: MessageTone = .warm
    @State private var length: MessageLength = .medium
    @State private var includeEmojis = true
    @State private var customPrompt = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            Form {
                toneSection
                lengthSection
                styleSection
                instructionsSection
            }
            .navigationTitle("Customize Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        generateCustomMessage()
                    }
                    .buttonStyle(CompactButtonStyle(isLoading: isGenerating))
                    .disabled(isGenerating)
                }
            }
        }
    }
    
    private var toneSection: some View {
        Section("Tone") {
            Picker("Message Tone", selection: $tone) {
                ForEach(MessageTone.allCases, id: \.self) { messageTone in
                    HStack {
                        Text(messageTone.emoji)
                        Text(messageTone.displayName)
                            .foregroundStyle(messageTone.color)
                    }
                    .tag(messageTone)
                }
            }
            .pickerStyle(WheelPickerStyle())
        }
    }
    
    private var lengthSection: some View {
        Section("Length") {
            Picker("Message Length", selection: $length) {
                ForEach(MessageLength.allCases, id: \.self) { length in
                    Text(length.displayName)
                        .tag(length)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var styleSection: some View {
        Section("Style") {
            Toggle("Include Emojis", isOn: $includeEmojis)
        }
    }
    
    private var instructionsSection: some View {
        Section("Additional Instructions") {
            TextField("Any specific requests...", text: $customPrompt, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func generateCustomMessage() {
        isGenerating = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isGenerating = false
            dismiss()
        }
    }
}

// MARK: - Supporting Types

struct AIGeneratedMessage: Codable, Identifiable {
    let id = UUID()
    let content: String
    let category: MessageCategoryType
    let context: String?
    let alternatives: [String]
    let customizationTips: [String]
    let confidenceScore: Double?
    let generatedAt: Date
}

// MessageCategory and MessageTone are defined in Models/MessageCategoryModels.swift

enum MessageLength: String, CaseIterable, Codable {
    case short = "short"
    case medium = "medium"
    case long = "long"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

#Preview {
    AIMessageCard(message: AIGeneratedMessage(
        content: "Hey babe! I know you've been stressed with work lately. How about we have a cozy movie night tonight? I'll order from that Thai place you love and we can just relax together. What do you think? ❤️",
        category: .support,
        context: "This message acknowledges their stress and offers a specific, low-key solution that shows care and consideration for their current state.",
        alternatives: [
            "I noticed you've been working really hard. Want to take a break together tonight?",
            "You deserve some relaxation after this tough week. Movie night and takeout?"
        ],
        customizationTips: [
            "Add their favorite movie genre",
            "Mention a specific restaurant they love",
            "Include plans for tomorrow if they're still stressed"
        ],
        confidenceScore: 0.89,
        generatedAt: Date()
    ))
    .padding()
}