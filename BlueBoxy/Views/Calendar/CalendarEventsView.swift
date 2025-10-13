//
//  CalendarEventsView.swift
//  BlueBoxy
//
//  Calendar events display with date range support, event details, and sync status
//

import SwiftUI

struct CalendarEventsView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDateRange: DateRange = .thisWeek
    @State private var showingEventDetail = false
    @State private var selectedEvent: Event?
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.systemBackground
                    .ignoresSafeArea()
                
                content
            }
            .navigationTitle("Calendar Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Button(range.displayName) {
                                changeDateRange(to: range)
                            }
                        }
                        
                        Divider()
                        
                        Button("Filters") {
                            showingFilters = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
            .refreshable {
                await viewModel.loadEvents(forceRefresh: true)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    EventDetailView(event: event)
                }
            }
            .sheet(isPresented: $showingFilters) {
                EventFiltersView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.selectedDateRange = selectedDateRange
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.events {
        case .idle:
            ProgressView("Loading events...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loading:
            LoadingView()
            
        case .loaded(let events):
            eventsListView(events)
            
        case .failed(let error):
            EventErrorView(
                error: error,
                onRetry: {
                    Task {
                        await viewModel.loadEvents(forceRefresh: true)
                    }
                }
            )
        }
    }
    
    private func eventsListView(_ events: [Event]) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Header with sync status and date range
                headerSection
                
                // Events grouped by date
                if events.isEmpty {
                    emptyEventsView
                } else {
                    eventsSection(events)
                }
            }
            .defaultPadding()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Date range selector and sync status
            HStack {
                DateRangeSelector(
                    selectedRange: $selectedDateRange,
                    onRangeChanged: changeDateRange
                )
                
                Spacer()
                
                SyncStatusIndicator(viewModel: viewModel)
            }
            
            // Event statistics
            EventStatistics(viewModel: viewModel)
        }
        .defaultPadding()
        .background(DesignSystem.Colors.systemBackground)
        .cardRadius()
        .shadow(color: DesignSystem.Shadow.sm, radius: 4, x: 0, y: 2)
    }
    
    private var emptyEventsView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.muted)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Events Found")
                    .h2Style()
                
                Text("No events found for \(selectedDateRange.displayName.lowercased()). Try selecting a different date range or create a new event.")
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
            
            DSButton("Create Event", style: .primary) {
                // Navigate to event creation
            }
        }
        .defaultPadding()
        .frame(maxWidth: .infinity)
    }
    
    private func eventsSection(_ events: [Event]) -> some View {
        ForEach(groupEventsByDate(events).sorted(by: { $0.key < $1.key }), id: \.key) { date, dayEvents in
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Date header
                DateSectionHeader(date: date, eventCount: dayEvents.count)
                
                // Events for this date
                ForEach(dayEvents.sorted(by: { $0.startTime < $1.startTime })) { event in
                    EventRow(
                        event: event,
                        onTap: {
                            selectedEvent = event
                            showingEventDetail = true
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadInitialData() async {
        await viewModel.loadProviders()
        await viewModel.loadEvents()
    }
    
    private func changeDateRange(to range: DateRange) {
        selectedDateRange = range
        viewModel.changeDateRange(to: range)
    }
    
    private func groupEventsByDate(_ events: [Event]) -> [Date: [Event]] {
        let calendar = Calendar.current
        return Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startTime)
        }
    }
}

// MARK: - Supporting Views


struct DateRangeSelector: View {
    @Binding var selectedRange: DateRange
    let onRangeChanged: (DateRange) -> Void
    
    var body: some View {
        HStack {
            Button(action: { moveToPrevious() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            VStack(spacing: 2) {
                Text(selectedRange.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(formatDateRangeDescription())
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.muted)
            }
            .frame(minWidth: 120)
            
            Button(action: { moveToNext() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
    }
    
    private func moveToPrevious() {
        let newRange = selectedRange.previous()
        selectedRange = newRange
        onRangeChanged(newRange)
    }
    
    private func moveToNext() {
        let newRange = selectedRange.next()
        selectedRange = newRange
        onRangeChanged(newRange)
    }
    
    private func formatDateRangeDescription() -> String {
        let (start, end) = selectedRange.dateInterval
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if Calendar.current.isDate(start, inSameDayAs: end.addingTimeInterval(-1)) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end.addingTimeInterval(-1)))"
        }
    }
}

struct SyncStatusIndicator: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            syncStatusIcon
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(syncStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(syncStatusColor)
                
                Text("Last sync: \(lastSyncText)")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.muted)
            }
        }
    }
    
    private var syncStatusIcon: some View {
        Group {
            if viewModel.events.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var syncStatusText: String {
        if viewModel.events.isLoading {
            return "Syncing"
        } else if viewModel.events.isLoaded {
            return "Synced"
        } else if viewModel.events.isFailed {
            return "Error"
        } else {
            return "Idle"
        }
    }
    
    private var syncStatusColor: Color {
        if viewModel.events.isLoading {
            return DesignSystem.Colors.muted
        } else if viewModel.events.isLoaded {
            return DesignSystem.Colors.success
        } else if viewModel.events.isFailed {
            return DesignSystem.Colors.error
        } else {
            return DesignSystem.Colors.muted
        }
    }
    
    private var lastSyncText: String {
        // This would be more sophisticated in a real app
        "Just now"
    }
}

struct EventStatistics: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        HStack {
            StatisticItem(
                title: "Total Events",
                value: "\(viewModel.events.value?.count ?? 0)",
                icon: "calendar"
            )
            
            Spacer()
            
            StatisticItem(
                title: "Today",
                value: "\(viewModel.todaysEvents.count)",
                icon: "calendar.badge.clock"
            )
            
            Spacer()
            
            StatisticItem(
                title: "Upcoming",
                value: "\(viewModel.upcomingEvents.count)",
                icon: "calendar.badge.plus"
            )
        }
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.primary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.muted)
            }
        }
    }
}

