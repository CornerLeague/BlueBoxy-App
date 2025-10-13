//
//  StorageManagementView.swift
//  BlueBoxy
//
//  Advanced storage management interface for message caching, cleanup, and analytics
//  Provides detailed storage statistics and optimization controls
//

import SwiftUI
import Charts

// MARK: - Storage Management View

struct StorageManagementView: View {
    
    // MARK: - Dependencies
    
    @ObservedObject var storageService: MessageStorageService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var statistics: MessageStorageStatistics?
    @State private var isLoading = true
    @State private var showingClearConfirmation = false
    @State private var clearAction: ClearAction = .oldMessages
    @State private var isOptimizing = false
    @State private var optimizationProgress: Double = 0.0
    @State private var showingExportConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let stats = statistics {
                        // Storage overview
                        StorageOverviewCard(stats: stats)
                        
                        // Category breakdown chart
                        CategoryBreakdownChart(stats: stats)
                        
                        // Storage actions
                        StorageActionsSection(
                            onOptimize: {
                                Task {
                                    await optimizeStorage()
                                }
                            },
                            onClearOld: {
                                clearAction = .oldMessages
                                showingClearConfirmation = true
                            },
                            onClearAll: {
                                clearAction = .allMessages
                                showingClearConfirmation = true
                            },
                            onExport: {
                                showingExportConfirmation = true
                            },
                            isOptimizing: isOptimizing
                        )
                        
                        // Detailed statistics
                        DetailedStatisticsSection(stats: stats)
                        
                    } else if isLoading {
                        LoadingCard()
                    } else {
                        ErrorCard {
                            await loadStatistics()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Storage Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadStatistics()
        }
        .alert("Clear Messages", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await performClearAction()
                }
            }
        } message: {
            Text(clearAction.confirmationMessage)
        }
        .alert("Export Messages", isPresented: $showingExportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                Task {
                    await exportAllData()
                }
            }
        } message: {
            Text("Export all message data and statistics to a JSON file?")
        }
    }
    
    // MARK: - Actions
    
    private func loadStatistics() async {
        isLoading = true
        
        let stats = await storageService.getStorageStatistics()
        
        await MainActor.run {
            self.statistics = stats
            self.isLoading = false
        }
    }
    
    private func optimizeStorage() async {
        await MainActor.run {
            self.isOptimizing = true
            self.optimizationProgress = 0.0
        }
        
        // Simulate optimization progress
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            await MainActor.run {
                self.optimizationProgress = progress
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await storageService.optimizeStorage()
        await loadStatistics()
        
        await MainActor.run {
            self.isOptimizing = false
        }
    }
    
    private func performClearAction() async {
        switch clearAction {
        case .oldMessages:
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            await storageService.cleanupOldRecords(olderThan: thirtyDaysAgo)
        case .allMessages:
            await storageService.clearAllMessages()
        }
        
        await loadStatistics()
    }
    
    private func exportAllData() async {
        // In a real implementation, this would create a comprehensive export
        print("📤 Exporting all storage data...")
    }
}

// MARK: - Supporting Types

enum ClearAction {
    case oldMessages
    case allMessages
    
    var confirmationMessage: String {
        switch self {
        case .oldMessages:
            return "Clear messages older than 30 days? This action cannot be undone."
        case .allMessages:
            return "Clear ALL stored messages? This action cannot be undone."
        }
    }
}

// MARK: - Supporting Views

struct StorageOverviewCard: View {
    let stats: MessageStorageStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StorageMetricCard(
                    title: "Total Messages",
                    value: "\(stats.totalMessages)",
                    subtitle: "Across all categories",
                    color: .blue,
                    systemImage: "message.fill"
                )
                
                StorageMetricCard(
                    title: "Storage Used",
                    value: String(format: "%.1f MB", stats.storageUsedMB),
                    subtitle: "Local storage",
                    color: .green,
                    systemImage: "externaldrive.fill"
                )
                
