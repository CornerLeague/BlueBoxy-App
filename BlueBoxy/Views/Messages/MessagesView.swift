//
//  MessagesView.swift
//  BlueBoxy
//
//  Main messaging interface that integrates with EnhancedMessagingService
//  and provides comprehensive message generation and management capabilities.
//

import SwiftUI

struct MessagesView: View {
    
    // MARK: - Dependencies
    
    @StateObject private var messagingService = EnhancedMessagingService(messagingNetworkClient: MessagingNetworkClient())
    @StateObject private var retryableService = RetryableMessagingService.preview
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    // MARK: - State
    
    @State private var showingContextInput = false
    @State private var showingSettings = false
    @State private var selectedMessage: ComprehensiveGeneratedMessage?
    @State private var showingHistory = false
    @State private var errorBanner: NetworkError?
    
    // MARK: - UI State
    
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var contextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Error banner at top
                if let error = errorBanner {
                    MessagingErrorBanner(
                        error: error,
                        onRetry: {
                            Task {
                                await handleRetryFromBanner()
                            }
                        },
                        onDismiss: {
                            errorBanner = nil
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Network status indicator
                NetworkStatusIndicator()
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        headerSection
                        
                        // Categories with error handling
                        categoriesWithErrorHandling
                        
                        selectedCategoryCard
                        
                        contextInputSection
                        
                        generatedMessagesSection
                        
                        emptyState
                        
                        recentMessagesSection
                    }
                    .padding(.horizontal)
                    .padding(.bottom, keyboardHeight)
                }
            }
            .navigationTitle("AI Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingHistory = true
                        } label: {
                            Label("Message History", systemImage: "clock")
                        }
                        
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Button {
                            Task {
                                await messagingService.loadCategories(forceRefresh: true)
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: authViewModel.user?.id) { userId in
            if let userId = userId, let user = authViewModel.user {
                Task {
                    print("👤 User became available (ID: \(userId)), loading personalized content")
                    await messagingService.loadPersonalizedRecommendations(for: user)
                    await messagingService.loadHistory(limit: 10, offset: 0)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            // TODO: Create MessagingSettingsView or use alternative settings view
            VStack {
                Text("Settings")
                    .font(.title)
                    .padding()
                Text("Messaging settings coming soon")
                    .padding()
                Button("Done") {
                    showingSettings = false
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingHistory) {
            MessageHistoryView()
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailView(message: message, storageService: MessageStorageService())
        }
        .alert("Error", isPresented: .constant(messagingService.generationState.error != nil)) {
            Button("OK") {
                messagingService.clearGeneration()
            }
        } message: {
            Text(messagingService.generationState.error?.localizedDescription ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            handleKeyboardShow(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "wand.and.rays.inverse")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Message Generator")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let user = authViewModel.user {
                        Text("Personalized for \(user.partnerName ?? "your partner")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Quick stats
            if let statistics = messagingService.messageStatistics {
                MessageStatsView(statistics: statistics)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Categories Section
    
    private func categoriesSection(categories: [DetailedMessageCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Message Categories")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if case .loaded(let recommendations) = messagingService.recommendationsState {
                    Button("See Recommendations") {
                        // Show personalized recommendations
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories) { category in
                        MessageCategoryButton(
                            category: category,
                            isSelected: messagingService.selectedCategory == category.type,
                            isLoading: messagingService.isGenerating
                        ) {
                            messagingService.selectedCategory = category.type
                        }
                    }
                }
                .padding(.horizontal)
            }
            .contentMargins(.horizontal, 20)
        }
    }
    
    // MARK: - Selected Category Card
    
    private var selectedCategoryCard: some View {
        Group {
            if let selectedCategory = messagingService.selectedCategory,
               let categoryDetails = messagingService.currentCategories.first(where: { $0.type == selectedCategory }) {
                
                SelectedCategoryCard(
                    category: categoryDetails,
                    isGenerating: messagingService.isGenerating,
                    canGenerate: messagingService.canGenerate
                ) {
                    Task {
                        guard let user = authViewModel.user else { return }
                        await messagingService.generateMessages(for: user)
                    }
                }
                .disabled(messagingService.isGenerating)
            }
        }
    }
    
    // MARK: - Context Input Section
    
    private var contextInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Context")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingContextInput.toggle()
                    }
                } label: {
                    Image(systemName: showingContextInput ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if showingContextInput {
                VStack(spacing: 12) {
                    // Recent context input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's happening?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., After our wonderful date last night...", text: $messagingService.recentContext)
                            .textFieldStyle(.roundedBorder)
                            .focused($contextFieldFocused)
                    }
                    
                    // Special occasion input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Special occasion?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., Anniversary, Birthday, Just because...", text: $messagingService.specialOccasion)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Contextual suggestions
                    if let user = authViewModel.user {
                        ContextualSuggestionsView(
                            suggestions: messagingService.getContextualSuggestions(for: user),
                            onSuggestionTapped: { suggestion in
                                messagingService.recentContext = suggestion
                                contextFieldFocused = false
                            }
                        )
                    }
                    
                    // Time of day selector
                    TimeOfDaySelector(selectedTime: $messagingService.selectedTimeOfDay)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingContextInput)
    }
    
    // MARK: - Generated Messages Section
    
    private var generatedMessagesSection: some View {
        Group {
            if case .loading = messagingService.generationState {
                MessagingLoadingView(
                    message: "Generating personalized messages...",
                    progress: nil,
                    error: nil,
                    onRetry: nil,
                    onCancel: {
                        messagingService.clearGeneration()
                    }
                )
            } else if case .loaded(let response) = messagingService.generationState {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Generated Messages")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Clear") {
                            withAnimation(.easeOut(duration: 0.3)) {
                                messagingService.clearGeneration()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // Context is not optional, so display it directly
                    MessageContextCard(context: response.context)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(response.messages) { message in
                            EnhancedMessageCard(
                                message: message,
                                messagingService: messagingService
                            ) { message in
                                selectedMessage = message
                            }
                        }
                    }
                    
                    // Metadata is not optional, so display it directly
                    GenerationMetadataView(metadata: response.metadata)
                }
            } else if case .failed(let error) = messagingService.generationState {
                MessagingErrorView(
                    error: error,
                    context: .messageGeneration,
                    onRetry: {
                        Task {
                            await retryMessageGeneration()
                        }
                    },
                    onDismiss: {
                        messagingService.clearGeneration()
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Group {
            if messagingService.generatedMessages.isEmpty && !messagingService.isGenerating {
                EmptyStateView(
                    title: "Ready to Generate Messages",
                    subtitle: "Select a category and add some context to create personalized messages for your partner.",
                    systemImage: "wand.and.rays",
                    actionTitle: messagingService.selectedCategory != nil ? "Generate Messages" : nil
                ) {
                    if messagingService.canGenerate,
                       let user = authViewModel.user {
                        Task {
                            await messagingService.generateMessages(for: user)
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Recent Messages Section
    
    private var recentMessagesSection: some View {
        Group {
            let todaysMessages = messagingService.todaysRecentMessages
            if !todaysMessages.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today's Messages")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(todaysMessages.count) generated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button("View All") {
                            showingHistory = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(todaysMessages.prefix(3))) { recentMessage in
                            RecentMessageCard(message: recentMessage) {
                                // Create a ComprehensiveGeneratedMessage for detail view
                                if let categoryType = MessageCategoryType(rawValue: recentMessage.category) {
                                    let comprehensiveMessage = ComprehensiveGeneratedMessage(
                                        id: recentMessage.id,
                                        content: recentMessage.content,
                                        category: categoryType,
                                        personalityMatch: recentMessage.metadata.personalityMatch,
                                        tone: MessageTone(rawValue: recentMessage.metadata.tone) ?? .warm,
                                        estimatedImpact: MessageImpact(rawValue: recentMessage.metadata.estimatedImpact) ?? .medium,
                                        context: ComprehensiveGeneratedMessage.MessageContext(
                                            timeOfDay: .current,
                                            relationshipDuration: nil,
                                            recentContext: nil,
                                            specialOccasion: nil,
                                            userPersonalityType: recentMessage.metadata.personalityMatch,
                                            partnerName: nil
                                        ),
                                        generatedAt: recentMessage.generatedAt
                                    )
                                    selectedMessage = comprehensiveMessage
                                }
                            }
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Error Handling Views
    
    private var categoriesWithErrorHandling: some View {
        let _ = print("👀 CategoriesWithErrorHandling - Current state: \(messagingService.categoriesState)")
        
        return Group {
            if case .loaded(let categories) = messagingService.categoriesState {
                let _ = print("📜 Rendering categories section with \(categories.count) categories")
                categoriesSection(categories: categories)
            } else if case .loading = messagingService.categoriesState {
                VStack(spacing: 16) {
                    ProgressView("Loading categories...")
                        .padding()
                }
            } else if case .failed(let error) = messagingService.categoriesState {
                VStack(spacing: 12) {
                    Text("Failed to load categories")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await handleCategoryRetry()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            } else {
                // .idle state
                VStack(spacing: 12) {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Load Categories") {
                        Task {
                            await loadCategoriesWithErrorHandling()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadInitialData() async {
        // Always load categories first
        await loadCategoriesWithErrorHandling()
        
        // Only load user-specific content if user is available
        if let user = authViewModel.user {
            await messagingService.loadPersonalizedRecommendations(for: user)
            await messagingService.loadHistory(limit: 10, offset: 0)
        } else {
            print("⚠️ User not available yet, will load recommendations and history when user loads")
        }
    }
    
    private func loadCategoriesWithErrorHandling() async {
        // Use messagingService directly which has fallback support
        await messagingService.loadCategories(forceRefresh: false)
    }
    
    private func handleRetryFromBanner() async {
        errorBanner = nil
        await loadCategoriesWithErrorHandling()
    }
    
    private func handleCategoryRetry() async {
        await loadCategoriesWithErrorHandling()
    }
    
    private func retryMessageGeneration() async {
        guard let user = authViewModel.user else { return }
        
        // First try to generate with retry service
        guard let selectedCategory = messagingService.selectedCategory,
              let categoryDetails = messagingService.currentCategories.first(where: { $0.type == selectedCategory }) else {
            return
        }
        
        let request = MessageGenerateRequest(
            category: categoryDetails.type.rawValue,
            timeOfDay: messagingService.selectedTimeOfDay,
            recentContext: messagingService.recentContext.isEmpty ? nil : messagingService.recentContext,
            specialOccasion: messagingService.specialOccasion.isEmpty ? nil : messagingService.specialOccasion,
            userId: user.id,
            personalityType: user.personalityType,
            partnerName: user.partnerName
        )
        
        let result = await retryableService.generateMessage(
            request: request,
            retryPolicy: .aggressive
        )
        
        switch result {
        case .success(let response):
            // Update the messaging service with successful response - using existing patterns
            await MainActor.run {
                // Simulate updating the service's state with the response
                // In a real implementation, you'd update the service state appropriately
                self.errorBanner = nil
            }
        case .failure(let error):
            // Show error in the UI
            await MainActor.run {
                self.errorBanner = error
            }
        }
    }
    
    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            keyboardHeight = keyboardFrame.height - 100 // Account for safe area
        }
    }
}

// MARK: - Supporting Views

struct MessageCategoryButton: View {
    let category: DetailedMessageCategory
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImageName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : category.displayColor)
                
                Text(category.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(category.displayColor.gradient)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .stroke(category.displayColor.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .disabled(isLoading)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct SelectedCategoryCard: View {
    let category: DetailedMessageCategory
    let isGenerating: Bool
    let canGenerate: Bool
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(category.displayColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.systemImageName)
                        .font(.title2)
                        .foregroundStyle(category.displayColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.label)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            Button(action: onGenerate) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wand.and.rays")
                            .font(.headline)
                    }
                    
                    Text(isGenerating ? "Generating..." : "Generate Messages")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(category.displayColor.opacity(0.3), lineWidth: 1)
        }
    }
}

struct MessageStatsView: View {
    let statistics: MessageStatistics
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "Generated",
                value: "\(statistics.totalMessages)",
                icon: "sparkles"
            )
            
            StatItem(
                title: "Avg Impact", 
                value: String(format: "%.1f", statistics.averageImpact),
                icon: "heart.fill"
            )
            
            if let mostUsed = statistics.mostUsedCategory {
                StatItem(
                    title: "Favorite",
                    value: mostUsed.displayName,
                    icon: "star.fill"
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.5))
        }
    }
}


// MARK: - Preview

#Preview {
    MessagesView()
        .environmentObject(AuthService())
}