struct DateSectionHeader: View {
    let date: Date
    let eventCount: Int
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today' - EEEE, MMM d"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow' - EEEE, MMM d"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
        }
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("\(eventCount) event\(eventCount == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.muted)
            }
            
            Spacer()
            
            // Day indicator dot
            Circle()
                .fill(Calendar.current.isDateInToday(date) ? DesignSystem.Colors.primary : DesignSystem.Colors.muted)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}


struct EventTypeIndicator: View {
    let eventType: String
    
    var body: some View {
        Text(eventType.capitalized)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(eventTypeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(eventTypeColor.opacity(0.2))
            .clipShape(Capsule())
    }
    
    private var eventTypeColor: Color {
        switch eventType.lowercased() {
        case "date":
            return Color.pink
        case "anniversary":
            return Color.red
        case "reminder":
            return Color.orange
        case "activity":
            return Color.blue
        case "special":
            return Color.purple
        default:
            return DesignSystem.Colors.muted
        }
    }
}

struct EventErrorView: View {
    let error: NetworkError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.error)
                
                Text("Unable to Load Events")
                    .h2Style()
                    .multilineTextAlignment(.center)
                
                Text(error.localizedDescription)
                    .bodyStyle()
                    .mutedStyle()
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                DSButton("Try Again", style: .primary, action: onRetry)
                
                DSButton("Check Connection", style: .secondary) {
                    // Navigate to calendar providers
                }
            }
        }
        .defaultPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: Event
    @Environment(\.presentationMode) var presentationMode
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(event.title)
                            .h1Style()
                        
                        if let description = event.description {
                            Text(description)
                                .bodyStyle()
                                .mutedStyle()
                        }
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        DetailRow(
                            icon: "calendar",
                            title: "Date & Time",
                            value: event.allDay ? 
                                "All day on \(DateFormatter.shortDate.string(from: event.startTime))" :
                                "\(dateFormatter.string(from: event.startTime)) - \(DateFormatter.shortTime.string(from: event.endTime))"
                        )
                        
                        if let location = event.location, !location.isEmpty {
                            DetailRow(
                                icon: "location",
                                title: "Location",
                                value: location
                            )
                        }
                        
                        DetailRow(
                            icon: "tag",
                            title: "Type",
                            value: event.eventType.capitalized
                        )
                        
                        if let provider = event.calendarProvider {
                            DetailRow(
                                icon: "calendar.badge.plus",
                                title: "Provider",
                                value: provider
                            )
                        }
                    }
                }
                .defaultPadding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Using DetailRow from UIComponents.swift

// MARK: - Event Filters View

struct EventFiltersView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Event Types Filter
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Event Types")
                        .h3Style()
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2)) {
                        ForEach(["date", "anniversary", "reminder", "activity", "special"], id: \.self) { type in
                            FilterToggle(
                                title: type.capitalized,
                                isSelected: viewModel.selectedEventTypes.contains(type)
                            ) {
                                if viewModel.selectedEventTypes.contains(type) {
                                    viewModel.selectedEventTypes.remove(type)
                                } else {
                                    viewModel.selectedEventTypes.insert(type)
                                }
                            }
                        }
                    }
                }
                
                // Past Events Toggle
                Toggle("Show Past Events", isOn: $viewModel.showPastEvents)
                    .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.primary))
                
                Spacer()
            }
            .defaultPadding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        Task {
                            await viewModel.loadEvents(forceRefresh: true)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        viewModel.selectedEventTypes.removeAll()
                        viewModel.showPastEvents = false
                    }
                }
            }
        }
    }
}

struct FilterToggle: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.primary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    CalendarEventsView()
}