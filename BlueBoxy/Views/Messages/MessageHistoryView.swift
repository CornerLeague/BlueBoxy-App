//
//  MessageHistoryView.swift
//  BlueBoxy
//
//  Comprehensive message history view with search, filtering, analytics, and storage management
//  Integrates with MessageStorageService for local persistence and caching
//

import SwiftUI

// MARK: - Message History View

struct MessageHistoryView: View {
    
    // MARK: - Dependencies
    
    @StateObject private var storageService = MessageStorageService()
    @EnvironmentObject private var messagingService: EnhancedMessagingService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var messages: [ComprehensiveGeneratedMessage] = []
    @State private var filteredMessages: [ComprehensiveGeneratedMessage] = []
    @State private var favoriteMessageIds: Set<String> = []
    @State private var searchText = ""
    @State private var selectedCategory: MessageCategoryType?
    @State private var selectedTone: MessageTone?
    @State private var showingFavoritesOnly = false
    @State private var sortOrder: SortOrder = .newest
    @State private var showingStorageManagement = false
    @State private var showingMessageDetail: ComprehensiveGeneratedMessage?
    @State private var isLoading = true
    @State private var storageStats: MessageStorageStatistics?
    
    // MARK: - UI State
    
    @State private var selectedSegment: HistorySegment = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with statistics
                if let stats = storageStats {
                    StorageStatsHeaderView(stats: stats)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                // Filters and search
                filtersSection
                
                // Content
                messagesList
            }
            .navigationTitle("Message History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingStorageManagement = true
                        } label: {
                            Label("Storage Management", systemImage: "externaldrive")
                        }
                        
