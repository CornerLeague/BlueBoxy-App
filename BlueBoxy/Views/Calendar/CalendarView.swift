//
//  CalendarView.swift
//  BlueBoxy
//
//  Monthly calendar view with event integration and date selection functionality.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var viewModel: CalendarViewModel
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingDatePicker = false
    @State private var showingEventDetail = false
    @State private var selectedEvent: Event?
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header with navigation
            calendarHeader
            
            // Calendar grid
            calendarGrid
            
            Divider()
                .padding(.vertical, 16)
            
            // Selected date events
            selectedDateEvents
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $currentMonth)
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadEvents()
            }
        }
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        HStack {
            // Previous month button
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Month/Year display
            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 2) {
                    Text(monthYearString)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let eventCount = monthlyEventCount {
                        Text("\(eventCount) events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Next month button
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            weekdayHeaders
            
            // Calendar dates
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDates, id: \.self) { date in
                    CalendarDateView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isInCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        events: eventsForDate(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var weekdayHeaders: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Selected Date Events
    
    private var selectedDateEvents: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected date header
            HStack {
                Text(selectedDateString)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let dayEvents = eventsForDate(selectedDate), !dayEvents.isEmpty {
                    Text("\(dayEvents.count) event\(dayEvents.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Events list for selected date
            if let dayEvents = eventsForDate(selectedDate), !dayEvents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dayEvents.sorted(by: { $0.startTime < $1.startTime })) { event in
                            CalendarEventCard(event: event) {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // No events for selected date
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No events for this date")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Helper Properties
    
    private var monthYearString: String {
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: currentMonth)
    }
    
    private var selectedDateString: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            dateFormatter.dateFormat = "EEEE, MMMM d"
            return dateFormatter.string(from: selectedDate)
        }
    }
    
    private var monthlyEventCount: Int? {
        guard let events = viewModel.events.value else { return nil }
        return events.filter { event in
            calendar.isDate(event.startTime, equalTo: currentMonth, toGranularity: .month)
        }.count
    }
    
    private var calendarDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let monthFirstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysToSubtract = monthFirstWeekday - calendar.firstWeekday
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: monthInterval.start) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = startDate
        
        // Generate 42 dates (6 weeks × 7 days) to ensure full calendar grid
        for _ in 0..<42 {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return dates
    }
    
    // MARK: - Helper Methods
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
        Task {
            await loadEventsForCurrentMonth()
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
        Task {
            await loadEventsForCurrentMonth()
        }
    }
    
    private func eventsForDate(_ date: Date) -> [Event]? {
        guard let events = viewModel.events.value else { return nil }
        return events.filter { event in
            calendar.isDate(event.startTime, inSameDayAs: date)
        }
    }
    
    private func loadEventsForCurrentMonth() async {
        // Update the view model's date range to current month and reload events
        let monthRange = DateRange.thisMonth
        viewModel.changeDateRange(to: monthRange)
    }
}

// MARK: - Calendar Date View

struct CalendarDateView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isInCurrentMonth: Bool
    let events: [Event]?
    let onTap: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Date number
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)
                
                // Event indicators
                if let events = events, !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(events.count, 3), id: \.self) { index in
                            Circle()
                                .fill(eventColor(for: events[index]))
                                .frame(width: 4, height: 4)
                        }
                        
                        if events.count > 3 {
                            Text("+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Spacer to maintain consistent height
                    Spacer()
                        .frame(height: 8)
                }
            }
            .frame(width: 44, height: 44)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var textColor: Color {
        if !isInCurrentMonth {
            return .secondary
        } else if isToday {
            return .white
        } else if isSelected {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return .blue
        } else if isSelected {
            return Color.blue.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        return .blue
    }
    
    private func eventColor(for event: Event) -> Color {
        switch event.eventType.lowercased() {
        case "date":
            return .pink
        case "anniversary":
            return .red
        case "reminder":
            return .orange
        case "activity":
            return .blue
        case "special":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Calendar Event Card

struct CalendarEventCard: View {
    let event: Event
    let onTap: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Time indicator
                VStack(spacing: 2) {
                    Text(timeFormatter.string(from: event.startTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    EventTypeIndicator(eventType: event.eventType)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Month",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(CalendarViewModel())
    }
}
#endif