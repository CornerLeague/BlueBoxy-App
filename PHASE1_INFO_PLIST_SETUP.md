# Phase 1 - Info.plist Configuration

## Required Location Permission Keys

To enable location services in the BlueBoxy app, you need to add the following keys to your `Info.plist` file:

### Method 1: Using Xcode (Recommended)

1. Open `BlueBoxy.xcodeproj` in Xcode
2. Select the BlueBoxy target
3. Go to the "Info" tab
4. Click the "+" button to add new entries
5. Add the following keys:

**NSLocationWhenInUseUsageDescription**
```
Value: BlueBoxy needs access to your location to provide personalized activity and date recommendations near you.
```

**NSLocationAlwaysAndWhenInUseUsageDescription** (Optional - for background location)
```
Value: BlueBoxy uses your location to suggest activities and dates nearby, even when the app is in the background.
```

### Method 2: Direct XML Edit

If you prefer to edit the Info.plist file directly, add these entries:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>BlueBoxy needs access to your location to provide personalized activity and date recommendations near you.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>BlueBoxy uses your location to suggest activities and dates nearby, even when the app is in the background.</string>
```

### Location Services Configuration

The LocationService.swift implementation uses:
- **When In Use Authorization**: Requested when the Activities tab is opened
- **High Accuracy Mode**: `kCLLocationAccuracyBest` for precise recommendations
- **Timeout**: 10 seconds
- **Caching**: 5 minutes to reduce battery usage

### Privacy Requirements

According to Apple's App Store guidelines:
1. **Purpose String**: Must clearly explain why location access is needed
2. **User Control**: Users can deny permission and the app should handle this gracefully
3. **Minimal Usage**: Only request location when needed (Activities tab)
4. **Transparency**: Show location status in UI (LocationHeaderView)

### Testing Location Permissions

**Simulator:**
1. Open Simulator
2. Features → Location → Custom Location
3. Enter coordinates or use presets (Apple, City Run, etc.)

**Device:**
1. Settings → Privacy & Security → Location Services
2. Find "BlueBoxy"
3. Change permission level to test different states

### Location Permission States

The app handles three permission states:

1. **Not Determined** (Initial)
   - Shows request permission UI
   - Icon: Gray location icon
   - User can grant or deny

2. **Granted** (Authorized When In Use)
   - Shows current location name
   - Icon: Blue filled location icon
   - Updates automatically

3. **Denied** (Permission Denied)
   - Shows error message
   - Icon: Red location slash icon
   - Button to open Settings

### Implementation Status

✅ **Completed:**
- LocationService.swift with Core Location integration
- LocationHeaderView.swift with permission handling
- Integration with ActivitiesView
- Permission status indicators
- Error handling and fallbacks

📋 **Next Steps:**
- Add Info.plist keys in Xcode
- Test on simulator/device
- Verify permission flow
- Test location caching

### Troubleshooting

**Location Not Detecting:**
1. Check Info.plist keys are present
2. Verify location services enabled on device
3. Check console for location errors
4. Ensure network connectivity (for reverse geocoding)

**Permission Dialog Not Showing:**
1. Uninstall and reinstall app
2. Reset location & privacy (Settings → General → Reset)
3. Check authorization status in code

**Geocoding Failing:**
1. Verify internet connection
2. Check BigDataCloud API availability
3. Fallback to coordinate display works

### Additional Resources

- [Apple Location Services Documentation](https://developer.apple.com/documentation/corelocation)
- [Core Location Best Practices](https://developer.apple.com/documentation/corelocation/choosing_the_location_services_authorization_to_request)
- [Privacy Best Practices](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
