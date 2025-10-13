import SwiftUI
import CoreLocation
import MapKit

struct PreferencesEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager.shared
    
    // Preferences state
    @State private var selectedBudget = BudgetRange.medium
    @State private var selectedCategories: Set<ActivityCategory> = []
    @State private var searchRadius: Double = 25.0 // kilometers
    @State private var selectedTimePreference = TimePreference.flexible
    @State private var selectedGroupSize = GroupSize.couple
    @State private var allowAdultContent = false
    @State private var notificationsEnabled = true
    @State private var location: CLLocationCoordinate2D?
    @State private var customLocation: String = ""
    
    // UI state
    @State private var isLoading = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingLocationPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                budgetSection
                categorySection
                locationSection
                timingSection
                groupSizeSection
                contentSection
                notificationSection
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePreferences()
                        }
                    }
                    .buttonStyle(CompactButtonStyle(isLoading: isLoading))
                    .disabled(isLoading)
                }
            }
            .alert("Discard Changes", isPresented: $showingDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $location,
                    customLocationName: $customLocation
                )
            }
        }
        .onAppear {
            loadCurrentPreferences()
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }
    
    // MARK: - Form Sections
    
    private var budgetSection: some View {
        Section("Budget Range") {
            Picker("Budget", selection: $selectedBudget) {
                ForEach(BudgetRange.allCases, id: \.self) { budget in
                    HStack {
                        Text(budget.displayName)
                        Spacer()
                        Text(budget.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(budget)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .onChange(of: selectedBudget) { _, _ in hasUnsavedChanges = true }
        }
    }
    
    private var categorySection: some View {
        Section("Activity Categories") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    Button {
                        toggleCategory(category)
                    } label: {
                        CategorySelectionCard(
                            category: category,
                            isSelected: selectedCategories.contains(category)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Text("Select your preferred activity types")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var locationSection: some View {
        Section("Location & Search Radius") {
            // Current location display
            if let location = location {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customLocation.isEmpty ? "Current Location" : customLocation)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(location.latitude, specifier: "%.3f"), \(location.longitude, specifier: "%.3f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Location actions
            HStack(spacing: 12) {
                Button("Use Current Location") {
                    requestCurrentLocation()
                }
                .buttonStyle(CompactButtonStyle(variant: .secondary))
                .disabled(locationManager.authorizationStatus != .authorizedWhenInUse &&
                         locationManager.authorizationStatus != .authorizedAlways)
                
                Button("Choose on Map") {
                    showingLocationPicker = true
                }
                .buttonStyle(CompactButtonStyle(variant: .primary))
            }
            
            // Search radius slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Search Radius")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(searchRadius)) km")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                
                Slider(value: $searchRadius, in: 5...100, step: 5)
                    .onChange(of: searchRadius) { _, _ in hasUnsavedChanges = true }
                
                HStack {
                    Text("5 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("100 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var timingSection: some View {
        Section("Time Preferences") {
            Picker("Preferred Time", selection: $selectedTimePreference) {
                ForEach(TimePreference.allCases, id: \.self) { time in
                    HStack {
                        Image(systemName: time.icon)
                            .foregroundStyle(time.color)
                        Text(time.displayName)
                    }
                    .tag(time)
                }
            }
            .onChange(of: selectedTimePreference) { _, _ in hasUnsavedChanges = true }
        }
    }
    
    private var groupSizeSection: some View {
        Section("Group Size") {
            Picker("Group Size", selection: $selectedGroupSize) {
                ForEach(GroupSize.allCases, id: \.self) { size in
                    HStack {
                        Image(systemName: size.icon)
                            .foregroundStyle(.blue)
                        Text(size.displayName)
                        Spacer()
                        Text(size.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(size)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .onChange(of: selectedGroupSize) { _, _ in hasUnsavedChanges = true }
        }
    }
    
    private var contentSection: some View {
        Section("Content Preferences") {
            Toggle("Allow Adult Content", isOn: $allowAdultContent)
                .onChange(of: allowAdultContent) { _, _ in hasUnsavedChanges = true }
            
            Text("Include bars, clubs, and other adult-oriented venues")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Activity Recommendations", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, _ in hasUnsavedChanges = true }
            
            Text("Get notified about new activity suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentPreferences() {
        // Load from user preferences if available
        // This would typically come from your API or local storage
        // For now, we'll use default values
    }
    
    private func toggleCategory(_ category: ActivityCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        hasUnsavedChanges = true
    }
    
    private func requestCurrentLocation() {
        locationManager.requestPermission()
        if let currentLocation = locationManager.location {
            location = currentLocation.coordinate
            customLocation = "" // Clear custom location name when using current
            hasUnsavedChanges = true
        }
    }
    
    private func handleCancel() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    @MainActor
    private func savePreferences() async {
        isLoading = true
        
        do {
            let preferencesRequest = UserPreferencesRequest(
                budgetRange: selectedBudget,
                activityCategories: Array(selectedCategories),
                location: location.map { GeoLocationPayload(latitude: $0.latitude, longitude: $0.longitude) },
                searchRadius: searchRadius,
                timePreference: selectedTimePreference,
                groupSize: selectedGroupSize,
                allowAdultContent: allowAdultContent,
                notificationsEnabled: notificationsEnabled
            )
            
            // Save preferences via API
            // try await authViewModel.updatePreferences(preferencesRequest)
            
            hasUnsavedChanges = false
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

struct CategorySelectionCard: View {
    let category: ActivityCategory
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(isSelected ? .white : category.color)
            
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? category.color : Color.gray.opacity(0.1))
                .stroke(isSelected ? category.color : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var customLocationName: String
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                TextField("Search for a location", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                // Map
                Map(coordinateRegion: $region, annotationItems: selectedLocation.map { [MapPin(coordinate: $0)] } ?? []) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .blue)
                }
                .onTapGesture { location in
                    // Convert tap location to coordinate
                    // This is simplified - you'd need proper coordinate conversion
                    selectedLocation = region.center
                }
                
                Spacer()
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Enums and Models

enum BudgetRange: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case luxury = "luxury"
    
    var displayName: String {
        switch self {
        case .low: return "Budget"
        case .medium: return "Moderate"
        case .high: return "High"
        case .luxury: return "Luxury"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "$0-50"
        case .medium: return "$50-150"
        case .high: return "$150-300"
        case .luxury: return "$300+"
        }
    }
}

enum ActivityCategory: String, CaseIterable, Codable {
    case dining = "dining"
    case outdoor = "outdoor"
    case cultural = "cultural"
    case active = "active"
    case relaxed = "relaxed"
    case romantic = "romantic"
    case adventure = "adventure"
    case entertainment = "entertainment"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .dining: return "fork.knife"
        case .outdoor: return "leaf.fill"
        case .cultural: return "building.columns.fill"
        case .active: return "figure.run"
        case .relaxed: return "sofa.fill"
        case .romantic: return "heart.fill"
        case .adventure: return "mountain.2.fill"
        case .entertainment: return "theatermasks.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .dining: return .orange
        case .outdoor: return .green
        case .cultural: return .purple
        case .active: return .blue
        case .relaxed: return .mint
        case .romantic: return .red
        case .adventure: return .yellow
        case .entertainment: return .pink
        }
    }
}

enum TimePreference: String, CaseIterable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case flexible = "flexible"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .flexible: return "clock.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .purple
        case .flexible: return .blue
        }
    }
}

enum GroupSize: String, CaseIterable, Codable {
    case solo = "solo"
    case couple = "couple"
    case smallGroup = "small_group"
    case largeGroup = "large_group"
    
    var displayName: String {
        switch self {
        case .solo: return "Solo"
        case .couple: return "Couple"
        case .smallGroup: return "Small Group"
        case .largeGroup: return "Large Group"
        }
    }
    
    var description: String {
        switch self {
        case .solo: return "Just me"
        case .couple: return "2 people"
        case .smallGroup: return "3-6 people"
        case .largeGroup: return "7+ people"
        }
    }
    
    var icon: String {
        switch self {
        case .solo: return "person.fill"
        case .couple: return "person.2.fill"
        case .smallGroup: return "person.3.fill"
        case .largeGroup: return "person.3.sequence.fill"
        }
    }
}

struct UserPreferencesRequest: Codable {
    let budgetRange: BudgetRange
    let activityCategories: [ActivityCategory]
    let location: GeoLocationPayload?
    let searchRadius: Double
    let timePreference: TimePreference
    let groupSize: GroupSize
    let allowAdultContent: Bool
    let notificationsEnabled: Bool
}

// MARK: - Location Manager
// Using shared LocationManager from RecommendationsViewModel

#Preview {
    PreferencesEditView()
        .environmentObject(AuthViewModel())
}