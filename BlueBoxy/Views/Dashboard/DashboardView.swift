import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with user greeting
                    if let user = authViewModel.user {
                        HeaderSection(user: user)
                    }
                    
                    // Stats overview
                    StatsSection(statsState: dashboardViewModel.stats)
                    
                    // Quick actions
                    QuickActionsSection()
                    
                    // Recent activities  
                    RecentActivitiesSection(activitiesState: dashboardViewModel.activities.map { $0.activities })
                    
                    // Upcoming events
                    UpcomingEventsSection(eventsState: dashboardViewModel.recentEvents.map { events in
                        events.map { event in
                            CalendarEventDB(
                                id: event.id,
                                userId: 1, // Default user ID
                                title: event.title,
                                description: event.description ?? "",
                                location: event.location ?? "",
                                startTime: ISO8601DateFormatter().string(from: event.startTime),
                                endTime: ISO8601DateFormatter().string(from: event.endTime),
                                allDay: event.allDay,
                                eventType: "event",
                                status: "scheduled",
                                externalEventId: nil,
                                calendarProvider: nil,
                                reminders: nil,
                                metadata: nil,
                                createdAt: ISO8601DateFormatter().string(from: Date()),
                                updatedAt: ISO8601DateFormatter().string(from: Date())
                            )
                        }
                    })
                    
                    // AI insights
                    if let user = authViewModel.user, let insight = user.personalityInsight {
                        AIInsightsSection(insight: insight)
                    }
                }
                .padding()
            }
            .refreshable {
                await dashboardViewModel.loadDashboard()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        AsyncImage(url: URL(string: "https://via.placeholder.com/40")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.gray.opacity(0.3))
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.gray)
                                }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
        }
        .task {
            await dashboardViewModel.loadDashboard()
        }
    }
}

struct HeaderSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeOfDayGreeting), \(user.name ?? "there")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Ready to make today special?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
    
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "evening"
        }
    }
}

struct StatsSection: View {
    let statsState: Loadable<UserStatsResponse>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress")
                .font(.headline)
                .padding(.horizontal)
            
            switch statsState {
            case .idle, .loading:
                StatsLoadingView()
            case .loaded(let stats):
                StatsContentView(stats: stats)
            case .failed(let error):
                ErrorBanner(error: error, onRetry: nil)
                    .padding(.horizontal)
            }
        }
    }
}

struct StatsLoadingView: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.3))
                        .frame(width: 60, height: 40)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.3))
                        .frame(width: 80, height: 12)
                }
                .redacted(reason: .placeholder)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct StatsContentView: View {
    let stats: UserStatsResponse
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(title: "Events Created", value: "\(stats.eventsCreated)", icon: "calendar.badge.plus")
            
            Divider()
                .frame(height: 40)
            
            StatItem(title: "This Week", value: "3", icon: "flame.fill") // Placeholder
            
            Divider()
                .frame(height: 40)
            
            StatItem(title: "Streak", value: "7", icon: "bolt.fill") // Placeholder
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Generate Message",
                    subtitle: "AI-powered messages",
                    icon: "message.fill",
                    color: .blue
                ) {
                    // Navigate to messages
                }
                
                QuickActionCard(
                    title: "Find Activities",
                    subtitle: "Personalized recommendations",
                    icon: "mappin.and.ellipse",
                    color: .green
                ) {
                    // Navigate to recommendations
                }
                
                QuickActionCard(
                    title: "Add Event",
                    subtitle: "Plan your next date",
                    icon: "calendar.badge.plus",
                    color: .orange
                ) {
                    // Navigate to calendar
                }
                
                QuickActionCard(
                    title: "Take Assessment",
                    subtitle: "Update your profile",
                    icon: "person.crop.circle.fill.badge.questionmark",
                    color: .purple
                ) {
                    // Navigate to assessment
                }
            }
            .padding(.horizontal)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentActivitiesSection: View {
    let activitiesState: Loadable<[Activity]>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested Activities")
                    .font(.headline)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to activities
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            
            switch activitiesState {
            case .idle, .loading:
                ActivityLoadingView()
            case .loaded(let activities):
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(activities.prefix(5), id: \.id) { activity in
                            ActivityCard(activity: activity)
                        }
                    }
                    .padding(.horizontal)
                }
            case .failed(let error):
                ErrorBanner(error: error, onRetry: nil)
                    .padding(.horizontal)
            }
        }
    }
}

struct ActivityCard: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: activity.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
            .frame(width: 140, height: 80)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let rating = activity.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { star in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(star < Int(rating) ? .yellow : .gray.opacity(0.3))
                        }
                    }
                }
            }
        }
        .frame(width: 140)
        .padding(.vertical, 8)
    }
}

struct ActivityLoadingView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 140, height: 80)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.gray.opacity(0.3))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.gray.opacity(0.3))
                                .frame(width: 80, height: 8)
                        }
                    }
                    .frame(width: 140)
                    .redacted(reason: .placeholder)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct UpcomingEventsSection: View {
    let eventsState: Loadable<[CalendarEventDB]>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.headline)
                
                Spacer()
                
                Button("Calendar") {
                    // Navigate to calendar
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            
            switch eventsState {
            case .idle, .loading:
                EventsLoadingView()
            case .loaded(let events):
                if events.isEmpty {
                    EmptyEventsView()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(events.prefix(3), id: \.id) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
            case .failed(let error):
                ErrorBanner(error: error, onRetry: nil)
                    .padding(.horizontal)
            }
        }
    }
}

struct EventRow: View {
    let event: CalendarEventDB
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dayFormatter.string(from: parseDate(event.startTime)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(dateFormatter.string(from: parseDate(event.startTime)))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Text(timeFormatter.string(from: parseDate(event.startTime)))
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
    
    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }
}

struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.title)
                .foregroundStyle(.gray)
            
            Text("No upcoming events")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Add Your First Event") {
                // Navigate to create event
            }
            .font(.caption)
            .buttonStyle(BorderedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct EventsLoadingView: View {
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.3))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 100, height: 8)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal)
    }
}


#Preview {
    DashboardView()
        .environmentObject(DashboardViewModel())
        .environmentObject(AuthViewModel())
}