                StorageMetricCard(
                    title: "Favorites",
                    value: "\(stats.favoriteMessages)",
                    subtitle: "Saved messages",
                    color: .red,
                    systemImage: "heart.fill"
                )
                
                StorageMetricCard(
                    title: "Sessions",
                    value: "\(stats.generationRecords)",
                    subtitle: "Generation records",
                    color: .purple,
                    systemImage: "clock.arrow.circlepath"
                )
            }
            
            // Date range
            if let oldest = stats.oldestMessageDate, let newest = stats.newestMessageDate {
                VStack(spacing: 4) {
                    Text("Message Range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(oldest, style: .date)
                        Text("–")
                        Text(newest, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StorageMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct CategoryBreakdownChart: View {
    let stats: MessageStorageStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Messages by Category")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if stats.messagesPerCategory.isEmpty {
                Text("No data available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    // Simple bar chart representation
                    ForEach(Array(stats.messagesPerCategory.sorted { $0.value > $1.value }), id: \.key) { category, count in
                        CategoryBar(
                            category: category,
                            count: count,
                            percentage: Double(count) / Double(stats.totalMessages),
                            color: category.displayColor
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CategoryBar: View {
    let category: MessageCategoryType
    let count: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: category.systemImageName)
                        .font(.caption)
                        .foregroundColor(color)
                    
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                }
            }
            .frame(height: 4)
            .clipShape(Capsule())
        }
    }
}

struct StorageActionsSection: View {
    let onOptimize: () -> Void
    let onClearOld: () -> Void
    let onClearAll: () -> Void
    let onExport: () -> Void
    let isOptimizing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Storage Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                StorageActionButton(
                    title: "Optimize Storage",
                    subtitle: "Clean up and compress data",
                    systemImage: "arrow.clockwise",
                    color: .blue,
                    isLoading: isOptimizing,
                    action: onOptimize
                )
                
                StorageActionButton(
                    title: "Clear Old Messages",
                    subtitle: "Remove messages older than 30 days",
                    systemImage: "trash",
                    color: .orange,
                    action: onClearOld
                )
                
                StorageActionButton(
                    title: "Export Data",
                    subtitle: "Download all data as JSON",
                    systemImage: "square.and.arrow.up",
                    color: .green,
                    action: onExport
                )
                
                Divider()
                
                StorageActionButton(
                    title: "Clear All Messages",
                    subtitle: "Remove all stored messages",
                    systemImage: "trash.fill",
                    color: .red,
                    action: onClearAll
                )
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StorageActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(color)
                    } else {
                        Image(systemName: systemImage)
                            .font(.title3)
                            .foregroundColor(color)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
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
        .disabled(isLoading)
    }
}

struct DetailedStatisticsSection: View {
    let stats: MessageStorageStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Detailed Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                DetailStatRow(
                    label: "Average Messages per Session",
                    value: String(format: "%.1f", stats.averageMessagesPerGeneration)
                )
                
                if let oldestDate = stats.oldestMessageDate {
                    DetailStatRow(
                        label: "First Message",
                        value: DateFormatter.localizedString(from: oldestDate, dateStyle: .medium, timeStyle: .none)
                    )
                }
                
                if let newestDate = stats.newestMessageDate {
                    DetailStatRow(
                        label: "Latest Message",
                        value: DateFormatter.localizedString(from: newestDate, dateStyle: .medium, timeStyle: .none)
                    )
                }
                
                DetailStatRow(
                    label: "Storage Efficiency",
                    value: stats.totalMessages > 0 ? 
                    String(format: "%.1f KB per message", (stats.storageUsedMB * 1024) / Double(stats.totalMessages)) : 
                    "N/A"
                )
            }
        }
        .padding(20)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DetailStatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading storage statistics...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ErrorCard: View {
    let onRetry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Failed to load storage statistics")
                .font(.headline)
            
            Button("Retry") {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    let storageService = MessageStorageService.preview
    
    return StorageManagementView(storageService: storageService)
}