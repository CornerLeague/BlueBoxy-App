//
//  CalendarProviderListView.swift
//  BlueBoxy
//
//  Calendar provider management screen with connection status and OAuth integration
//

import SwiftUI
import AuthenticationServices

struct CalendarProviderListView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var oauthService = OAuthService()
    @State private var showingOAuthProgress = false
    @State private var selectedProvider: CalendarProvider?
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.systemBackground
                    .ignoresSafeArea()
                
                content
            }
            .navigationTitle("Calendar Providers")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadProviders()
            }
            .sheet(isPresented: $showingOAuthProgress) {
                if let provider = selectedProvider {
                    OAuthProgressView(
                        oauthService: oauthService,
                        provider: provider,
                        onComplete: { success in
                            handleOAuthCompletion(success: success)
                        },
                        onCancel: {
                            handleOAuthCancellation()
                        }
                    )
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadProviders()
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.providers {
        case .idle:
            ProgressView("Loading providers...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loading:
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView("Loading providers...")
                    .scaleEffect(1.2)
                
                Text("Connecting to calendar services...")
                    .captionStyle()
                    .mutedStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loaded(let providers):
            providersList(providers)
            
        case .failed(let error):
            ErrorView(
                error: error,
                title: "Failed to Load Providers",
                onRetry: {
                    Task {
                        await viewModel.loadProviders()
                    }
                }
            )
        }
    }
    
    private func providersList(_ providers: [CalendarProvider]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Header section
                headerSection
                
                // Connected providers section
                if !viewModel.connectedProviders.isEmpty {
                    connectedProvidersSection
                }
                
                // Available providers section
                if !viewModel.availableProviders.isEmpty {
                    availableProvidersSection
                }
                
                // Info section
                infoSection
            }
            .defaultPadding()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Calendar Integration")
                        .h3Style()
                    
                    Text("Connect your calendar providers to sync events")
                        .captionStyle()
                        .mutedStyle()
                }
                
                Spacer()
            }
            
            // Connection status summary
            connectionStatusSummary
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 4, x: 0, y: 2)
    }
    
    private var connectionStatusSummary: some View {
        HStack {
            Label("\(viewModel.connectedProviders.count) Connected", 
                  systemImage: "checkmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.success)
                .captionStyle()
            
            Spacer()
            
            Label("\(viewModel.availableProviders.count) Available", 
                  systemImage: "circle")
                .foregroundColor(DesignSystem.Colors.muted)
                .captionStyle()
        }
    }
    
    private var connectedProvidersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: "Connected Providers", 
                         icon: "checkmark.circle.fill",
                         iconColor: DesignSystem.Colors.success)
            
            ForEach(viewModel.connectedProviders, id: \.id) { provider in
                ConnectedProviderRow(
                    provider: provider,
                    onDisconnect: {
                        Task {
                            await disconnectProvider(provider)
                        }
                    },
                    onSync: {
                        Task {
                            await syncProvider(provider)
                        }
                    }
                )
            }
        }
    }
    
    private var availableProvidersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: "Available Providers", 
                         icon: "plus.circle",
                         iconColor: DesignSystem.Colors.primary)
            
            ForEach(viewModel.availableProviders, id: \.id) { provider in
                AvailableProviderRow(
                    provider: provider,
                    isConnecting: oauthService.isAuthenticating(provider: provider),
                    onConnect: {
                        connectProvider(provider)
                    }
                )
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            SectionHeader(title: "About Calendar Integration", 
                         icon: "info.circle",
                         iconColor: DesignSystem.Colors.muted)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                InfoRow(icon: "lock.shield",
                        title: "Your calendar data is secure and encrypted", 
                        description: "Data is encrypted and secure")
                
                InfoRow(icon: "arrow.clockwise",
                        title: "Events sync automatically in the background", 
                        description: "Background sync keeps data up to date")
                
                InfoRow(icon: "person.crop.circle.badge.minus",
                        title: "You can disconnect providers at any time", 
                        description: "Full control over your connections")
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    
    private func connectProvider(_ provider: CalendarProvider) {
        selectedProvider = provider
        showingOAuthProgress = true
        
        Task {
            _ = await oauthService.authenticate(provider: provider)
        }
    }
    
    private func disconnectProvider(_ provider: CalendarProvider) async {
        await viewModel.disconnectFromCalendar()
    }
    
    private func syncProvider(_ provider: CalendarProvider) async {
        // Trigger a manual sync - this would call a sync endpoint
        await viewModel.loadProviders()
    }
    
    // MARK: - OAuth Completion Handlers
    
    private func handleOAuthCompletion(success: Bool) {
        showingOAuthProgress = false
        selectedProvider = nil
        
        if success {
            Task {
                await viewModel.loadProviders()
            }
        }
    }
    
    private func handleOAuthCancellation() {
        showingOAuthProgress = false
        selectedProvider = nil
        oauthService.resetState()
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .semibold))
            
            Text(title)
                .h3Style()
                .foregroundColor(DesignSystem.Colors.primary)
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

struct ConnectedProviderRow: View {
    let provider: CalendarProvider
    let onDisconnect: () -> Void
    let onSync: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Provider icon
            providerIcon
            
            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .bodyStyle()
                    .foregroundColor(DesignSystem.Colors.primary)
                
                HStack {
                    connectionStatusIndicator
                    
                    if let lastSync = provider.lastSync {
                        Text("Last sync: \(formatLastSync(lastSync))")
                            .captionStyle()
                            .mutedStyle()
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: onSync) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDisconnect) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(DesignSystem.Colors.error)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    private var providerIcon: some View {
        Image(systemName: provider.icon)
            .foregroundColor(DesignSystem.Colors.success)
            .font(.system(size: 20))
            .frame(width: 32, height: 32)
            .background(DesignSystem.Colors.success.opacity(0.1))
            .clipShape(Circle())
    }
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(DesignSystem.Colors.success)
                .frame(width: 6, height: 6)
            
            Text("Connected")
                .captionStyle()
                .foregroundColor(DesignSystem.Colors.success)
        }
    }
    
    private func formatLastSync(_ lastSync: String) -> String {
        // This would parse the ISO string and format it nicely
        // For now, return a simplified version
        return "Just now"
    }
}

struct AvailableProviderRow: View {
    let provider: CalendarProvider
    let isConnecting: Bool
    let onConnect: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Provider icon
            providerIcon
            
            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .bodyStyle()
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(provider.description)
                    .captionStyle()
                    .mutedStyle()
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Connect button
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: onConnect) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Connect")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 2, x: 0, y: 1)
    }
    
    private var providerIcon: some View {
        Image(systemName: provider.icon)
            .foregroundColor(DesignSystem.Colors.muted)
            .font(.system(size: 20))
            .frame(width: 32, height: 32)
            .background(DesignSystem.Colors.muted.opacity(0.1))
            .clipShape(Circle())
    }
}




// MARK: - Preview

#Preview {
    CalendarProviderListView()
}