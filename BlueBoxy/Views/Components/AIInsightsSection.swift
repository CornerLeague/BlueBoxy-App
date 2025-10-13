import SwiftUI

struct AIInsightsSection: View {
    let insight: PersonalityInsightDisplay
    @State private var isExpanded = false
    @State private var showingFullAnalysis = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with expand/collapse
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("AI Insights")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(isExpanded ? "Show Less" : "Show More") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.purple)
            }
            .padding(.horizontal)
            
            // Insights cards
            VStack(spacing: 12) {
                // Always visible - Primary insight
                InsightCard(
                    title: "Your Love Language",
                    content: insight.loveLanguage,
                    icon: "heart.fill",
                    color: .red,
                    priority: .high
                )
                
                // Expandable content
                if isExpanded {
                    InsightCard(
                        title: "Communication Style",
                        content: insight.communicationStyle,
                        icon: "bubble.left.and.bubble.right.fill",
                        color: .blue,
                        priority: .medium
                    )
                    
                    InsightCard(
                        title: "Conflict Resolution",
                        content: insight.conflictResolution ?? "Balanced approach to resolving disagreements",
                        icon: "scale.3d",
                        color: .orange,
                        priority: .medium
                    )
                    
                    InsightCard(
                        title: "Stress Response",
                        content: insight.stressResponse,
                        icon: "brain.head.profile",
                        color: .purple,
                        priority: .medium
                    )
                    
                    // Ideal Activities section
                    IdealActivitiesCard(activities: insight.idealActivities)
                    
                    // Compatibility insights
                    if let compatibility = insight.compatibilityTips {
                        CompatibilityTipsCard(tips: compatibility)
                    }
                    
                    // Growth areas
                    if let growthAreas = insight.growthAreas {
                        GrowthAreasCard(areas: growthAreas)
                    }
                }
                
                // AI Analysis summary - always visible
                DescriptionCard(description: insight.description)
                
                // Full analysis button
                if isExpanded {
                    Button("View Detailed Analysis") {
                        showingFullAnalysis = true
                    }
                    .buttonStyle(CompactButtonStyle(variant: .primary))
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingFullAnalysis) {
            FullAIAnalysisView(insight: insight)
        }
    }
}

struct InsightCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    let priority: InsightPriority
    
    enum InsightPriority {
        case high, medium, low
        
        var borderWidth: CGFloat {
            switch self {
            case .high: return 2
            case .medium: return 1
            case .low: return 0.5
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .high: return 4
            case .medium: return 2
            case .low: return 1
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(priority == .high ? nil : 3)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .stroke(color.opacity(0.2), lineWidth: priority.borderWidth)
        )
        .shadow(color: color.opacity(0.1), radius: priority.shadowRadius, x: 0, y: 2)
        .padding(.horizontal)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }
}

struct IdealActivitiesCard: View {
    let activities: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                
                Text("Ideal Activities")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(activities.enumerated()), id: \.offset) { index, activity in
                    ActivityChip(activity: activity, index: index)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.green.opacity(0.05))
                .stroke(.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct ActivityChip: View {
    let activity: String
    let index: Int
    
    private var chipColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo]
        return colors[index % colors.count]
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
            
            Text(activity)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.quaternary.opacity(0.5))
        )
        .overlay(
            Capsule()
                .stroke(chipColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CompatibilityTipsCard: View {
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.pink.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                }
                
                Text("Compatibility Tips")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.pink)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(.pink.opacity(0.1))
                            )
                        
                        Text(tip)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.pink.opacity(0.05))
                .stroke(.pink.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct GrowthAreasCard: View {
    let areas: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                }
                
                Text("Growth Opportunities")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(areas, id: \.self) { area in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.teal)
                        
                        Text(area)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.teal.opacity(0.05))
                .stroke(.teal.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct DescriptionCard: View {
    let description: String
    @State private var isExpanded = false
    
    private var truncatedDescription: String {
        if description.count <= 150 {
            return description
        }
        let truncated = String(description.prefix(150))
        return truncated + "..."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.yellow.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                }
                
                Text("AI Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if description.count > 150 {
                    Button(isExpanded ? "Show Less" : "Read More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.8))
                }
            }
            
            Text(isExpanded ? description : truncatedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.yellow.opacity(0.05))
                .stroke(.yellow.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Full Analysis View

struct FullAIAnalysisView: View {
    let insight: PersonalityInsightDisplay
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.purple.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundStyle(.purple)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Complete AI Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Comprehensive personality insights and recommendations")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Detailed sections
                    VStack(spacing: 20) {
                        DetailedInsightSection(
                            title: "Personality Overview",
                            content: insight.description,
                            icon: "person.circle.fill",
                            color: .purple
                        )
                        
                        DetailedInsightSection(
                            title: "Love Language Deep Dive",
                            content: insight.loveLanguageDescription ?? insight.loveLanguage,
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        DetailedInsightSection(
                            title: "Communication Analysis",
                            content: insight.communicationAnalysis ?? insight.communicationStyle,
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .blue
                        )
                        
                        if let stressAnalysis = insight.stressAnalysis {
                            DetailedInsightSection(
                                title: "Stress Management",
                                content: stressAnalysis,
                                icon: "brain.head.profile",
                                color: .orange
                            )
                        }
                        
                        if let relationshipAdvice = insight.relationshipAdvice {
                            DetailedInsightSection(
                                title: "Relationship Advice",
                                content: relationshipAdvice,
                                icon: "heart.text.square.fill",
                                color: .pink
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailedInsightSection: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Models

struct PersonalityInsightDisplay: Codable, Identifiable {
    let id = UUID()
    let loveLanguage: String
    let loveLanguageDescription: String?
    let communicationStyle: String
    let communicationAnalysis: String?
    let stressResponse: String
    let stressAnalysis: String?
    let conflictResolution: String?
    let idealActivities: [String]
    let compatibilityTips: [String]?
    let growthAreas: [String]?
    let description: String
    let relationshipAdvice: String?
    let confidenceScore: Double?
}

#Preview {
    AIInsightsSection(insight: PersonalityInsightDisplay(
        loveLanguage: "Quality Time",
        loveLanguageDescription: "You value undivided attention and meaningful moments together.",
        communicationStyle: "Direct and Honest",
        communicationAnalysis: "You prefer straightforward communication and appreciate honesty.",
        stressResponse: "Problem-solving focused",
        stressAnalysis: "You tend to tackle stress head-on by finding practical solutions.",
        conflictResolution: "Collaborative approach",
        idealActivities: ["Cooking together", "Nature walks", "Board games", "Deep conversations"],
        compatibilityTips: ["Schedule regular one-on-one time", "Minimize distractions during conversations"],
        growthAreas: ["Practice active listening", "Express appreciation more often"],
        description: "You are a thoughtful and caring partner who values deep connections and meaningful experiences.",
        relationshipAdvice: "Focus on creating regular opportunities for quality time together without distractions.",
        confidenceScore: 0.87
    ))
}