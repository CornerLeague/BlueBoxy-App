# OpenAI Geolocation-Based Activity Search Integration

## Overview

BlueBoxy now uses **OpenAI API** instead of Grok AI for generating personalized activity suggestions with **geolocation support**. This provides more accurate, location-aware recommendations for couples.

## Key Features

- ✅ **Geolocation Integration**: Uses device coordinates and city information to generate location-specific recommendations
- ✅ **Personality-Based Matching**: Considers personality types, love languages, and communication styles
- ✅ **Rich Activity Details**: Provides cost estimates, duration, best time of day, and practical tips
- ✅ **Error Handling**: Graceful fallback to curated activities if API fails
- ✅ **Caching**: 30-minute cache for AI-generated recommendations
- ✅ **Timeout Protection**: 30-second timeout prevents hanging requests

## Architecture

### New Files Created

1. **`OpenAIActivityService.swift`** - Main service for OpenAI integration
   - Handles geolocation-based activity search
   - Manages API requests and responses
   - Includes error handling and retry logic

### Modified Files

1. **`EnhancedActivitiesViewModel.swift`**
   - Updated to use `OpenAIActivityService` instead of `GrokAIService`
   - New method: `loadActivitiesFromOpenAI()`
   - Passes geolocation data to OpenAI prompts

2. **`Environment.swift`**
   - Updated `OpenAIConfig` with proper API key configuration
   - Supports environment variables and keychain storage

## Setup Instructions

### 1. Get OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/account/api-keys)
2. Create a new API key or use existing one
3. Ensure you have credits or a paid subscription

### 2. Set API Key (Development)

**Option A: Environment Variable (Recommended)**
```bash
export OPENAI_API_KEY='sk-your-actual-key-here'
```

**Option B: Xcode Scheme**
1. Product → Scheme → Edit Scheme
2. Run → Pre-actions
3. Add environment variable:
   ```
   OPENAI_API_KEY=sk-your-actual-key-here
   ```

**Option C: Keychain (Production)**
```swift
KeychainHelper.shared.save(service: "BlueBoxy", account: "openai_api_key", data: "sk-your-key")
```

### 3. Test the Integration

Run the test script:
```bash
cd /Users/newmac/Desktop/BlueBoxy
export OPENAI_API_KEY='sk-your-actual-key-here'
swift test_openai_activities.swift
```

## How It Works

### User Flow

1. User taps "Generate AI Activities" button in Activities tab
2. System gathers:
   - User's current geolocation (latitude/longitude)
   - City name
   - User's personality type
   - Ideal activities preferences
   - Relationship duration
   - Current time of day and season

3. OpenAI generates location-specific recommendations:
   - 3-5 activity recommendations
   - Specific venues/locations in the given area
   - Personality match scores
   - Cost estimates, duration, best times
   - Actionable tips

4. Results are:
   - Cached for 30 minutes
   - Displayed with personality matching
   - Available for bookmarking

### Geolocation Data Flow

```
User Location (CLLocationCoordinate2D)
    ↓
GeolocationActivityCriteria
    ├── latitude/longitude
    ├── city name
    ├── search radius (25 miles)
    └── personality/preferences
    ↓
OpenAI Prompt (includes coordinates and location info)
    ↓
OpenAI API Response
    ↓
Activity Objects with coordinates stored
```

## API Response Format

OpenAI returns a structured JSON response:

```json
{
  "recommendations": [
    {
      "name": "Activity Name",
      "description": "Detailed description",
      "category": "romantic",
      "location": "Specific venue address",
      "estimated_cost": "$50-75",
      "duration": "2-3 hours",
      "best_time_of_day": "evening",
      "personality_match": "Perfect for quality time",
      "why_recommended": "Reason based on profile",
      "tips": ["Tip 1", "Tip 2"],
      "alternatives": ["Alternative 1", "Alternative 2"]
    }
  ],
  "search_context": "Context about search",
  "personality_insights": "Personality-based insights",
  "location_notes": "Location-specific information"
}
```