                        Button {
                            Task {
                                await exportMessages()
                            }
                        } label: {
                            Label("Export Messages", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Picker("Sort Order", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Label(order.displayName, systemImage: order.systemImage)
                                    .tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search messages...")
        .task {
            await loadData()
        }
        .onChange(of: searchText) { _ in
            filterMessages()
        }
        .onChange(of: selectedCategory) { _ in
            filterMessages()
        }
        .onChange(of: selectedTone) { _ in
            filterMessages()
        }
        .onChange(of: showingFavoritesOnly) { _ in
            filterMessages()
        }
        .onChange(of: sortOrder) { _ in
            sortMessages()
        }
        .onChange(of: selectedSegment) { _ in
            filterMessages()
        }
        .sheet(isPresented: $showingStorageManagement) {
            StorageManagementView(storageService: storageService)
        }
        .sheet(item: $showingMessageDetail) { message in
            MessageDetailView(message: message, storageService: storageService)
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Segment control
            Picker("History Segment", selection: $selectedSegment) {
                ForEach(HistorySegment.allCases, id: \.self) { segment in
                    Text(segment.displayName)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Favorites filter
                    FilterChip(
                        title: "Favorites",
                        systemImage: "heart.fill",
                        isSelected: showingFavoritesOnly,
                        count: favoriteMessageIds.count
                    ) {
                        showingFavoritesOnly.toggle()
                    }
                    
                    // Category filters
                    ForEach(MessageCategoryType.allCases.prefix(6), id: \.self) { category in
                        FilterChip(
                            title: category.displayName,
                            systemImage: category.systemImageName,
                            isSelected: selectedCategory == category,
                            count: messages.filter { $0.category == category }.count
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                    
                    // Tone filters
                    ForEach(MessageTone.allCases.prefix(4), id: \.self) { tone in
                        FilterChip(
                            title: tone.displayName,
                            systemImage: "waveform",
                            isSelected: selectedTone == tone,
                            count: messages.filter { $0.tone == tone }.count
                        ) {
                            selectedTone = selectedTone == tone ? nil : tone
                        }
                    }
                }
                .padding(.horizontal)
            }
            .contentMargins(.horizontal, 16)
            
            Divider()
        }
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading message history...")
            } else if filteredMessages.isEmpty {
                EmptyHistoryView(
                    hasMessages: !messages.isEmpty,
                    searchText: searchText,
                    onClearFilters: {
                        clearAllFilters()
                    }
                )
            } else {
                List {
                    ForEach(filteredMessages) { message in
                        MessageHistoryCard(
                            message: message,
                            isFavorited: favoriteMessageIds.contains(message.id),
                            onTap: {
                                showingMessageDetail = message
                            },
                            onFavorite: {
                                Task {
                                    await toggleFavorite(message)
                                }
                            },
                            onShare: {
                                shareMessage(message)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteMessages)
                }
                .listStyle(.plain)
                .refreshable {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        isLoading = true
        
        async let messagesLoad = storageService.loadRecentMessages(limit: 500)
        async let favoritesLoad = loadFavoriteIds()
        async let statsLoad = storageService.getStorageStatistics()
        
        do {
            let (loadedMessages, favoriteIds, stats) = await (messagesLoad, favoritesLoad, statsLoad)
            
            await MainActor.run {
                self.messages = loadedMessages ?? []
                self.favoriteMessageIds = favoriteIds
                self.storageStats = stats
                self.isLoading = false
                
                filterMessages()
            }
        }
    }
    
    private func loadFavoriteIds() async -> Set<String> {
        let favoriteMessages = await storageService.loadFavoriteMessages(limit: 1000)
        return Set((favoriteMessages ?? []).map { $0.id })
    }
    
    private func filterMessages() {
        var filtered = messages
        
        // Apply segment filter
        switch selectedSegment {
        case .all:
            break
        case .recent:
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            filtered = filtered.filter { $0.generatedAt >= oneWeekAgo }
        case .favorites:
            filtered = filtered.filter { favoriteMessageIds.contains($0.id) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let lowercaseSearch = searchText.lowercased()
            filtered = filtered.filter { message in
                message.content.lowercased().contains(lowercaseSearch) ||
                message.category.displayName.lowercased().contains(lowercaseSearch) ||
                message.tone.displayName.lowercased().contains(lowercaseSearch)
            }
        }
        
        // Apply category filter
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply tone filter
        if let selectedTone = selectedTone {
            filtered = filtered.filter { $0.tone == selectedTone }
        }
        
        // Apply favorites filter
        if showingFavoritesOnly {
            filtered = filtered.filter { favoriteMessageIds.contains($0.id) }
        }
        
        filteredMessages = filtered
        sortMessages()
    }
    
    private func sortMessages() {
        switch sortOrder {
        case .newest:
            filteredMessages.sort { $0.generatedAt > $1.generatedAt }
        case .oldest:
            filteredMessages.sort { $0.generatedAt < $1.generatedAt }
        case .category:
            filteredMessages.sort { $0.category.displayName < $1.category.displayName }
        case .impact:
            filteredMessages.sort { $0.estimatedImpact.numericValue > $1.estimatedImpact.numericValue }
        }
    }
    
    private func clearAllFilters() {
        searchText = ""
        selectedCategory = nil
        selectedTone = nil
        showingFavoritesOnly = false
        selectedSegment = .all
    }
    
    private func toggleFavorite(_ message: ComprehensiveGeneratedMessage) async {
        let isFavorited = favoriteMessageIds.contains(message.id)
        
        if isFavorited {
            favoriteMessageIds.remove(message.id)
            // Remove from storage favorites
        } else {
            favoriteMessageIds.insert(message.id)
            await storageService.favoriteMessage(message.id)
        }
    }
    
    private func shareMessage(_ message: ComprehensiveGeneratedMessage) {
        let shareText = message.content + "\n\n💕 Created with BlueBoxy"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        
        Task {
            await storageService.markMessageAsShared(message.id)
        }
    }
    
    private func deleteMessages(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let message = filteredMessages[index]
                await storageService.deleteMessage(message.id)
            }
            
            await loadData()
        }
    }
    
    private func exportMessages() async {
        let allMessages = await storageService.loadRecentMessages(limit: 10000) ?? []
        
        let exportData = allMessages.map { message in
            [
                "id": message.id,
                "content": message.content,
                "category": message.category.displayName,
                "tone": message.tone.displayName,
                "impact": message.estimatedImpact.displayName,
                "generated_at": ISO8601DateFormatter().string(from: message.generatedAt)
            ]
        }
        
        // Create and share JSON file
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BlueBoxy_Messages_Export.json")
            try jsonData.write(to: tempURL)
            
            let activityViewController = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityViewController, animated: true)
            }
        } catch {
            print("❌ Failed to export messages: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum HistorySegment: String, CaseIterable {
    case all = "All"
    case recent = "Recent"
    case favorites = "Favorites"
    
    var displayName: String {
        return rawValue
    }
}

enum SortOrder: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case category = "By Category"
    case impact = "By Impact"
    
    var displayName: String {
        return rawValue
    }
    
    var systemImage: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .category: return "folder"
        case .impact: return "heart.fill"
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2)
                
                Text(title)
                    .font(.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MessageHistoryCard: View {
    let message: ComprehensiveGeneratedMessage
    let isFavorited: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: message.category.systemImageName)
                            .font(.caption2)
                        Text(message.category.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(message.category.displayColor.opacity(0.2))
                    .foregroundColor(message.category.displayColor)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button(action: onFavorite) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(isFavorited ? .red : .secondary)
                        }
                        
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Footer
                HStack {
                    // Tone badge
                    HStack(spacing: 4) {
                        Text(message.tone.emoji)
                        Text(message.tone.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(message.tone.color.opacity(0.2))
                    .foregroundColor(message.tone.color)
                    .clipShape(Capsule())
                    
                    // Impact indicator
                    HStack(spacing: 2) {
                        ForEach(0..<message.estimatedImpact.numericValue, id: \.self) { _ in
                            Circle()
                                .fill(message.estimatedImpact.color)
                                .frame(width: 4, height: 4)
                        }
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(message.generatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StorageStatsHeaderView: View {
    let stats: MessageStorageStatistics
    
    var body: some View {
        HStack {
            StatItem(
                value: "\(stats.totalMessages)",
                label: "Messages",
                color: .blue
            )
            
            StatItem(
                value: "\(stats.favoriteMessages)",
                label: "Favorites",
                color: .red
            )
            
            StatItem(
                value: String(format: "%.1f MB", stats.storageUsedMB),
                label: "Storage",
                color: .green
            )
            
            StatItem(
                value: "\(stats.generationRecords)",
                label: "Sessions",
                color: .purple
            )
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


struct EmptyHistoryView: View {
    let hasMessages: Bool
    let searchText: String
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasMessages ? "magnifyingglass" : "message")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(hasMessages ? "No Results Found" : "No Messages Yet")
                    .font(.headline)
                
                Text(hasMessages ? 
                     "Try adjusting your search or filters" : 
                     "Your generated messages will appear here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if hasMessages && (!searchText.isEmpty) {
                Button("Clear Filters", action: onClearFilters)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - Preview

#Preview {
    MessageHistoryView()
        .environmentObject(EnhancedMessagingService(messagingNetworkClient: MessagingNetworkClient()))
}
