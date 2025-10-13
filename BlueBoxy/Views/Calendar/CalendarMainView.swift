//
//  CalendarMainView.swift
//  BlueBoxy
//
//  Main calendar view integrating provider management and events display
//

import SwiftUI

struct CalendarMainView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedTab: CalendarTab = .events
    
    enum CalendarTab: String, CaseIterable {
        case events = "Events"
        case providers = "Providers"
        
        var icon: String {
            switch self {
            case .events:
                return "calendar"
            case .providers:
                return "calendar.badge.plus"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.systemBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom tab bar
                    calendarTabBar
                    
                    // Content based on selected tab
                    TabView(selection: $selectedTab) {
                        CalendarEventsView()
                            .tag(CalendarTab.events)
                        
                        CalendarProviderListView()
                            .tag(CalendarTab.providers)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .environmentObject(viewModel)
        }
    }
    
    private var calendarTabBar: some View {
        HStack {
            ForEach(CalendarTab.allCases, id: \.self) { tab in
                CalendarTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    viewModel: viewModel
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.systemBackground)
        .shadow(color: DesignSystem.Shadow.sm, radius: 1, x: 0, y: 1)
    }
}

struct CalendarTabButton: View {
    let tab: CalendarMainView.CalendarTab
    let isSelected: Bool
    @ObservedObject var viewModel: CalendarViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(tab.rawValue)
                    .font(.system(size: 16, weight: .medium))
                
                // Show connection status badge for providers tab
                if tab == .providers {
                    connectionStatusBadge
                }
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.primary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? DesignSystem.Colors.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DesignSystem.Colors.primary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var connectionStatusBadge: some View {
        if viewModel.connectedProviders.count > 0 {
            Text("\(viewModel.connectedProviders.count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(DesignSystem.Colors.success)
                .clipShape(Circle())
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarMainView()
}