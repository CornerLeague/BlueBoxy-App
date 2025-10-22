# OpenAI Geolocation Activity Search - Quick Start Guide

## 🚀 5-Minute Setup

### 1. Get Your OpenAI API Key (2 minutes)
```bash
# Visit: https://platform.openai.com/account/api-keys
# Create a new API key and copy it
```

### 2. Set Environment Variable (1 minute)
```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
export OPENAI_API_KEY='sk-your-key-here'

# Reload shell
source ~/.zshrc
```

### 3. Verify Setup (2 minutes)
```bash
# Test the integration
cd /Users/newmac/Desktop/BlueBoxy
swift test_openai_activities.swift
```

Expected output:
```
🚀 OpenAI Activity Generation with Geolocation Test
...
✅ API Response received successfully!
✅ All tests completed!
```

## 📱 What Users See

### Before: Empty State
```
✨ Generate AI Activities
Get personalized activity recommendations powered by OpenAI AI 
based on your personality and preferences.

[Generate Activities]
```

### After: Geolocation-Aware Results
```
5 Activities

📍 Coordinates: 37.7749, -122.4194
🎯 Romantic dinner in SF with quality time focus

Activity 1: Sunset Dinner at Waterbar
Description: Waterfront dining with bay views...
Cost: $50-75 per person
Duration: 2-3 hours
Best time: Evening
Why: Perfect for intimate conversations

Activity 2: Art Gallery in SOMA...
```

## 🔧 Configuration

### Change AI Model (Cost vs Quality)

In `OpenAIActivityService.swift` line 151:

```swift
// Better quality (costs more)
private let defaultModel = "gpt-4"

// Cheaper & faster (lower quality)
private let defaultModel = "gpt-3.5-turbo"
```

### Adjust Timeout

In `OpenAIActivityService.swift` line 153:

```swift
private let timeout: TimeInterval = 30 // seconds
```

## 🧪 Testing Geolocation

### Test with Different Locations

Edit `test_openai_activities.swift` lines 20-23:

```swift
// San Francisco
let TEST_LATITUDE = 37.7749
let TEST_LONGITUDE = -122.4194
let TEST_CITY = "San Francisco"

// New York
// let TEST_LATITUDE = 40.7128
// let TEST_LONGITUDE = -74.0060
// let TEST_CITY = "New York"

// Los Angeles
// let TEST_LATITUDE = 34.0522
// let TEST_LONGITUDE = -118.2437
// let TEST_CITY = "Los Angeles"
```

## 📊 How Geolocation Works

```
User Location (GPS)
    ↓
Latitude: 37.7749, Longitude: -122.4194
    ↓
Passed to OpenAI Prompt
    ↓
"Please recommend activities in San Francisco (37.7749, -122.4194)"
    ↓
OpenAI generates location-specific recommendations
    ↓
Results show SF venues, landmarks, attractions
```

## ❌ Troubleshooting

### Issue: "Invalid API Key"
```bash
# Check if set
echo $OPENAI_API_KEY

# Should output: sk-...
# If empty, set it:
export OPENAI_API_KEY='sk-your-key-here'
```

### Issue: "Network timeout"
- Check internet connection
- Verify API key has credits
- Try again (built-in retry logic helps)

### Issue: "Empty results"
- Ensure geolocation is enabled
- Try different coordinates
- Check OpenAI API status: https://status.openai.com

### Issue: "High costs"
- Switch to `gpt-3.5-turbo` (10x cheaper)
- Increase cache duration in ViewModel
- Reduce max_tokens (line 179 in OpenAIActivityService)

## 📈 Expected Costs

**With GPT-4:** ~$0.04-0.07 per activity generation
**With GPT-3.5-Turbo:** ~$0.002-0.003 per activity generation

With 30-minute caching, most users spend:
- **Light user:** $0/month (cached results)
- **Active user:** $5-20/month (new generations)
- **Power user:** $50-100/month (frequent new searches)

## 🎯 Key Features Implemented

✅ **Geolocation Integration**
- Uses device latitude/longitude
- Includes city name in prompts
- Stores coordinates with activities

✅ **Personality Matching**
- Considers love language
- Accounts for communication style
- Matches ideal activities

✅ **Error Handling**
- Falls back to curated activities
- Retry logic with exponential backoff
- User-friendly error messages

✅ **Performance**
- 30-minute result caching
- 30-second request timeout
- Background fetching

## 🚀 Next Steps

1. ✅ Run `swift test_openai_activities.swift`
2. ✅ Open the app and tap "Generate Activities"
3. ✅ Verify you see location-specific recommendations
4. ✅ Test bookmarking and filtering

## 📚 Full Documentation

See `OPENAI_GEOLOCATION_INTEGRATION.md` for:
- Detailed architecture
- API response format
- Configuration options
- Advanced troubleshooting
- Future enhancements

## 💡 Pro Tips

**Tip 1: Save Costs**
```swift
// In EnhancedActivitiesViewModel.swift
strategy: .hybrid(expiration: 3600) // Increase to 1 hour
```

**Tip 2: Better Results**
Add more personality context:
```swift
"Their love language is quality time and they prefer intimate settings"
```

**Tip 3: Faster Response**
Use gpt-3.5-turbo and reduce tokens:
```swift
max_tokens: 1000 // down from 1500
```

## 🎓 Learn More

- [OpenAI API Docs](https://platform.openai.com/docs)
- [Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering)
- [iOS Geolocation](https://developer.apple.com/documentation/corelocation)

## Support

If you encounter issues:

1. Check `OPENAI_GEOLOCATION_INTEGRATION.md` 
2. Run the test script: `swift test_openai_activities.swift`
3. Review console logs in Xcode
4. Check [OpenAI Status](https://status.openai.com)

---

**Last Updated:** October 2025
**Version:** 1.0
