# Activities Tab - Complete Implementation Plan

## Executive Summary

This document provides a comprehensive build plan to implement the complete Activities Tab functionality as specified in `ACTIVITIES_TAB_DOCUMENTATION.md`. The existing Swift iOS app has foundational activities functionality but requires significant enhancements to match the full specification.

## Current State Analysis

### ✅ What Currently Exists

1. **Basic Infrastructure**
   - `EnhancedActivitiesViewModel.swift` - Core view model with OpenAI integration
   - `ActivitiesView.swift` - Main activities view with search, filters, and categories
   - `ActivityDetailView.swift` - Detail view for individual activities
   - `Activity.swift` - Comprehensive activity model
   - OpenAI service integration for generating recommendations

2. **Existing Features**
   - Activity generation with "Generate Activities" button
   - Search functionality
   - Basic category filtering
   - Quick filter presets (Nearby & Free, High Rated, Romantic, etc.)
   - Bookmark system
   - Sort options (Recommended, Rating, Distance, Name, Newest, Price)
   - Price and location filtering
   - Personality matching integration

### ❌ What's Missing (Documentation Requirements)

1. **Location Services**
   - ✅ **COMPLETED**: LocationService.swift with Core Location integration
   - ✅ **COMPLETED**: BigDataCloud reverse geocoding
   - ✅ **COMPLETED**: Location caching (5-minute expiration)
   - ❌ Location UI in activities page
   - ❌ "Update" and "Prefs" buttons

2. **Structured Activity Categories**
   - The 7 specific categories from documentation:
     - Recommended (⭐ blue)
     - Near Me (📍 green)
     - Dining (🍽️ orange)
     - Outdoor (🌳 emerald)
     - Cultural (🎭 purple)
     - Active (⚡ red)
     - Drinks (🍹 amber)

3. **Drink Sub-Categories**
   - ☕ Coffee
   - 🍵 Tea
   - 🍷 Alcohol
   - 🥤 Non-Alcohol
   - 🧋 Boba
   - 🥛 Other

4. **Dynamic Radius Control**
   - Slider: 1-50 miles (default 25)
   - Real-time adjustment
   - Visual feedback with mile markers
   - Session persistence

5. **Generation Limit System**
   - 3 generations per category
   - "Get Recommendations" (initial)
   - "Generate More" button (2 additional)
   - "Reset" option
   - Generation count tracking

6. **Activity Scheduling**
   - Schedule modal with date/time pickers
   - Notes field
   - Calendar integration
   - 2-hour default duration
   - Event storage in calendar_events table

7. **Expandable Card UI**
   - "See Details" toggle
   - Smooth animations
   - Extended information display
   - State persistence during session

8. **API Endpoint Integration**
   - `/api/recommendations/location-based`
   - `/api/recommendations/drinks`
   - `/api/recommendations/ai-powered`
   - `/api/events`

9. **Enhanced Prompt Engineering**
   - Category-specific prompts for AI
   - Drink-specific prompts
   - Personality-matched recommendations

## Implementation Roadmap

### Phase 1: Foundation & Location (Week 1)

#### ✅ Task 1.1: Location Service - COMPLETED
**Files Created:**
- `BlueBoxy/Services/LocationService.swift`

**Features Implemented:**
- Core Location integration with CLLocationManager
- Permission handling (notDetermined, granted, denied)
- High-accuracy location detection with 10-second timeout
- BigDataCloud API reverse geocoding
- Location caching (5-minute expiration)
- "City, State" formatting
- Error handling with fallback to coordinates
- Notification system for location updates

#### Task 1.2: Location UI Components
**Files to Create/Modify:**
- `BlueBoxy/Views/Activities/LocationHeaderView.swift` (NEW)
- `BlueBoxy/Views/Activities/ActivitiesView.swift` (MODIFY)

**Requirements:**
```swift
// LocationHeaderView.swift - Glass-effect card showing location status
struct LocationHeaderView: View {
    @ObservedObject var locationService: LocationService
    @Binding var showingPreferences: Bool
    
    var body: some View {
        HStack {
            // Location icon with permission status indicator
            // Location name or "Detecting location..."
            // "Update" button
            // "Prefs" button
        }
        .padding()
        .background(glassEffectBackground)
    }
}
```

**UI Specifications:**
- Glass card effect: `background(rgba(255,255,255,0.1))` with blur
- Location icon changes based on permission status
- Real-time location name display
- Loading spinner during location detection
- Error state display

