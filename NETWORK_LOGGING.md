# Network Logging - Phase 3 Implementation

## Overview
The BlueBoxy iOS app now includes lightweight network logging for DEBUG builds to aid in development and debugging.

## Implementation

### NetLog Utility
- **Location**: `BlueBoxy/Core/Networking/NetLog.swift`
- **Purpose**: Lightweight network request/response logging using `os.Logger`
- **Privacy**: Keeps PII out of logs by using `.public` privacy levels appropriately
- **Build Configuration**: Only active in DEBUG builds via `#if DEBUG` compilation flags

### Features

#### Request Logging
```swift
NetLog.request(req)
```
- Logs HTTP method and URL
- Example: `➡️ POST http://192.168.1.16:3001/auth/login`

#### Response Logging
```swift
NetLog.response(http, data: data, started: start)
```
- Logs status code, duration, and truncated response body (first 500 chars)
- Example: `⬅️ 200 in 245.3ms :: {"user":{"id":123,"name":"John"}...`

#### Error Logging
```swift
NetLog.failure(error, started: start)
```
- Logs error description and duration
- Example: `❌ The Internet connection appears to be offline. in 5000.0ms`

#### Future Enhancement
```swift
NetLog.responseWithRequestId(http, data: data, started: start)
```
- Ready for when backend adds `x-request-id` headers
- Will log request ID for cross-correlation with server logs

## Integration

The logging is automatically integrated into `APIClient.request()` method:

1. **Request**: Logged before `session.data(for: req)`
2. **Success Response**: Logged after receiving valid HTTP response
3. **Failure**: Logged in catch blocks for both API errors and network errors

## Usage in Development

### Viewing Logs
- **Xcode Console**: View logs during development/debugging
- **Console.app**: On macOS, filter by subsystem `com.yourco.BlueBoxy` and category `network`
- **Device Logs**: Available in device logs when testing on physical devices

### Log Levels
- **Request/Response**: Uses `logger.debug()` - visible in development
- **Errors**: Uses `logger.error()` - higher visibility for issues

### Privacy Considerations
- All logged content uses `.public` privacy level
- Response bodies are truncated to 500 characters
- No sensitive headers (like Authorization) are logged
- User IDs in headers are not explicitly logged in the request

## Benefits

1. **Development Velocity**: Quick visibility into network calls
2. **Debugging**: Easy correlation between requests and responses
3. **Performance Monitoring**: Request duration tracking
4. **Cross-Platform Debugging**: Works in simulator and on device
5. **Zero Production Impact**: Completely disabled in release builds

## Future Enhancements

- [ ] Request ID correlation when backend implements `x-request-id`
- [ ] Optional request body logging for debugging (with PII filtering)
- [ ] Network metrics aggregation
- [ ] Integration with crash reporting tools