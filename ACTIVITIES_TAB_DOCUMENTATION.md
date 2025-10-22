# Activities Tab - Complete Development Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features & Functionality](#features--functionality)
4. [Frontend Implementation](#frontend-implementation)
5. [Backend Implementation](#backend-implementation)
6. [AI Integration](#ai-integration)
7. [Data Flow](#data-flow)
8. [API Endpoints](#api-endpoints)
9. [User Preferences System](#user-preferences-system)
10. [Location Services](#location-services)
11. [Scheduling System](#scheduling-system)
12. [UI/UX Design](#uiux-design)
13. [Technical Specifications](#technical-specifications)

---

## Overview

The Activities Tab is a core feature of BlueBoxy that provides AI-powered, location-based activity and drink recommendations for couples. It leverages personality assessment data, user preferences, and geolocation to generate personalized date suggestions tailored to each relationship.

**Key Capabilities:**
- Real-time geolocation detection and reverse geocoding
- AI-powered recommendations using Grok AI (xAI) and OpenAI
- Multi-category activity suggestions (Dining, Outdoor, Cultural, Active, Drinks)
- Drink-specific recommendations with sub-categories
- Event scheduling with calendar integration
- Customizable search radius (1-50 miles)
- Generation limit system (3 total generations per category)
- Personality-matched recommendations based on assessment results

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Activities Page                       │
│  (client/src/pages/activities.tsx)                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ├─── Location Detection
                 │    ├─► Browser Geolocation API
                 │    └─► Reverse Geocoding (BigDataCloud)
                 │
                 ├─── User Data
                 │    └─► GET /api/user/profile
                 │
                 ├─── Recommendations
                 │    ├─► POST /api/recommendations/location-based
                 │    ├─► POST /api/recommendations/drinks
                 │    └─► POST /api/recommendations/ai-powered
                 │
                 └─── Event Scheduling
                      └─► POST /api/events
                           │
┌──────────────────────────┴──────────────────────────────┐
│                  Backend Services                        │
├──────────────────────────────────────────────────────────┤
│  Grok AI Service (server/grok-ai.ts)                    │
│  ├─► generateActivityRecommendations()                  │
│  ├─► generateDrinkRecommendations()                     │
│  └─► Recommendation Algorithm (generation limits)       │
│                                                          │
│  OpenAI Service (server/openai.ts)                      │
│  ├─► generateLocationBasedRecommendations()             │
│  └─► generateAIPoweredRecommendations()                 │
│                                                          │
│  Storage Layer (server/storage.ts)                      │
│  └─► PostgreSQL Database (Neon)                         │
└──────────────────────────────────────────────────────────┘
```

### Technology Stack

**Frontend:**
- React 18 with TypeScript
- TanStack Query v5 (server state management)
- Wouter (routing)
- Radix UI components
- Tailwind CSS (styling)
- Lucide React (icons)

**Backend:**
- Express.js with TypeScript
- Drizzle ORM (PostgreSQL)
- Axios (HTTP client for AI APIs)
- bcrypt (password hashing)

**External Services:**
- Grok AI (xAI) - Primary recommendation engine
- OpenAI GPT-4o - Alternative recommendation engine
- BigDataCloud API - Reverse geocoding
- Browser Geolocation API - Location detection

---

## Features & Functionality

### 1. Location Detection & Management

**Automatic Location Detection:**
- Detects user location on page load using browser geolocation
- Requests high-accuracy position with 10-second timeout
- Caches location for 5 minutes to reduce API calls
- Handles permission denied scenarios gracefully

**Reverse Geocoding:**
- Converts coordinates to human-readable location names
- Displays "City, State" format
- Fallback to coordinates if city name unavailable
- Uses free BigDataCloud API (no authentication required)

**Manual Location Control:**
- "Update" button to refresh current location
- "Prefs" button to navigate to preferences page
- Visual indicators for location permission status
- Location name displayed prominently in UI

### 2. Activity Categories

**Seven Primary Categories:**

1. **Recommended** (⭐ blue)
   - Highly-rated activities based on personality type
   - Personalized to user's assessment results
   - Balanced mix of categories

2. **Near Me** (📍 green)
   - Prioritizes proximity (within 2-3 miles)
   - Quality-focused local options
   - Perfect for spontaneous dates

3. **Dining** (🍽️ orange)
   - Restaurants, cafes, unique food experiences
   - Cuisine variety and ambiance focus
   - Price range specifications

4. **Outdoor** (🌳 emerald)
   - Parks, hiking trails, nature activities
   - Couple-friendly outdoor experiences
   - Seasonal considerations

5. **Cultural** (🎭 purple)
   - Museums, galleries, theaters
   - Enriching cultural experiences
   - Educational and artistic venues

6. **Active** (⚡ red)
   - Fitness activities, sports
   - Active pursuits for couples
   - Energy-level matched recommendations

7. **Drinks** (🍹 amber)
   - Specialized drink venue recommendations
   - Sub-categories for drink types
   - Atmosphere-focused suggestions

### 3. Drink Sub-Categories

When "Drinks" category is selected, users can filter by:
- ☕ **Coffee** - Coffee shops, specialty roasters, artisan cafes
- 🍵 **Tea** - Tea houses, bubble tea, specialty tea cafes
- 🍷 **Alcohol** - Bars, cocktail lounges, wine bars
- 🥤 **Non-Alcohol** - Juice bars, smoothie shops, creative beverages
- 🧋 **Boba** - Bubble tea shops, authentic boba experiences
- 🥛 **Other** - Unique beverage spots, specialty drinks

### 4. Search Radius Control

**Dynamic Radius Slider:**
- Range: 1-50 miles
- Default: 25 miles
- Real-time adjustment
- Visual feedback with mile markers
- Persists across page refreshes

### 5. Recommendation Generation

**Generation System:**
- **Initial Generation:** "Get Recommendations" button
- **Additional Generations:** "Generate More" button (2 additional allowed)
- **Total Limit:** 3 generations per category
- **Reset Option:** Resets generation count for fresh recommendations
- **Loading States:** Spinner animation during API calls

**Generation Algorithm (Grok AI):**
```
Generation 1: Fresh recommendations
Generation 2: New recommendations (excludes previous)
Generation 3: Final set (excludes all previous)
After 3: Must reset to generate more
```

### 6. Activity Scheduling

**Schedule Modal Features:**
- Date picker (calendar input)
- Time selector (24-hour format)
- Optional notes field
- Event preview before submission
- Default 2-hour duration
- Automatic calendar integration

**Event Data Structure:**
```typescript
{
  userId: number,
  title: string,              // Activity name
  description: string,        // Full activity details
  location: string,           // Activity address
  startTime: ISO8601,        // Selected date + time
  endTime: ISO8601,          // +2 hours from start
  eventType: 'date',         // Event category
  allDay: false              // Time-specific event
}
```

### 7. Card Interaction System

**Expandable/Collapsible Cards:**
- "See Details" toggle button
- Smooth expand/collapse animation
- Shows/hides:
  - Full description
  - Complete address
  - Atmosphere details
  - Personality match explanation
- State persists during session
- Chevron icon indicates expand/collapse state

**Card Information Display:**
- **Always Visible:**
  - Activity name
  - Star rating
  - Distance in miles
  - Price estimate
  - Estimated cost
  - Recommended time
  - Specialties badges
  - Schedule button

- **Expandable Section:**
  - Full description
  - Complete street address
  - Phone number (if available)
  - Website link (if available)
  - Atmosphere description
  - Personality match explanation

---

## Frontend Implementation

### Component Structure

**File:** `client/src/pages/activities.tsx`

**State Management:**

```typescript
// Navigation
const [, setLocation] = useLocation();

// Category & Filtering
const [activeCategory, setActiveCategory] = useState("recommended");
const [activeDrinkTab, setActiveDrinkTab] = useState("coffee");

// Location
const [userLocation, setUserLocation] = useState<Location | null>(null);
const [locationName, setLocationName] = useState<string>("");
const [locationPermissionStatus, setLocationPermissionStatus] = useState<Status>("prompt");

// Recommendations
const [radius, setRadius] = useState([25]);
const [recommendations, setRecommendations] = useState<ActivityRecommendation[]>([]);
const [drinkRecommendations, setDrinkRecommendations] = useState<Record<string, ActivityRecommendation[]>>({});

// Generation Control
const [canGenerateMore, setCanGenerateMore] = useState(true);
const [generationsRemaining, setGenerationsRemaining] = useState(2);
const [isGenerating, setIsGenerating] = useState(false);

// UI State
const [expandedCards, setExpandedCards] = useState<Set<string>>(new Set());

// Scheduling
const [isScheduleModalOpen, setIsScheduleModalOpen] = useState(false);
const [selectedActivity, setSelectedActivity] = useState<ActivityRecommendation | null>(null);
const [schedulingData, setSchedulingData] = useState({
  date: '',
  time: '',
  notes: ''
});
```

### Key Functions

**Location Detection:**
```typescript
const detectLocation = async () => {
  // Request geolocation permission
  const position = await navigator.geolocation.getCurrentPosition();
  
  // Set location state
  setUserLocation({
    latitude: position.coords.latitude,
    longitude: position.coords.longitude
  });
  
  // Reverse geocode to get city name
  const locationName = await reverseGeocode(lat, lng);
  setLocationName(locationName);
};
```

**Recommendation Generation:**
```typescript
const handleGetRecommendations = async (resetAlgorithm = false) => {
  if (activeCategory === "drinks") {
    // Generate drink recommendations
    const response = await apiRequest("POST", "/api/recommendations/drinks", {
      userId, location, radius, drinkPreferences, personalityType, resetAlgorithm
    });
  } else {
    // Generate activity recommendations
    const response = await apiRequest("POST", "/api/recommendations/location-based", {
      userId, location, radius, category, preferences, personalityType, resetAlgorithm
    });
  }
  
  // Update state with results
  setRecommendations(result.recommendations);
  setCanGenerateMore(result.canGenerateMore);
  setGenerationsRemaining(result.generationsRemaining);
};
```

**Event Scheduling:**
```typescript
const handleScheduleSubmit = () => {
  const startDateTime = new Date(`${schedulingData.date}T${schedulingData.time}`);
  const endDateTime = new Date(startDateTime.getTime() + 2 * 60 * 60 * 1000);
  
  scheduleEventMutation.mutate({
    userId,
    title: selectedActivity.name,
    description: /* full details */,
    location: selectedActivity.address,
    startTime: startDateTime.toISOString(),
    endTime: endDateTime.toISOString(),
    eventType: 'date',
    allDay: false
  });
};
```

### UI Components Used

**Radix UI Components:**
- `Dialog` - Scheduling modal
- `Button` - All interactive buttons
- `Card` - Activity recommendation cards
- `Slider` - Radius control
- `Badge` - Specialty tags
- `Input` - Date/time inputs
- `Textarea` - Notes field
- `Label` - Form labels

**Lucide React Icons:**
- `MapPin` - Location marker
- `Star` - Rating display
- `Navigation` - Location active state
- `Sparkles` - Generate recommendations
- `RefreshCw` - Update location / Generate more
- `Settings` - Preferences access
- `Calendar` - Schedule event
- `Clock` - Time indicator
- `DollarSign` - Price indicator
- `ChevronDown/Up` - Expand/collapse
- `Loader2` - Loading spinner
- Category-specific icons (Utensils, TreePine, Palette, etc.)

---

## Backend Implementation

### Grok AI Service

**File:** `server/grok-ai.ts`

**Core Class:** `GrokAIService`

**Key Features:**
- Generation limit tracking (max 3 per category)
- Recommendation exclusion system
- Session-based state management
- Fallback recommendations when AI unavailable
- Real location data within specified radius

**Activity Generation:**
```typescript
async generateActivityRecommendations(
  userId: number,
  location: Location,
  radius: number,
  category: string,
  preferences: any,
  personalityType?: string
): Promise<{
  recommendations: ActivityRecommendation[];
  canGenerateMore: boolean;
  generationsRemaining: number;
}> {
  // Build category-specific prompt
  const prompt = this.buildActivityPrompt(category, location, radius, preferences, personalityType);
  
  // Call Grok API
  const response = await this.callGrokAPI(prompt);
  
  // Parse and sort results
  const recommendations = this.parseActivityResponse(response, category, location);
  const sorted = this.sortByLocalAndRadius(recommendations, location, radius);
  
  // Update generation tracking
  this.algorithm.incrementGeneration(`${userId}_${category}`);
  
  return {
    recommendations: sorted,
    canGenerateMore: this.algorithm.canGenerateMore(`${userId}_${category}`),
    generationsRemaining: this.algorithm.getGenerationsRemaining(`${userId}_${category}`)
  };
}
```

**Drink Generation:**
```typescript
async generateDrinkRecommendations(
  userId: number,
  location: Location,
  radius: number,
  drinkPreferences: string[],
  personalityType?: string
): Promise<{
  recommendations: { [key: string]: ActivityRecommendation[] };
  canGenerateMore: boolean;
  generationsRemaining: number;
}> {
  const results: { [key: string]: ActivityRecommendation[] } = {};
  
  // Generate for each drink preference
  for (const preference of drinkPreferences) {
    const prompt = this.buildDrinkPrompt(preference, location, radius, personalityType);
    const response = await this.callGrokAPI(prompt);
    const recommendations = this.parseActivityResponse(response, 'drinks', location);
    results[preference] = recommendations.slice(0, 3); // Max 3 per type
  }
  
  return {
    recommendations: results,
    canGenerateMore: this.algorithm.canGenerateMore(`${userId}_drinks`),
    generationsRemaining: this.algorithm.getGenerationsRemaining(`${userId}_drinks`)
  };
}
```

**Grok API Integration:**
```typescript
private async callGrokAPI(prompt: string): Promise<string> {
  const response = await axios.post(
    'https://api.x.ai/v1/chat/completions',
    {
      messages: [{ role: 'user', content: prompt }],
      model: 'grok-3-mini',
      temperature: 0.7
    },
    {
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return response.data.choices[0].message.content;
}
```

**Sorting Algorithm:**
```typescript
private sortByLocalAndRadius(
  recommendations: ActivityRecommendation[],
  location: Location,
  radius: number
): ActivityRecommendation[] {
  // Priority: First result must be local (≤3 miles)
  const local = recommendations.filter(r => r.distance <= 3);
  const withinRadius = recommendations.filter(r => r.distance > 3 && r.distance <= radius);
  
  // Sort by rating (primary) and distance (secondary)
  local.sort((a, b) => b.rating - a.rating);
  withinRadius.sort((a, b) => b.rating - a.rating || a.distance - b.distance);
  
  // Return 1 local + 2 within radius
  return [...local.slice(0, 1), ...withinRadius.slice(0, 2)];
}
```

### OpenAI Service

**File:** `server/openai.ts`

**Alternative AI Engine (Fallback):**

```typescript
export async function generateLocationBasedRecommendations(
  context: RecommendationContext,
  userLocation: { latitude: number; longitude: number },
  preferences: any,
  radius: number = 25,
  count: number = 8
): Promise<any[]> {
  const prompt = `Generate ${count} location-based date recommendations for ${context.userName} and ${context.partnerName} near ${userLocation.latitude}, ${userLocation.longitude} within a ${radius}km radius.

Context:
- Personality type: ${context.personalityType}
- Relationship duration: ${context.relationshipDuration}
- User preferences: ${JSON.stringify(preferences)}

Create diverse recommendations across categories: dining, outdoor, entertainment, active, creative, cultural.

Respond with JSON format:
{
  "activities": [
    {
      "id": 1,
      "title": "Activity Name",
      "description": "Why this is perfect for them",
      "category": "dining|outdoor|entertainment|active|creative|cultural",
      "duration": "1-2 hours",
      "budget": "low|medium|high",
      "personalityMatch": "How this matches their personality"
    }
  ]
}`;

  const response = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [
      { role: "system", content: "You are a local relationship expert. Create location-based date recommendations. Always respond with valid JSON." },
      { role: "user", content: prompt }
    ],
    response_format: { type: "json_object" },
    temperature: 0.7,
    max_tokens: 1500
  });

  const result = JSON.parse(response.choices[0].message.content || "{}");
  return result.activities || [];
}
```

---

## AI Integration

### Grok AI (xAI) - Primary Engine

**Model:** `grok-3-mini`
**Temperature:** 0.7
**API Endpoint:** `https://api.x.ai/v1/chat/completions`

**Prompt Engineering for Activities:**
```
Generate 3 real, specific [category] recommendations for a couple's date within [radius] miles of coordinates [lat], [lon].

[Category-specific instructions]

Return a JSON array with exactly this structure for each recommendation:
{
  "id": "unique_id",
  "name": "Establishment Name",
  "description": "Brief engaging description",
  "category": "[category]",
  "rating": 4.5,
  "distance": 2.3,
  "price": "$20-40 per person",
  "address": "Full street address",
  "phone": "phone number",
  "website": "website if available",
  "specialties": ["specialty1", "specialty2"],
  "atmosphere": "atmosphere description",
  "estimatedCost": "cost estimate",
  "recommendedTime": "best time to visit",
  "personalityMatch": "why this matches [personalityType] personality"
}

Ensure all locations are real and within the specified radius. Return only the JSON array.
```

**Category-Specific Instructions:**

- **Recommended:** "Focus on highly-rated, personality-matched activities based on [personalityType] personality type."
- **Near Me:** "Prioritize proximity and quality. Include the closest high-quality options."
- **Dining:** "Include restaurants, cafes, and unique food experiences. Consider cuisine variety and ambiance."
- **Outdoor:** "Focus on parks, hiking trails, and outdoor activities suitable for couples."
- **Cultural:** "Include museums, galleries, theaters, and enriching cultural experiences."
- **Active:** "Focus on fitness activities, sports, and active pursuits suitable for couples."
- **Drinks:** "Include bars, cafes, and beverage-focused venues with great atmospheres."

**Drink-Specific Prompts:**

- **Coffee:** "coffee shops, specialty coffee roasters, cozy cafes with artisan coffee"
- **Tea:** "tea houses, bubble tea shops, specialty tea cafes with traditional and modern tea experiences"
- **Alcohol:** "bars, restaurants with excellent drink menus, cocktail lounges, mix of dining and drinking establishments"
- **Non-Alcohol:** "juice bars, smoothie shops, cafes with creative non-alcoholic beverages"
- **Boba:** "bubble tea shops, boba cafes, Asian tea houses with authentic boba experiences"
- **Other:** "unique beverage spots, specialty drink establishments, innovative beverage experiences"

### OpenAI GPT-4o - Secondary Engine

**Model:** `gpt-4o`
**Temperature:** 0.7
**Max Tokens:** 1500
**Response Format:** JSON object

**Used as fallback when:**
- Grok AI API key unavailable
- Grok AI request fails
- Alternative recommendation source needed

---

## Data Flow

### Complete Recommendation Flow

```
┌────────────────────────────────────────────────────────────┐
│ 1. USER INTERACTION                                        │
├────────────────────────────────────────────────────────────┤
│ - Select category (e.g., "Dining")                        │
│ - Adjust radius slider (e.g., 25 miles)                   │
│ - Click "Get Recommendations"                             │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 2. FRONTEND DATA COLLECTION                                │
├────────────────────────────────────────────────────────────┤
│ - Get userId from localStorage                            │
│ - Get user location (lat/lng)                             │
│ - Get current radius value                                │
│ - Get active category                                     │
│ - Fetch user profile (preferences, personality)           │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 3. API REQUEST                                             │
├────────────────────────────────────────────────────────────┤
│ POST /api/recommendations/location-based                  │
│ {                                                          │
│   userId: 4,                                              │
│   location: { latitude: 40.7128, longitude: -74.0060 },  │
│   radius: 25,                                             │
│   category: "dining",                                     │
│   preferences: {...},                                     │
│   personalityType: "The Adventurer",                      │
│   resetAlgorithm: false                                   │
│ }                                                          │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 4. BACKEND PROCESSING                                      │
├────────────────────────────────────────────────────────────┤
│ - Validate request parameters                             │
│ - Check generation limits                                 │
│ - Build category-specific prompt                          │
│ - Call Grok AI API                                        │
│ - Parse JSON response                                     │
│ - Sort by local priority + rating                        │
│ - Update generation counters                              │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 5. AI PROCESSING (Grok)                                    │
├────────────────────────────────────────────────────────────┤
│ - Analyze location coordinates                            │
│ - Search real establishments within radius                │
│ - Match to personality type                               │
│ - Consider user preferences                               │
│ - Generate 3 recommendations                              │
│ - Format as JSON array                                    │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 6. API RESPONSE                                            │
├────────────────────────────────────────────────────────────┤
│ {                                                          │
│   success: true,                                          │
│   recommendations: [                                       │
│     {                                                      │
│       id: "rec_1",                                        │
│       name: "La Bella Cucina",                           │
│       description: "Authentic Italian...",               │
│       category: "dining",                                │
│       rating: 4.8,                                       │
│       distance: 1.2,                                     │
│       price: "$30-50 per person",                        │
│       address: "123 Main St, New York, NY",             │
│       specialties: ["Pasta", "Wine"],                   │
│       ...                                                 │
│     },                                                     │
│     ...                                                    │
│   ],                                                       │
│   canGenerateMore: true,                                  │
│   generationsRemaining: 2                                 │
│ }                                                          │
└───────────────────────┬────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 7. FRONTEND DISPLAY                                        │
├────────────────────────────────────────────────────────────┤
│ - Update recommendations state                            │
│ - Update generation tracking                              │
│ - Render activity cards                                   │
│ - Show "Generate More" button if available               │
│ - Display success toast notification                      │
└────────────────────────────────────────────────────────────┘
```

### Scheduling Flow

```
┌────────────────────────────────────────────────────────────┐
│ 1. USER CLICKS "SCHEDULE" ON ACTIVITY CARD                │
└───────────────────────┬────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 2. OPEN SCHEDULING MODAL                                   │
│ - Pre-fill activity name                                  │
│ - Show activity details                                   │
│ - Display date/time pickers                               │
└───────────────────────┬────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 3. USER FILLS SCHEDULING DATA                             │
│ - Select date (calendar picker)                           │
│ - Select time (time picker)                               │
│ - Optional: Add notes                                     │
└───────────────────────┬────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 4. SUBMIT EVENT                                            │
│ POST /api/events                                          │
│ {                                                          │
│   userId: 4,                                              │
│   title: "La Bella Cucina",                              │
│   description: "Authentic Italian dinner date...",        │
│   location: "123 Main St, New York, NY",                 │
│   startTime: "2025-10-25T19:00:00Z",                     │
│   endTime: "2025-10-25T21:00:00Z",                       │
│   eventType: "date",                                      │
│   allDay: false                                           │
│ }                                                          │
└───────────────────────┬────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 5. BACKEND PROCESSING                                      │
│ - Validate event data                                     │
│ - Create event in database                                │
│ - Increment user's eventsCreated counter                 │
│ - Return event confirmation                               │
└───────────────────────┬────────────────────────────────────┘
                        ▼
┌────────────────────────────────────────────────────────────┐
│ 6. FRONTEND UPDATE                                         │
│ - Close modal                                             │
│ - Clear scheduling form                                   │
│ - Invalidate calendar queries                            │
│ - Invalidate user stats queries                          │
│ - Show success toast                                      │
│ - Event appears in Calendar tab                          │
└────────────────────────────────────────────────────────────┘
```

---

## API Endpoints

### GET /api/user/profile

**Purpose:** Fetch user profile including preferences and personality data

**Query Parameters:**
- `userId` (string, required) - User ID

**Response:**
```typescript
{
  id: number,
  name: string,
  email: string,
  partnerName: string,
  relationshipDuration: string,
  personalityType: string,
  personalityInsight: string,
  preferences: {
    // User preference responses
    diningPreferences: string[],
    outdoorActivities: string[],
    culturalInterests: string[],
    drinkPreferences: string[],
    // ... more preferences
  },
  location: {
    latitude: number,
    longitude: number
  }
}
```

**Status Codes:**
- 200: Success
- 400: Invalid user ID
- 404: User not found
- 500: Server error

---

### POST /api/recommendations/location-based

**Purpose:** Generate location-based activity recommendations using Grok AI

**Request Body:**
```typescript
{
  userId: number,              // Required
  location: {                  // Required
    latitude: number,
    longitude: number
  },
  radius: number,              // Required (in miles)
  category: string,            // Required (recommended|near_me|dining|outdoor|cultural|active|drinks)
  preferences: object,         // User preferences object
  personalityType: string,     // User's personality type
  resetAlgorithm: boolean     // Reset generation count
}
```

**Response:**
```typescript
{
  success: boolean,
  recommendations: ActivityRecommendation[],
  canGenerateMore: boolean,
  generationsRemaining: number,
  category: string,
  radius: number
}
```

**ActivityRecommendation Structure:**
```typescript
{
  id: string,
  name: string,
  description: string,
  category: string,
  rating: number,              // 0-5 scale
  distance: number,            // Miles from user location
  price: string,               // e.g., "$20-40 per person"
  address: string,
  phone?: string,
  website?: string,
  specialties?: string[],
  atmosphere?: string,
  estimatedCost: string,
  recommendedTime: string,     // e.g., "Evening", "Afternoon"
  personalityMatch: string     // Why it matches user's personality
}
```

**Status Codes:**
- 200: Success
- 400: Missing required parameters
- 500: Server error (returns fallback recommendations)

---

### POST /api/recommendations/drinks

**Purpose:** Generate drink-specific venue recommendations using Grok AI

**Request Body:**
```typescript
{
  userId: number,                    // Required
  location: {                        // Required
    latitude: number,
    longitude: number
  },
  radius: number,                    // Required (in miles)
  drinkPreferences: string[],        // Required (coffee|tea|alcohol|non_alcohol|boba|other)
  personalityType: string,           // User's personality type
  resetAlgorithm: boolean           // Reset generation count
}
```

**Response:**
```typescript
{
  success: boolean,
  recommendations: {
    [drinkType: string]: ActivityRecommendation[]  // Max 3 per type
  },
  canGenerateMore: boolean,
  generationsRemaining: number
}
```

**Example Response:**
```json
{
  "success": true,
  "recommendations": {
    "coffee": [
      { "id": "coffee_1", "name": "Blue Bottle Coffee", ... },
      { "id": "coffee_2", "name": "Stumptown Roasters", ... }
    ],
    "tea": [
      { "id": "tea_1", "name": "Cha Cha Matcha", ... }
    ]
  },
  "canGenerateMore": true,
  "generationsRemaining": 1
}
```

**Status Codes:**
- 200: Success
- 400: Missing required parameters
- 500: Server error (returns fallback recommendations)

---

### POST /api/recommendations/ai-powered

**Purpose:** Generate AI-powered recommendations using OpenAI (alternative/fallback)

**Request Body:**
```typescript
{
  userId: number,          // Required
  category: string,        // Activity category
  location: {              // Optional (uses user's saved location if not provided)
    latitude: number,
    longitude: number
  },
  preferences: object      // Optional (uses user's saved preferences if not provided)
}
```

**Response:**
```typescript
{
  success: boolean,
  recommendations: ActivityRecommendation[],
  message: string
}
```

**Status Codes:**
- 200: Success
- 400: Missing user ID
- 404: User not found
- 500: Server error

---

### POST /api/events

**Purpose:** Create a new calendar event from scheduled activity

**Request Body:**
```typescript
{
  userId: number,          // Required
  title: string,           // Required - Activity name
  description: string,     // Required - Full activity details
  location: string,        // Required - Activity address
  startTime: string,       // Required - ISO 8601 datetime
  endTime: string,         // Required - ISO 8601 datetime
  eventType: string,       // Required - "date" | "activity" | "special"
  allDay: boolean         // Required - false for specific times
}
```

**Response:**
```typescript
{
  id: number,
  userId: number,
  title: string,
  description: string,
  location: string,
  startTime: string,
  endTime: string,
  eventType: string,
  allDay: boolean,
  createdAt: string
}
```

**Side Effects:**
- Increments user's `eventsCreated` counter in user_stats table
- Invalidates TanStack Query cache for:
  - `/api/events/user/${userId}`
  - `/api/user/stats/${userId}`

**Status Codes:**
- 200: Success
- 400: Invalid event data
- 500: Server error

---

### GET /api/recommendations/categories

**Purpose:** Fetch available activity and drink categories

**Response:**
```typescript
{
  success: boolean,
  categories: [
    { id: "recommended", label: "Recommended", icon: "⭐", color: "blue" },
    { id: "near_me", label: "Near Me", icon: "📍", color: "green" },
    { id: "dining", label: "Dining", icon: "🍽️", color: "orange" },
    { id: "outdoor", label: "Outdoor", icon: "🌳", color: "emerald" },
    { id: "cultural", label: "Cultural", icon: "🎭", color: "purple" },
    { id: "active", label: "Active", icon: "⚡", color: "red" },
    { id: "drinks", label: "Drinks", icon: "🍹", color: "amber" }
  ],
  drinkPreferences: [
    { id: "coffee", label: "Coffee", icon: "☕" },
    { id: "tea", label: "Tea", icon: "🍵" },
    { id: "alcohol", label: "Alcohol", icon: "🍷" },
    { id: "non_alcohol", label: "Non-Alcohol", icon: "🥤" },
    { id: "boba", label: "Boba", icon: "🧋" },
    { id: "other", label: "Other", icon: "🥛" }
  ]
}
```

**Status Codes:**
- 200: Success
- 500: Server error

---

## User Preferences System

### Preference Collection Flow

**File:** `client/src/pages/preferences.tsx`

**Multi-Step Questionnaire:**

Users answer questions covering:
1. **Dining Preferences** - Cuisine types, dining atmosphere
2. **Outdoor Activities** - Nature activities, adventure level
3. **Entertainment** - Movie types, music genres
4. **Cultural Interests** - Art, museums, performances
5. **Active Pursuits** - Fitness level, sports preferences
6. **Creative Activities** - Artistic interests
7. **Drink Preferences** - Beverage types (multi-select)
8. **Budget Preferences** - Spending comfort level
9. **Time Preferences** - Best times for dates

**Question Types:**

1. **Multiple Choice** - Single selection from options
2. **Multi-Select** - Select all that apply (checkboxes)
3. **Scale** - Slider (0-10 rating)
4. **Boolean** - Yes/No toggle

**Example Preference Questions:**

```typescript
{
  id: "drink_preferences",
  question: "What drinks do you enjoy? (Select all that apply)",
  type: "multi-select",
  options: [
    { value: "coffee", label: "Coffee" },
    { value: "tea", label: "Tea" },
    { value: "alcohol", label: "Alcoholic beverages" },
    { value: "non_alcohol", label: "Non-alcoholic beverages" },
    { value: "boba", label: "Boba/Bubble tea" },
    { value: "other", label: "Other specialty drinks" }
  ]
}
```

### Preference Storage

**For Authenticated Users:**
- POST to `/api/user/preferences`
- Stored in PostgreSQL `users` table
- Saved in `preferences` JSONB column
- Also cached in localStorage for quick access

**For Guest Users:**
- Stored only in localStorage
- Key: `guestAssessmentResults`
- Transferred to user account upon registration

**Preference Data Structure:**
```typescript
{
  diningPreferences: ["italian", "japanese", "mexican"],
  outdoorActivities: ["hiking", "picnics"],
  culturalInterests: ["museums", "theater"],
  drinkPreferences: ["coffee", "wine", "cocktails"],
  budgetLevel: 7,                    // Scale 0-10
  adventureLevel: 8,                 // Scale 0-10
  activeLevel: 6,                    // Scale 0-10
  preferredTimes: ["evening", "weekend"]
}
```

### Preference Usage

Preferences are used to:
1. **Tailor AI prompts** - Include preference context in Grok/OpenAI requests
2. **Filter recommendations** - Match activities to stated preferences
3. **Rank results** - Boost recommendations aligned with preferences
4. **Generate drink lists** - Show drink categories user selected
5. **Personalize descriptions** - Highlight aspects user cares about

**Example AI Prompt Integration:**
```
User preferences: 
- Dining: Italian, Japanese
- Outdoor: Hiking, Nature walks
- Budget: Moderate ($30-60 per date)
- Drinks: Coffee, Wine

[Generate recommendations that align with these preferences...]
```

---

## Location Services

### Geolocation Detection

**Browser Geolocation API:**
```typescript
navigator.geolocation.getCurrentPosition(
  successCallback,
  errorCallback,
  {
    enableHighAccuracy: true,  // Use GPS if available
    timeout: 10000,            // 10 second timeout
    maximumAge: 300000         // Cache for 5 minutes
  }
);
```

**Permission States:**
- `granted` - Location detected successfully
- `denied` - User denied permission
- `prompt` - Permission not yet requested

**Error Handling:**
- Permission denied → Show manual location entry option
- Timeout → Retry with lower accuracy
- Position unavailable → Use IP-based fallback
- Show user-friendly error toasts for all failures

### Reverse Geocoding

**Service:** BigDataCloud Reverse Geocoding API
**Endpoint:** `https://api.bigdatacloud.net/data/reverse-geocode-client`

**Request:**
```
GET /data/reverse-geocode-client?latitude=40.7128&longitude=-74.0060&localityLanguage=en
```

**Response:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "city": "New York",
  "principalSubdivision": "New York",
  "locality": "Manhattan",
  "countryName": "United States",
  ...
}
```

**Display Logic:**
```typescript
if (data.city && data.principalSubdivision) {
  return `${data.city}, ${data.principalSubdivision}`;  // "New York, New York"
} else if (data.locality && data.principalSubdivision) {
  return `${data.locality}, ${data.principalSubdivision}`;  // "Manhattan, New York"
} else if (data.principalSubdivision) {
  return data.principalSubdivision;  // "New York"
} else {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;  // "40.7128, -74.0060"
}
```

**Advantages:**
- Free API (no key required)
- Client-side only (no server load)
- Fast response times
- Accurate city/state data
- Privacy-friendly

---

## Scheduling System

### Event Creation

**Triggered by:** "Schedule" button on activity cards

**Modal Form Fields:**
1. **Date** (required) - Calendar date picker
2. **Time** (required) - 24-hour time selector
3. **Notes** (optional) - Textarea for custom notes

**Event Processing:**
```typescript
// Combine date + time into startTime
const startDateTime = new Date(`${date}T${time}`);

// Add 2 hours for default endTime
const endDateTime = new Date(startDateTime.getTime() + 2 * 60 * 60 * 1000);

// Build description from activity details
const description = `
${activity.description}

Location: ${activity.address}
Estimated Cost: ${activity.estimatedCost}
Recommended Time: ${activity.recommendedTime}
${notes ? `\n\nNotes: ${notes}` : ''}
`;

// Create event object
const eventData = {
  userId: parseInt(userId),
  title: activity.name,
  description,
  location: activity.address,
  startTime: startDateTime.toISOString(),
  endTime: endDateTime.toISOString(),
  eventType: 'date',
  allDay: false
};
```

### Calendar Integration

**Event Storage:**
- Events stored in `calendar_events` table
- Linked to user via `userId` foreign key
- Includes all activity details in description
- Preserves location for map integration

**Event Appearance:**
- Shows in Calendar tab immediately after creation
- Listed in chronological order
- Color-coded by event type
- Shows date, time, and location preview

**Statistics Tracking:**
- Each event creation increments `user_stats.eventsCreated`
- Displayed on Dashboard
- Used for engagement analytics

### Query Invalidation

**After Event Creation:**
```typescript
queryClient.invalidateQueries({ 
  queryKey: ["/api/events/user", userId] 
});

queryClient.invalidateQueries({ 
  queryKey: ["/api/user/stats", userId] 
});
```

**Effect:**
- Calendar tab automatically refetches events
- Dashboard statistics update immediately
- User sees new event count without refresh

---

## UI/UX Design

### Mobile-First Approach

**Responsive Breakpoints:**
- Mobile: < 640px (sm)
- Tablet: 640px - 1024px
- Desktop: > 1024px

**Mobile Optimizations:**
- Touch-friendly buttons (min 44x44px)
- Horizontal scrolling for categories
- Collapsible card details (reduce screen space)
- Bottom sheet modal for scheduling
- Sticky header for location info
- Large tap targets for radius slider

### Design System

**Color Scheme:**
- Primary: Blue gradient (#0070F3 → #1FB6FF)
- Success: Green (#10B981)
- Warning: Yellow (#F59E0B)
- Danger: Red (#EF4444)
- Category-specific colors (see Features section)

**Typography:**
- Headings: font-semibold, text-lg/xl
- Body: font-normal, text-sm/base
- Labels: font-medium, text-xs/sm
- Descriptions: text-muted-foreground

**Spacing:**
- Card padding: p-4 to p-5
- Section margins: mb-4 to mb-6
- Element gaps: space-x-2, space-y-3
- Container padding: p-6, pb-24 (accounts for bottom nav)

### Glass Effect Styling

**Used Throughout:**
```css
.glass-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 1rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}
```

**Applied To:**
- Location status card
- Activity recommendation cards
- Category buttons (when active)
- Modal backgrounds

### Animation & Transitions

**Card Expansion:**
```css
.animate-in {
  animation: slideIn 200ms ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

**Hover Effects:**
- Cards: `hover:shadow-xl transition-all duration-300`
- Buttons: `hover:bg-secondary transition-colors`
- Icons: `hover:text-primary transition-colors`

**Loading States:**
- Spinner icon rotation: `animate-spin`
- Button disabled state: `disabled:opacity-50 disabled:cursor-not-allowed`
- Skeleton placeholders during data fetch

### Accessibility

**ARIA Labels:**
- All interactive elements have descriptive labels
- Icons paired with text labels
- Loading states announced to screen readers

**Keyboard Navigation:**
- All buttons focusable via Tab
- Enter/Space to activate
- Escape to close modals
- Focus rings visible (ring-2 ring-primary)

**Color Contrast:**
- All text meets WCAG AA standards (4.5:1 minimum)
- Icon colors tested for visibility
- Disabled states clearly indicated

### Error States

**Network Errors:**
- Toast notification with error message
- "Try again" button for manual retry
- Fallback recommendations if AI fails

**Location Errors:**
- Permission denied message with manual entry option
- Timeout errors with retry button
- Clear error messaging in UI

**Empty States:**
- "No recommendations yet" message
- Call-to-action to generate recommendations
- Helpful hint text

---

## Technical Specifications

### Data Types

**TypeScript Interfaces:**

```typescript
interface ActivityRecommendation {
  id: string;
  name: string;
  description: string;
  category: string;
  rating: number;
  distance: number;
  price: string;
  address: string;
  phone?: string;
  website?: string;
  specialties?: string[];
  atmosphere?: string;
  estimatedCost: string;
  recommendedTime: string;
  personalityMatch: string;
}

interface Location {
  latitude: number;
  longitude: number;
}

interface SchedulingData {
  date: string;      // YYYY-MM-DD format
  time: string;      // HH:MM format (24-hour)
  notes: string;
}

interface RecommendationResponse {
  success: boolean;
  recommendations: ActivityRecommendation[] | Record<string, ActivityRecommendation[]>;
  canGenerateMore: boolean;
  generationsRemaining: number;
  category?: string;
  radius?: number;
  error?: string;
}
```

### Database Schema

**Users Table:**
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  partner_name VARCHAR(255),
  relationship_duration VARCHAR(100),
  personality_type VARCHAR(100),
  personality_insight TEXT,
  preferences JSONB,              -- Stores all user preferences
  location JSONB,                 -- {latitude: number, longitude: number}
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Calendar Events Table:**
```sql
CREATE TABLE calendar_events (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  location VARCHAR(500),
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL,
  event_type VARCHAR(50) DEFAULT 'date',  -- date|activity|special
  all_day BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**User Stats Table:**
```sql
CREATE TABLE user_stats (
  id SERIAL PRIMARY KEY,
  user_id INTEGER UNIQUE REFERENCES users(id),
  events_created INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Environment Variables

**Required:**
```bash
# Database
DATABASE_URL=postgresql://user:password@host:port/database

# AI Services
XAI_API_KEY=xai-xxxxxxxxxxxxx          # Grok AI (primary)
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx     # OpenAI (fallback)

# Server
NODE_ENV=development
PORT=5000
```

**Optional:**
```bash
# Feature Flags
ENABLE_OPENAI_FALLBACK=true
MAX_GENERATIONS_PER_CATEGORY=3
DEFAULT_RADIUS_MILES=25
```

### Performance Optimizations

**Frontend:**
- TanStack Query caching (5-minute stale time)
- Debounced radius slider (300ms)
- Lazy loading of recommendation cards
- Memoized category filtering
- localStorage for location caching

**Backend:**
- Connection pooling for database
- Rate limiting on AI API calls
- Response compression (gzip)
- Efficient JSON parsing
- Database query optimization (indexed columns)

**AI Requests:**
- Batched drink recommendations (single API call per preference set)
- Cached user profile data (reduces database queries)
- Generation limits (prevent API abuse)
- Timeout handling (10-second max)
- Fallback recommendations (no API failure)

### Error Handling

**Frontend Error Boundaries:**
```typescript
try {
  // API call
} catch (error) {
  console.error("Error:", error);
  toast({
    title: "Operation failed",
    description: error.message || "Please try again",
    variant: "destructive"
  });
}
```

**Backend Error Responses:**
```typescript
try {
  // Processing
} catch (error) {
  console.error("Backend error:", error);
  res.status(500).json({
    success: false,
    error: error.message,
    fallback: getFallbackRecommendations()  // Provide fallback when possible
  });
}
```

### Testing Considerations

**Unit Tests:**
- AI prompt generation
- Location sorting algorithm
- Generation limit tracking
- Date/time formatting
- Error handling

**Integration Tests:**
- API endpoint responses
- Database operations
- AI service calls (mocked)
- Event creation flow

**E2E Tests:**
- Complete recommendation flow
- Scheduling flow
- Category switching
- Location detection
- Error recovery

---

## Future Enhancements

**Planned Features:**
1. **Favorites System** - Save favorite recommendations
2. **Recommendation History** - View past suggestions
3. **Shared Lists** - Collaborate on activity selection with partner
4. **Budget Tracking** - Track total spent on dates
5. **Weather Integration** - Show weather for outdoor activities
6. **Real-time Availability** - Check venue hours and availability
7. **Photo Integration** - Display venue photos
8. **Review Integration** - Fetch real user reviews
9. **Map View** - Visual map of recommendations
10. **Route Planning** - Navigate to selected venue

**Technical Improvements:**
1. **Caching Layer** - Redis for AI response caching
2. **Background Jobs** - Pre-generate recommendations
3. **Analytics** - Track recommendation effectiveness
4. **A/B Testing** - Test different AI prompts
5. **Push Notifications** - Remind about scheduled dates
6. **Progressive Web App** - Offline functionality
7. **Image Optimization** - Lazy loading, compression
8. **Performance Monitoring** - Real-time error tracking

---

## Conclusion

The Activities Tab represents a comprehensive, AI-powered dating recommendation system that combines:
- **Advanced AI** (Grok & OpenAI)
- **Real-time geolocation**
- **Personality-based matching**
- **User preference learning**
- **Seamless event scheduling**
- **Mobile-first design**
- **Robust error handling**

It delivers personalized, actionable date ideas that strengthen relationships through thoughtful, AI-curated experiences tailored to each couple's unique dynamic.