### Phase 2: Activity Categories & Structure (Week 2)

#### Task 2.1: Activity Category Models
**Files to Create:**
- `BlueBoxy/Models/ActivityCategory.swift` (NEW)

**Requirements:**
```swift
enum ActivityCategory: String, CaseIterable {
    case recommended
    case nearMe = "near_me"
    case dining
    case outdoor
    case cultural
    case active
    case drinks
    
    var displayName: String { /* ... */ }
    var icon: String { /* SF Symbol name */ }
    var color: Color { /* Category color */ }
    var description: String { /* Category description */ }
    
    // AI prompt instructions per category
    var aiPromptInstructions: String
}

enum DrinkCategory: String, CaseIterable {
    case coffee, tea, alcohol, nonAlcohol = "non_alcohol", boba, other
    
    var displayName: String { /* ... */ }
    var icon: String { /* Emoji */ }
    var aiPromptInstructions: String
}
```

#### Task 2.2: Category Selection UI
**Files to Modify:**
- `BlueBoxy/Views/Activities/ActivitiesView.swift`

**Requirements:**
- Horizontal scrolling category selector
- 7 category buttons with specific styling per category
- Sub-category tabs for Drinks category
- Active state highlighting with category colors
- Touch-friendly buttons (44x44pt minimum)

**UI Components:**
```swift
struct CategoryTabBar: View {
    // Horizontal ScrollView with 7 main categories
    // Each button shows icon + label
    // Active category has colored background
}

struct DrinkSubCategoryBar: View {
    // Shows when drinks category is active
    // 6 drink type buttons
    // Smaller, compact design
}
```

### Phase 3: Radius Control & Filtering (Week 2)

#### Task 3.1: Radius Slider Component
**Files to Create:**
- `BlueBoxy/Views/Activities/RadiusControlView.swift` (NEW)

**Requirements:**
```swift
struct RadiusControlView: View {
    @Binding var radius: Double // 1-50 miles
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search Radius")
                Spacer()
                Text("\(Int(radius)) miles")
                    .foregroundColor(.blue)
            }
            
            Slider(value: $radius, in: 1...50, step: 1)
                .accentColor(.blue)
            
            HStack {
                Text("1 mi")
                    .font(.caption)
                Spacer()
                Text("25 mi")
                    .font(.caption)
                Spacer()
                Text("50 mi")
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

**Features:**
- Real-time value display
- Mile markers at 1, 25, 50
- Debounced API calls (300ms delay)
- UserDefaults persistence
- Visual feedback during drag

#### Task 3.2: Enhanced Filtering Logic
**Files to Modify:**
- `BlueBoxy/ViewModels/EnhancedActivitiesViewModel.swift`

**New Methods:**
```swift
// Apply radius filter to recommendations
func filterByRadius(_ activities: [Activity], radius: Double) -> [Activity]

// Priority-based sorting (1 local, 2 within radius)
func sortByLocalAndRadius(_ activities: [Activity]) -> [Activity]

// Category-specific filtering
func filterByCategory(_ activities: [Activity], category: ActivityCategory) -> [Activity]
```

### Phase 4: Generation Limit System (Week 3)

#### Task 4.1: Generation Tracking Model
**Files to Create:**
- `BlueBoxy/Models/GenerationTracker.swift` (NEW)

**Requirements:**
```swift
class GenerationTracker {
    private var generationCounts: [String: Int] = [:] // userId_category -> count
    private var previousRecommendations: [String: [String]] = [:] // Track IDs
    
    func incrementGeneration(for key: String)
    func getGenerationsRemaining(for key: String) -> Int
    func canGenerateMore(for key: String) -> Bool
    func resetGeneration(for key: String)
    func addPreviousRecommendations(for key: String, ids: [String])
    func getPreviousRecommendations(for key: String) -> [String]
}
```

**Constants:**
- Maximum generations: 3
- Key format: `"{userId}_{category}"`
- Persist in UserDefaults

#### Task 4.2: Generation UI States
**Files to Modify:**
- `BlueBoxy/Views/Activities/ActivitiesView.swift`
- `BlueBoxy/ViewModels/EnhancedActivitiesViewModel.swift`

**UI States:**
1. **Initial State (0 generations)**
   - Large "Get Recommendations" button
   - Explanation text
   - Sparkles icon

2. **After First Generation (1-2 generations)**
   - "Generate More" button appears
   - Shows "X generations remaining"
   - Smaller, secondary style button

3. **After 3 Generations (limit reached)**
   - "Reset Algorithm" button
   - Explanation text about limit
   - Warning icon

**Button Behaviors:**
```swift
// Generate button logic
if generationsRemaining > 0 {
    await generateRecommendations(resetAlgorithm: false)
} else {
    // Show reset option
}