## Configuration Options

### Model Selection

In `OpenAIActivityService.swift`:
```swift
// Better quality, more expensive
private let defaultModel = "gpt-4"

// Faster, cheaper
// private let defaultModel = "gpt-3.5-turbo"
```

### Timeout Settings

```swift
private let timeout: TimeInterval = 30 // seconds
```

### Cache Duration

In `EnhancedActivitiesViewModel.swift`:
```swift
strategy: .hybrid(expiration: 1800) // 30 minutes
```

## Error Handling

The service gracefully handles:

| Error | Behavior |
|-------|----------|
| **Invalid API Key** | Falls back to curated activities, shows error message |
| **Network Timeout** | Retries up to 2 times with exponential backoff |
| **Rate Limit (429)** | Fails gracefully, displays retry suggestion |
| **Invalid JSON Response** | Falls back to mock data |
| **No Coordinates** | Uses city name instead |

## Troubleshooting

### "Invalid API key" Error
- Check your API key is set: `echo $OPENAI_API_KEY`
- Verify key starts with `sk-`
- Ensure no extra whitespace
- Test key on [OpenAI platform](https://platform.openai.com)

### "Network timeout" Error
- Check internet connection
- Verify OpenAI API is accessible
- Try increasing timeout in code
- Check for rate limiting

### Empty Results
- Verify geolocation is enabled
- Check city name is correct
- Try different activity categories
- Check OpenAI API status page

### High Cost
- Switch to `gpt-3.5-turbo` model
- Reduce `max_tokens` value
- Increase cache duration

## API Costs

**GPT-4:**
- Input: $0.03 per 1K tokens
- Output: $0.06 per 1K tokens
- Typical call: ~500-800 tokens = ~$0.04-0.07 per request

**GPT-3.5-Turbo:**
- Input: $0.001 per 1K tokens
- Output: $0.002 per 1K tokens
- Typical call: ~500-800 tokens = ~$0.002-0.003 per request

*Prices subject to change. Check [OpenAI pricing](https://openai.com/pricing) for current rates.*

## Testing

### Unit Tests (to be added)
```swift
func testGeolocationActivityGeneration() async {
    let criteria = GeolocationActivityCriteria(
        location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        cityName: "San Francisco",
        radius: 25.0,
        idealActivities: ["dining", "cultural"]
    )
    
    let response = try await service.findActivities(criteria: criteria)
    XCTAssertGreaterThan(response.recommendations.count, 0)
}
```

### Integration Testing
1. Run `test_openai_activities.swift`
2. Check Activities tab UI
3. Verify geolocation is included in prompts
4. Test with different cities/coordinates

## Future Enhancements

- [ ] Add distance calculation from coordinates
- [ ] Store activity coordinates for map view
- [ ] Real-time geolocation updates during activity search
- [ ] Support for user-specified search radius
- [ ] Activity availability checking
- [ ] Real-time pricing validation
- [ ] Integration with mapping APIs
- [ ] User rating and review system

## Support & Documentation

- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Geolocation in iOS](https://developer.apple.com/documentation/corelocation)
- [Rate Limiting Guide](https://platform.openai.com/docs/guides/rate-limits)

## Migration from Grok AI

### Old Code (Grok)
```swift
let criteria = ActivitySearchCriteria(...)
let response = try await grokService.findActivities(criteria: criteria)
```

### New Code (OpenAI)
```swift
let criteria = GeolocationActivityCriteria(
    location: currentLocation, // NEW: CLLocationCoordinate2D
    cityName: userLocation?.city,
    // ... rest of criteria
)
let response = try await openAIService.findActivities(criteria: criteria)
```

## Changelog

### Version 1.0 (Current)
- ✅ Initial OpenAI integration
- ✅ Geolocation support
- ✅ Error handling and fallback
- ✅ 30-minute caching
- ✅ Timeout protection

### Planned
- [ ] v1.1: Distance calculation
- [ ] v1.2: Real-time availability
- [ ] v2.0: Multi-location support
