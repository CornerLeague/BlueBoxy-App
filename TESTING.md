# Testing Guide for BlueBoxy

This document covers the comprehensive testing infrastructure for the BlueBoxy iOS app, including unit tests, integration tests, and CI/CD configuration.

## Test Structure

The testing suite is organized into several categories:

### 1. Model Decoding Tests (`ModelDecodingTests.swift`)
- **Purpose**: Validate that all Swift models correctly decode from JSON fixtures
- **Coverage**: All API response models (User, Activity, Event, MessageGenerationResponse, etc.)
- **Fixtures**: Uses sample JSON files from `/BlueBoxyTests/Fixtures/`
- **Key Features**:
  - JSONValue handling validation
  - Date decoding verification  
  - Optional field handling
  - Performance benchmarking

### 2. API Client Tests (`APIClientTests.swift`) 
- **Purpose**: Test API client behavior with mock networking
- **Coverage**: Request construction, header injection, auth handling, error mapping
- **Mock System**: Uses `MockURLProtocol` to simulate network responses
- **Key Features**:
  - Authentication header validation
  - HTTP method and body verification
  - Error response mapping
  - Endpoint path construction

### 3. Live Integration Tests (`LiveIntegrationTests.swift`)
- **Purpose**: End-to-end testing against real backend (opt-in only)
- **Coverage**: Public endpoints, error handling, performance, connectivity
- **Safety**: Multiple safeguards to prevent accidental production testing
- **Key Features**:
  - Environment variable gating (`LIVE_API=1`)
  - URL validation for safe testing
  - Performance monitoring

## Running Tests

### Local Development

#### Unit Tests (Default)
```bash
# Run all tests
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  clean test

# Run specific test class
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:BlueBoxyTests/ModelDecodingTests \
  test

# Run with faster simulator (if available)
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=latest' \
  clean test
```

#### With Live API Integration Tests
```bash
# Set environment variable and run tests
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  test \
  LIVE_API=1

# Alternative: Set in Xcode scheme
# 1. Edit scheme > Test > Arguments > Environment Variables
# 2. Add LIVE_API = 1
# 3. Ensure your backend is running locally (npm run dev)
```

### Continuous Integration

#### GitHub Actions Example
```yaml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
        
    - name: Run Tests
      run: |
        xcodebuild -scheme BlueBoxy \
          -sdk iphonesimulator \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
          clean test \
          -resultBundlePath TestResults.xcresult
          
    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: TestResults.xcresult
```

#### Bitrise Configuration
```yaml
format_version: '11'
default_step_lib_source: https://github.com/bitrise-io/bitrise-steplib.git

workflows:
  test:
    steps:
    - activate-ssh-key:
        run_if: '{{getenv "SSH_RSA_PRIVATE_KEY" | ne ""}}'
    - git-clone: {}
    - xcode-test:
        inputs:
        - scheme: BlueBoxy
        - simulator_device: iPhone 15
        - should_build_before_test: 'yes'
        - generate_code_coverage_files: 'yes'
        - project_path: BlueBoxy.xcodeproj
    - deploy-to-bitrise-io: {}
```

#### CircleCI Configuration
```yaml
version: 2.1

jobs:
  test:
    macos:
      xcode: "15.0"
    steps:
      - checkout
      - run:
          name: Install Dependencies
          command: |
            # Add any dependency installation here
            
      - run:
          name: Run Tests
          command: |
            xcodebuild -scheme BlueBoxy \
              -sdk iphonesimulator \
              -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
              clean test \
              | xcpretty --report junit --output test-results.xml
              
      - store_test_results:
          path: test-results.xml
          
      - store_artifacts:
          path: test-results.xml

workflows:
  version: 2
  test:
    jobs:
      - test
```

## Test Configuration

### Info.plist Setup for Testing
Ensure your `Info.plist` contains the `BASE_URL` key for API configuration:

```xml
<key>BASE_URL</key>
<string>$(BASE_URL)</string>
```

### Xcconfig Files
Create configuration files for different environments:

**Debug.xcconfig**
```
BASE_URL = http://127.0.0.1:5000
```

**Release.xcconfig** 
```
BASE_URL = https://api.blueboxy.com
```

**Testing.xcconfig**
```
BASE_URL = http://localhost:3000
```

## Test Fixtures

### Adding New Fixtures
1. Place JSON files in `/BlueBoxyTests/Fixtures/[category]/`
2. Update `FixtureLoader` convenience methods if needed
3. Add corresponding tests in `ModelDecodingTests`