// Reset button logic
func resetAndRegenerate() {
    generationTracker.resetGeneration(for: currentKey)
    await generateRecommendations(resetAlgorithm: true)
}
```

### Phase 5: Activity Scheduling (Week 3-4)

#### Task 5.1: Scheduling Models
**Files to Create:**
- `BlueBoxy/Models/SchedulingData.swift` (NEW)

**Requirements:**
```swift
struct SchedulingData {
    var date: Date
    var time: Date
    var notes: String
    
    func toCalendarEvent(activity: Activity, userId: Int) -> CalendarEventDB {
        let startDateTime = combineDateAndTime(date: date, time: time)
        let endDateTime = startDateTime.addingTimeInterval(2 * 60 * 60) // +2 hours
        
        return CalendarEventDB(
            userId: userId,
            title: activity.name,
            description: formatDescription(activity: activity, notes: notes),
            location: activity.location,
            startTime: startDateTime.ISO8601Format(),
            endTime: endDateTime.ISO8601Format(),
            eventType: "date",
            allDay: false
        )
    }
}
```

#### Task 5.2: Scheduling Modal View
**Files to Create:**
- `BlueBoxy/Views/Activities/ScheduleActivityModal.swift` (NEW)

**Requirements:**
```swift
struct ScheduleActivityModal: View {
    let activity: Activity
    @Binding var isPresented: Bool
    @State private var schedulingData = SchedulingData()
    @ObservedObject var calendarViewModel: CalendarViewModel
    
    var body: some View {
        NavigationView {
            Form {
                // Activity preview section
                Section("Activity Details") {
                    // Name, category, location
                }
                
                // Date/Time selection
                Section("When") {
                    DatePicker("Date", selection: $schedulingData.date, displayedComponents: .date)
                    DatePicker("Time", selection: $schedulingData.time, displayedComponents: .hourAndMinute)
                }
                
                // Optional notes
                Section("Notes") {
                    TextEditor(text: $schedulingData.notes)
                }
                
                // Schedule button
                Section {
                    Button("Schedule Activity") {
                        scheduleActivity()
                    }
                }
            }
        }
    }
    
    func scheduleActivity() {
        let event = schedulingData.toCalendarEvent(activity: activity, userId: userId)
        Task {
            await calendarViewModel.createEvent(event)
            isPresented = false
        }
    }
}
```

**UI Specifications:**
- Bottom sheet presentation (50% screen height)
- Native iOS date/time pickers
- Character limit for notes (500 chars)
- Loading state during save
- Success/error toast notifications

### Phase 6: Expandable Card UI (Week 4)

#### Task 6.1: Enhanced Activity Card
**Files to Modify:**
- `BlueBoxy/Views/Activities/ActivitiesView.swift` (ActivityListCard)

**Requirements:**
```swift
struct ActivityListCard: View {
    let activity: Activity
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Always visible content
            headerSection
            ratingAndDistanceSection
            
            if !isExpanded {
                descriptionPreview // 3 lines max
            } else {
                fullExpandedContent
            }
            
            // Toggle button
            Button(action: { 
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "See Details")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
    
    private var fullExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Full description
            Text(activity.description)
            
            // Complete address
            if let address = activity.address {
                AddressRow(address: address)
            }
            
            // Phone number
            if let phone = activity.phone {
                PhoneRow(phone: phone)
            }
            
            // Website link
            if let website = activity.website {
                WebsiteRow(website: website)
            }
            
            // Atmosphere
            if let atmosphere = activity.atmosphere {
                AtmosphereRow(atmosphere: atmosphere)
            }
            
            // Personality match explanation
            if let match = activity.personalityMatch {
                PersonalityMatchRow(match: match)
            }
        }
    }
}
```

**Animations:**
- Spring animation (duration: 0.3s)
- Smooth height transitions
- Chevron rotation
- Opacity fades for expanding content

### Phase 7: API Integration (Week 5)

#### Task 7.1: Backend API Models
**Files to Create:**
- `BlueBoxy/Models/RecommendationRequest.swift` (NEW)
- `BlueBoxy/Models/RecommendationResponse.swift` (NEW)

**API Request Models:**
```swift
// POST /api/recommendations/location-based
struct LocationBasedRecommendationRequest: Codable {
    let userId: Int
    let location: LocationCoordinates
    let radius: Int
    let category: String
    let preferences: [String: JSONValue]?
    let personalityType: String?
    let resetAlgorithm: Bool
}

