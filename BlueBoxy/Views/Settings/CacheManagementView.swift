import SwiftUI
import Foundation

struct CacheManagementView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var cacheStatus: CacheStatus?
    @State private var showingClearConfirmation = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    LoadingView(message: "Loading cache status...", style: .inline)
                } else if let status = cacheStatus {
                    cacheOverviewSection(status: status)
                    cacheDetailsSection(status: status)
                    cacheActionsSection()
                }
            }
            .navigationTitle("Cache Management")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadCacheStatus()
            }
            .alert("Clear Cache", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await clearCache()
                    }
                }
            } message: {
                Text("This will remove all cached data and may slow down the next app launch. Are you sure?")
            }
            .task {
                await loadCacheStatus()
            }
        }
    }
    
    @ViewBuilder
    private func cacheOverviewSection(status: CacheStatus) -> some View {
        Section("Overview") {
            // Cache size
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cache Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(status.formattedCacheSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                CacheHealthIndicator(score: status.cacheHealthScore)
            }
            .padding(.vertical, 4)
            
            // Last updated
            if let lastUpdated = status.lastUpdated {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Updated")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(formatRelativeDate(lastUpdated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private func cacheDetailsSection(status: CacheStatus) -> some View {
        Section("Cache Status") {
            CacheItemRow(
                title: "Activities",
                isExpired: status.activitiesExpired,
                icon: "mappin.and.ellipse"
            )
            
            CacheItemRow(
                title: "Statistics",
                isExpired: status.statsExpired,
                icon: "chart.bar.fill"
            )
            
            CacheItemRow(
                title: "Events",
                isExpired: status.eventsExpired,
                icon: "calendar"
            )
        }
    }
    
    @ViewBuilder
    private func cacheActionsSection() -> some View {
        Section("Actions") {
            Button("Refresh Cache Status") {
                Task {
                    await loadCacheStatus()
                }
            }
            .foregroundStyle(.blue)
            
            Button("Clear All Cache") {
                showingClearConfirmation = true
            }
            .foregroundStyle(.red)
        }
        
        Section("Information") {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "info.circle",
                    title: "What is cache?",
                    description: "Cache stores data locally to make the app faster and work offline."
                )
                
                InfoRow(
                    icon: "clock",
                    title: "When does cache expire?",
                    description: "Activities: 30 min, Stats: 1 hour, Events: 15 min"
                )
                
                InfoRow(
                    icon: "wifi.slash",
                    title: "Offline support",
                    description: "Cached data allows the app to work without internet connection."
                )
            }
            .padding(.vertical, 8)
        }
    }
    
    private func loadCacheStatus() async {
        isLoading = true
        
        // Simulate loading delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // This would need to be implemented in your actual DashboardViewModel
        // For now, we'll create a mock status
        let mockStatus = CacheStatus(
            activitiesExpired: false,
            statsExpired: true,
            eventsExpired: false,
            totalCacheSize: cacheManager.cacheSize,
            lastUpdated: Date().addingTimeInterval(-300) // 5 minutes ago
        )
        
        cacheStatus = mockStatus
        isLoading = false
    }
    
    private func clearCache() async {
        await cacheManager.clear()
        await loadCacheStatus()
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CacheStatus {
    let activitiesExpired: Bool
    let statsExpired: Bool
    let eventsExpired: Bool
    let totalCacheSize: Int64
    let lastUpdated: Date?

    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCacheSize)
    }

    var hasExpiredData: Bool {
        activitiesExpired || statsExpired || eventsExpired
    }

    var cacheHealthScore: Double {
        let expiredCount = [activitiesExpired, statsExpired, eventsExpired].filter { $0 }.count
        return Double(3 - expiredCount) / 3.0
    }
}

struct CacheHealthIndicator: View {
    let score: Double
    
    private var color: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    private var status: String {
        switch score {
        case 0.8...1.0: return "Excellent"
        case 0.5..<0.8: return "Good"
        default: return "Needs Refresh"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Health circle
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Cache Health")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
    }
}

struct CacheItemRow: View {
    let title: String
    let isExpired: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isExpired ? .red : .green)
                    .frame(width: 8, height: 8)
                
                Text(isExpired ? "Expired" : "Fresh")
                    .font(.caption)
                    .foregroundStyle(isExpired ? .red : .green)
            }
        }
        .padding(.vertical, 2)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Cache Statistics View

struct CacheStatisticsView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var cacheBreakdown: [CacheBreakdownItem] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section("Storage Breakdown") {
                    ForEach(cacheBreakdown, id: \.name) { item in
                        CacheBreakdownRow(item: item)
                    }
                }
                
                Section("Performance Metrics") {
                    MetricRow(title: "Cache Hit Rate", value: "87%", color: .green)
                    MetricRow(title: "Avg Load Time", value: "0.3s", color: .blue)
                    MetricRow(title: "Offline Sessions", value: "12", color: .orange)
                }
            }
            .navigationTitle("Cache Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                loadCacheBreakdown()
            }
        }
    }
    
    private func loadCacheBreakdown() {
        // Mock data - in real app, this would come from cache analytics
        cacheBreakdown = [
            CacheBreakdownItem(name: "Activities", size: 2048000, percentage: 45),
            CacheBreakdownItem(name: "Images", size: 1536000, percentage: 35),
            CacheBreakdownItem(name: "User Data", size: 512000, percentage: 12),
            CacheBreakdownItem(name: "Other", size: 356000, percentage: 8)
        ]
    }
}

struct CacheBreakdownItem {
    let name: String
    let size: Int64
    let percentage: Double
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct CacheBreakdownRow: View {
    let item: CacheBreakdownItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(item.percentage))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(.blue)
                            .frame(width: geometry.size.width * (item.percentage / 100), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CacheManagementView()
}

#Preview("Statistics") {
    CacheStatisticsView()
}