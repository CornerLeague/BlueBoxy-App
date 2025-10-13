# Unit Test Harness with JSON Fixtures - Phase 4 Implementation

## Overview
The BlueBoxy iOS app now includes a comprehensive unit test harness with JSON fixtures to validate model decoding and ensure build health.

## Test Target
- **Target Name**: `BlueBoxyTests`
- **Framework**: Swift Testing (modern Swift testing framework)
- **Location**: `/BlueBoxyTests/`

## JSON Fixtures

### Fixture Structure
```
BlueBoxyTests/Fixtures/
├── auth/
│   └── me_success.json
├── messages/
│   └── generate_success.json
├── activities/
│   └── list_success.json
├── events/
│   └── create_success.json
└── recommendations/
    └── ai_powered_success.json
```

### Fixture Sources
All fixtures are copied from the backend project's `docs/api-samples/` directory to ensure consistency with actual API responses.

## Test Infrastructure

### FixtureLoader Utility
**Location**: `BlueBoxyTests/FixtureLoader.swift`

```swift
final class FixtureLoader {
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T
}
```

**Features**:
- Generic type-safe JSON loading
- Automatic ISO8601 date decoding strategy
- Bundle-aware resource loading
- Comprehensive error handling

### Usage Example
```swift
// Load and decode a fixture
let authResponse: AuthEnvelope = try FixtureLoader.load("Fixtures/auth/me_success")
let activities: [Activity] = try FixtureLoader.load("Fixtures/activities/list_success")
```

## Models Added

### Activity Model
**Location**: `BlueBoxy/Core/Models/Activity.swift`

```swift
struct Activity: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let category: String
    let location: String?
    let rating: Double?
    let distance: String?
    let personalityMatch: String?
    let imageUrl: String?
}
```

### Event Model  
**Location**: `BlueBoxy/Core/Models/Event.swift`

```swift
struct Event: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    // ... additional fields for dates, metadata, etc.
}
```

### Recommendation Model
**Location**: `BlueBoxy/Core/Models/Recommendation.swift`

```swift
struct Recommendation: Decodable, Identifiable {
    let id: UUID // Generated locally
    let title: String
    let description: String
    let category: String
}
```

## Test Suites

### ModelDecodingTests
**Location**: `BlueBoxyTests/ModelDecodingTests.swift`

Smoke tests to validate model decoding:

- ✅ `testDecodeAuthMe()` - Validates AuthEnvelope decoding
- ✅ `testDecodeMessages()` - Validates MessageGenerationResponse decoding  
- ✅ `testDecodeActivities()` - Validates Activity array decoding
- ✅ `testDecodeEvents()` - Validates Event decoding
- ✅ `testDecodeRecommendations()` - Validates Recommendation array decoding

### FixtureLoaderTests
**Location**: `BlueBoxyTests/FixtureLoaderTests.swift`

Infrastructure validation tests:

- ✅ `testFixtureLoaderCanLoadJSON()` - Basic loading functionality
- ✅ `testAllRequiredFixturesExist()` - Fixture file presence validation
- ✅ `testFixtureLoaderHandlesDecodingErrors()` - Error handling validation

## Benefits

### Build Health Monitoring
- **Continuous Validation**: Tests run on every build to catch breaking changes
- **Model Consistency**: Ensures iOS models stay in sync with backend API responses
- **Regression Prevention**: Catches decoding issues before they reach production

### Development Velocity
- **Fast Feedback**: Unit tests run quickly compared to integration tests
- **Isolated Testing**: Test model logic without network dependencies
- **Debug Support**: Easy to reproduce and debug model-related issues

### API Contract Validation
- **Real Data**: Uses actual API response samples from backend documentation
- **Type Safety**: Compile-time validation of model field types and names
- **Future Proofing**: Easy to add new fixtures as API evolves

## Running Tests

### Xcode
- **Keyboard**: `Cmd + U` to run all tests
- **Test Navigator**: Click ▶️ next to specific test suites or individual tests
- **Results**: View results in the Test Navigator or Report Navigator

### Command Line
```bash
# Run all tests
xcodebuild test -project BlueBoxy.xcodeproj -scheme BlueBoxy -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test suite  
xcodebuild test -project BlueBoxy.xcodeproj -scheme BlueBoxy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BlueBoxyTests/ModelDecodingTests
```

## Maintenance

### Adding New Fixtures
1. Copy JSON files from backend `docs/api-samples/`
2. Place in appropriate `BlueBoxyTests/Fixtures/` subdirectory
3. Create corresponding model if needed
4. Add test case to validate decoding

### Updating Existing Fixtures
1. Update JSON file with new API response format
2. Update corresponding model if schema changed
3. Update test assertions if validation criteria changed
4. Run tests to ensure compatibility

## Future Enhancements

- [ ] Add error response fixtures (4xx, 5xx)
- [ ] Add parameterized tests for different API variations
- [ ] Add mock API client using fixtures for integration testing
- [ ] Add performance benchmarks for model decoding
- [ ] Add automated fixture sync with backend API documentation