// POST /api/recommendations/drinks
struct DrinksRecommendationRequest: Codable {
    let userId: Int
    let location: LocationCoordinates
    let radius: Int
    let drinkPreferences: [String]
    let personalityType: String?
    let resetAlgorithm: Bool
}

// POST /api/events
struct CreateEventRequest: Codable {
    let userId: Int
    let title: String
    let description: String
    let location: String
    let startTime: String // ISO8601
    let endTime: String // ISO8601
    let eventType: String
    let allDay: Bool
}
```

#### Task 7.2: API Service Methods
**Files to Modify:**
- `BlueBoxy/Services/BlueBoxyAPIService.swift`

**New Methods:**
```swift
extension BlueBoxyAPIService {
    func getLocationBasedRecommendations(request: LocationBasedRecommendationRequest) async throws -> AILocationBasedResponse
    
    func getDrinkRecommendations(request: DrinksRecommendationRequest) async throws -> AIDrinksResponse
    
    func createCalendarEvent(request: CreateEventRequest) async throws -> CalendarEventDB
}
```

### Phase 8: Enhanced AI Prompting (Week 5)

#### Task 8.1: Category-Specific Prompt Builder
**Files to Create:**
- `BlueBoxy/Services/AIPromptBuilder.swift` (NEW)

**Requirements:**
```swift
struct AIPromptBuilder {
    static func buildActivityPrompt(
        category: ActivityCategory,
        location: CLLocationCoordinate2D,
        radius: Double,
        personalityType: String?,
        preferences: [String]?
    ) -> String {
        var prompt = basePrompt(category: category, location: location, radius: radius)
        prompt += categoryInstructions(category)
        prompt += personalityContext(personalityType)
        prompt += preferencesContext(preferences)
        prompt += responseFormat()
        return prompt
    }
    
    static func buildDrinkPrompt(
        drinkCategory: DrinkCategory,
        location: CLLocationCoordinate2D,
        radius: Double,
        personalityType: String?
    ) -> String {
        // Drink-specific prompt engineering
    }
    