### Fixture Structure
```
BlueBoxyTests/Fixtures/
├── auth/
│   ├── me_success.json
│   └── login_success.json
├── messages/
│   └── generate_success.json
├── activities/
│   └── list_success.json
├── events/
│   ├── create_success.json
│   └── list_success.json
└── recommendations/
    ├── activities_success.json
    └── ai_powered_success.json
```

## Mock Testing

### MockURLProtocol Usage
```swift
// Setup mock response
MockURLProtocol.handler = MockURLProtocol.fixtureHandler(
    for: "https://api.test.com/api/activities",
    fixtureName: "activities/list_success",
    requestValidator: MockURLProtocol.validateAll(
        MockURLProtocol.validateMethod(.GET),
        MockURLProtocol.validatePath("/api/activities")
    )
)

// Make request with mocked client
let client = makeTestClient()
let response: ActivitiesResponse = try await client.request(endpoint)
```

### Request Validation Examples
```swift
// Validate HTTP method
MockURLProtocol.validateMethod(.POST)

// Validate headers
MockURLProtocol.validateHeader("Authorization", expectedValue: "Bearer token")

// Validate body content
MockURLProtocol.validateBodyContains("\"category\":\"test\"")

// Validate JSON structure
MockURLProtocol.validateJSONBody(MessageGenerateRequest.self)

// Combine multiple validations
MockURLProtocol.validateAll(
    MockURLProtocol.validateMethod(.POST),
    MockURLProtocol.validatePath("/api/messages/generate"),
    MockURLProtocol.validateHeader("X-User-ID", expectedValue: "123")
)
```

## Performance Testing

### Local Performance Benchmarking
```bash
# Run tests with timing info
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  test 2>&1 | grep -E "(Test Case|seconds)"
```

### CI Performance Monitoring
```bash
# Generate code coverage reports
xcodebuild -scheme BlueBoxy \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -enableCodeCoverage YES \
  clean test

# Extract performance metrics
xcrun xccov view --report BlueBoxy.xcresult/*/action.xccovreport
```

## Debugging Tests

### Common Issues

**Fixture Loading Failures**
- Verify fixture files are in test bundle target
- Check JSON syntax with `cat fixture.json | jq`
- Validate paths in FixtureLoader calls

**Mock Setup Issues**
- Ensure MockURLProtocol.reset() called between tests
- Verify handler is set before making requests
- Check URL matching in mock handlers

**Live Test Failures**
- Confirm backend is running (`npm run dev`)
- Verify BASE_URL points to local server
- Check LIVE_API=1 environment variable

### Debug Logging
```swift
#if DEBUG
// Enable in test setup
MockURLProtocol.handler = MockURLProtocol.successHandler(
    for: url,
    requestValidator: { request in
        print("🔍 Request: \(request.url?.absoluteString ?? "nil")")
        print("🔍 Method: \(request.httpMethod ?? "nil")")
        print("🔍 Headers: \(request.allHTTPHeaderFields ?? [:])")
    }
)
#endif
```

## Test Maintenance

### Regular Maintenance Tasks
- Update fixtures when API responses change
- Review and update mock validations
- Monitor test execution times
- Update CI configurations for new Xcode versions

### Adding New Model Tests
1. Add sample JSON to fixtures
2. Create decoding test in ModelDecodingTests
3. Add API client test if new endpoint
4. Update this documentation

### Code Coverage Goals
- **Models**: 100% decoding coverage
- **API Client**: 90%+ method coverage  
- **Networking**: 85%+ error path coverage
- **Overall**: 80%+ line coverage

## Troubleshooting

### Simulator Issues
```bash
# Reset simulators
xcrun simctl shutdown all
xcrun simctl erase all
xcrun simctl boot "iPhone 15"
```

### Build Issues
```bash
# Clean build folder
xcodebuild -scheme BlueBoxy clean
rm -rf ~/Library/Developer/Xcode/DerivedData/BlueBoxy-*

# Reset package cache
rm -rf ~/Library/Caches/org.swift.swiftpm/
```

### Test Data Issues
```bash
# Validate all fixture JSON
find BlueBoxyTests/Fixtures -name "*.json" -exec echo "Checking {}" \; -exec cat {} | jq . \;
```

---

This testing infrastructure ensures high quality and reliability for the BlueBoxy app through comprehensive coverage of models, networking, and integration scenarios.