    private static func categoryInstructions(_ category: ActivityCategory) -> String {
        switch category {
        case .recommended:
            return "Focus on highly-rated, personality-matched activities..."
        case .nearMe:
            return "Prioritize proximity and quality. Include closest high-quality options..."
        case .dining:
            return "Include restaurants, cafes, and unique food experiences..."
        case .outdoor:
            return "Focus on parks, hiking trails, outdoor activities for couples..."
        case .cultural:
            return "Include museums, galleries, theaters, enriching cultural experiences..."
        case .active:
            return "Focus on fitness activities, sports, active pursuits for couples..."
        case .drinks:
            return "Include bars, cafes, beverage-focused venues with great atmospheres..."
        }
    }
}
```

### Phase 9: Mobile UI Polish (Week 6)

#### Task 9.1: Responsive Design Enhancements
**Files to Modify:**
- All view files

**Requirements:**
- Touch-friendly buttons (44x44pt minimum)
- Horizontal scrolling for categories (no wrapping)
- Sticky location header on scroll
- Bottom-safe-area padding for tab bar
- Proper keyboard handling for search/notes
- Pull-to-refresh for recommendations
- Loading skeletons/placeholders

#### Task 9.2: Glass Effect Components
**Files to Create:**
- `BlueBoxy/Views/Components/GlassCard.swift` (NEW)

**Glass Effect Style:**
```swift
struct GlassCard<Content: View>: View {
    let content: Content
    
    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
```

### Phase 10: Testing (Week 6-7)

#### Task 10.1: Unit Tests
**Files to Create:**
- `BlueBoxyTests/LocationServiceTests.swift`
- `BlueBoxyTests/GenerationTrackerTests.swift`
- `BlueBoxyTests/AIPromptBuilderTests.swift`
- `BlueBoxyTests/SchedulingDataTests.swift`

**Test Coverage:**
- Location detection and caching
- Reverse geocoding
- Generation limit tracking
- AI prompt generation
- Date/time formatting
- Filtering algorithms
- Sorting logic

#### Task 10.2: Integration Tests
**Files to Create:**
- `BlueBoxyTests/ActivitiesFlowTests.swift`
- `BlueBoxyTests/SchedulingFlowTests.swift`

**Test Scenarios:**
- Complete recommendation flow (location → generate → filter → schedule)
- Category switching
- Generation limit enforcement
- API error handling
- Location permission scenarios

#### Task 10.3: UI Tests
**Files to Create:**
- `BlueBoxyUITests/ActivitiesUITests.swift`

**Test Scenarios:**
- Category selection and switching
- Radius slider interaction
- Card expansion/collapse
- Scheduling modal flow
- Search and filter interactions

## Data Flow Diagrams

### Recommendation Generation Flow
```
User Action → 
  Request Location Permission →
  Detect Location (CLLocationManager) →
  Reverse Geocode (BigDataCloud) →
  Build AI Prompt (category + location + radius + personality) →
  Call AI API (OpenAI/Grok) →
  Parse Response →
  Filter by Radius →
  Sort (1 local + 2 within radius) →
  Update UI →
  Increment Generation Count
```

### Scheduling Flow
```
User Taps "Schedule" →
  Open ScheduleActivityModal →
  User Selects Date/Time →
  User Adds Notes (optional) →
  User Taps "Schedule Activity" →
  Create CalendarEventDB →
  POST /api/events →
  Success:
    - Close Modal
    - Show Toast
    - Invalidate Calendar Queries
    - Event Appears in Calendar Tab
  Error:
    - Show Error Message
    - Keep Modal Open
```

### Location Detection Flow
```
App Launch →
  Check Location Permission →
  If Granted:
    Check Cache (< 5 min old) →
    If Valid:
      Use Cached Location
    Else:
      Request Current Location →
      Got Location:
        Reverse Geocode →
        Cache Location
  If Not Granted:
    Show Request Permission UI →
    User Grants:
      Request Current Location
    User Denies:
      Show Manual Entry Option
```

## File Structure

```
BlueBoxy/
├── Views/
│   └── Activities/
│       ├── ActivitiesView.swift (EXISTING - MODIFY)
│       ├── ActivityDetailView.swift (EXISTING - MODIFY)
│       ├── LocationHeaderView.swift (NEW)
│       ├── RadiusControlView.swift (NEW)
│       ├── CategoryTabBar.swift (NEW)
│       ├── DrinkSubCategoryBar.swift (NEW)
│       ├── ScheduleActivityModal.swift (NEW)
│       └── ExpandableActivityCard.swift (NEW)
│
├── ViewModels/
│   ├── EnhancedActivitiesViewModel.swift (EXISTING - MODIFY)
│   └── ActivitiesViewModel.swift (EXISTING - MODIFY)
│
├── Services/
│   ├── LocationService.swift (NEW - ✅ COMPLETED)
│   ├── AIPromptBuilder.swift (NEW)
│   └── BlueBoxyAPIService.swift (EXISTING - MODIFY)
│
├── Models/
│   ├── Activity.swift (EXISTING - MODIFY)
│   ├── ActivityCategory.swift (NEW)
│   ├── DrinkCategory.swift (NEW)
│   ├── GenerationTracker.swift (NEW)
│   ├── SchedulingData.swift (NEW)
│   ├── RecommendationRequest.swift (NEW)
│   └── RecommendationResponse.swift (NEW)
│
└── Components/
    ├── GlassCard.swift (NEW)
    └── LoadingSkeletons.swift (NEW)
```

## Technical Specifications

### Location Services
- **Accuracy:** `kCLLocationAccuracyBest` (high accuracy mode)
- **Timeout:** 10 seconds
- **Cache Duration:** 5 minutes
- **Reverse Geocoding:** BigDataCloud API (free, no key required)
- **Format:** "City, State" or coordinates fallback

### Generation Limits
- **Max Generations:** 3 per category per user
- **Storage:** UserDefaults with key format: `generations_{userId}_{category}`
- **Reset:** Manual reset by user or automatic after 24 hours
- **Tracking:** Previous recommendation IDs to exclude repeats

### Radius Control
- **Range:** 1-50 miles
- **Default:** 25 miles
- **Step:** 1 mile
- **Debounce:** 300ms before triggering API call
- **Persistence:** UserDefaults key: `activities_search_radius`

### Activity Categories
| Category | Icon | Color | Priority |
|----------|------|-------|----------|
| Recommended | ⭐ | Blue | Personality match |
| Near Me | 📍 | Green | Distance |
| Dining | 🍽️ | Orange | Rating |
| Outdoor | 🌳 | Emerald | Seasonal |
| Cultural | 🎭 | Purple | Rating |
| Active | ⚡ | Red | Fitness level |
| Drinks | 🍹 | Amber | Atmosphere |

### Scheduling
- **Default Duration:** 2 hours
- **Event Type:** "date"
- **Storage:** PostgreSQL `calendar_events` table
- **Integration:** Syncs with Calendar tab
- **Notifications:** Optional reminder support

## Success Criteria

### Functional Requirements
- [ ] All 7 categories implemented with correct styling
- [ ] 6 drink sub-categories functional
- [ ] Location detection working with 95%+ accuracy
- [ ] Radius slider responsive with <300ms debounce
- [ ] Generation limit enforced (3 per category)
- [ ] Scheduling creates events successfully
- [ ] Cards expand/collapse smoothly (<0.3s animation)
- [ ] AI prompts generate category-appropriate recommendations

### Performance Requirements
- [ ] Location detection: <3 seconds average
- [ ] Recommendation generation: <5 seconds average
- [ ] Reverse geocoding: <2 seconds average
- [ ] Card expansion animation: <300ms
- [ ] API calls complete within 10-second timeout
- [ ] UI remains responsive during async operations

### UX Requirements
- [ ] Touch targets ≥44x44pt
- [ ] All text readable (WCAG AA compliance)
- [ ] Smooth animations (60 FPS)
- [ ] Loading states for all async operations
- [ ] Clear error messages with recovery options
- [ ] Offline graceful degradation

## Dependencies

### iOS Frameworks
- CoreLocation (location services)
- MapKit (optional - for map views)
- SwiftUI (UI framework)
- Combine (reactive programming)

### Third-Party Services
- BigDataCloud API (reverse geocoding)
- OpenAI API (activity recommendations)
- Grok AI API (optional - alternative recommendations)

### Backend Requirements
- PostgreSQL database with `calendar_events` table
- REST API endpoints:
  - `POST /api/recommendations/location-based`
  - `POST /api/recommendations/drinks`
  - `POST /api/events`
  - `GET /api/user/profile`

## Timeline Summary

| Week | Phase | Tasks | Deliverables |
|------|-------|-------|--------------|
| 1 | Foundation | ✅ Location service, UI components | Working location detection |
| 2 | Categories | Category models, UI, radius control | 7 categories + drinks subcategories |
| 3 | Generation | Limit tracking, scheduling foundation | Generation limits working |
| 4 | Scheduling | Modal UI, calendar integration | Scheduling functional |
| 5 | API & AI | API integration, prompt engineering | Backend integration complete |
| 6 | Polish | Responsive design, glass effects | Production-ready UI |
| 7 | Testing | Unit, integration, UI tests | 80%+ test coverage |

**Total Estimated Time:** 7 weeks

## Risk Mitigation

### High-Risk Items
1. **Location Permission Denied**
   - Mitigation: Manual location entry fallback
   - Fallback: Use last known location or city-level search

2. **AI API Rate Limits**
   - Mitigation: Caching and generation limits
   - Fallback: Pre-generated static recommendations

3. **Network Connectivity Issues**
   - Mitigation: Offline mode with cached data
   - Fallback: Error messages with retry options

4. **Calendar Integration Conflicts**
   - Mitigation: Robust error handling
   - Fallback: Export to iOS Calendar app

## Next Steps

1. ✅ **COMPLETED:** Review and approve implementation plan
2. ✅ **COMPLETED:** Create LocationService.swift
3. **IN PROGRESS:** Implement LocationHeaderView UI
4. Create ActivityCategory and DrinkCategory models
5. Implement category selection UI
6. Add radius control slider
7. Continue through phases 4-10

## Conclusion

This implementation plan provides a comprehensive roadmap for building the complete Activities Tab functionality as specified in the documentation. The phased approach ensures systematic development with clear milestones and deliverables. The current progress (LocationService completed) provides a strong foundation for the remaining implementation.

**Status:** Ready to proceed with Phase 1, Task 1.2 (Location UI Components)

**Last Updated:** 2025-10-22