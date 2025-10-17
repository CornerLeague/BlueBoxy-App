# Registration Endpoint Consolidation - Migration Guide

## Overview

This migration consolidates conflicting registration endpoints in the BlueBoxy app to use a single canonical endpoint with consistent payload formatting.

## Problem Summary

Previously, the app had conflicting registration implementations:
- **SessionViewModel**: Used `/api/auth/register` with snake_case payload (`partner_name`, `personality_type`)
- **AuthService**: Used `/auth/signup` with different payload format
- **AuthViewModel**: Used `Endpoint.authRegister()` which mapped to `/api/auth/register` but with different request models

This led to potential 404s, inconsistent backend behavior, and maintenance issues.

## Solution

### 1. Centralized Registration Service

Created `RegistrationDTO.swift` with:
- **`RegistrationRequest`**: Unified request model with snake_case field mapping
- **`RegistrationService`**: Centralized service that all parts of the app use
- **`RegistrationRequestBuilder`**: Builder pattern for flexible request construction

### 2. Canonical Endpoint

**All registration now uses**: `/api/auth/register`

**Consistent payload format** (snake_case):
```json
{
  "email": "user@example.com",
  "password": "password123",
  "name": "User Name",
  "partner_name": "Partner Name",
  "personality_type": "INTJ",
  "relationship_duration": "6 months",
  "partner_age": 25
}
```

## Changes Made

### Files Modified

1. **`/Core/Models/RegistrationDTO.swift`** - NEW
   - Centralized registration request model and service

2. **`/Core/Services/AuthService.swift`**
   - `signUp()` method now uses `RegistrationService`

3. **`/Core/ViewModels/SessionViewModel.swift`**
   - `register()` method now uses `RegistrationService`

4. **`/ViewModels/AuthViewModel.swift`**
   - `register()` method now uses `RegistrationService`

5. **`/ViewModels/AuthViewModel+Bootstrap.swift`**
   - `enhancedRegister()` method now uses `RegistrationService`

6. **`/BlueBoxyTests/RegistrationServiceTests.swift`** - NEW
   - Comprehensive tests to prevent regression

### Migration Steps

#### For Developers

1. **Update Import Statements**
   ```swift
   // No additional imports needed - RegistrationDTO is part of BlueBoxy module
   ```

2. **Replace Direct Endpoint Calls**
   
   **Before:**
   ```swift
   let endpoint = Endpoint(path: "/auth/signup", method: .POST, body: request)
   let response: AuthEnvelope = try await apiClient.request(endpoint)
   ```
   
   **After:**
   ```swift
   let registrationService = RegistrationService()
   let response = try await registrationService.register(request)
   ```

3. **Update Request Models**
   
   **Before:**
   ```swift
   let request = SignUpRequest(email: email, password: password, name: name)
   ```
   
   **After:**
   ```swift
   let request = RegistrationRequest(email: email, password: password, name: name)
   ```

4. **Use Builder Pattern for Complex Requests**
   ```swift
   let request = RegistrationRequestBuilder()
       .setEmail("user@example.com")
       .setPassword("password123")
       .setName("User Name")
       .setPartnerName("Partner Name")
       .setPersonalityType("INTJ")
       .build()
   ```

#### For Backend Teams

1. **Deprecate Legacy Endpoint**
   - Keep `/auth/signup` temporarily as a redirect to `/api/auth/register`
   - Add deprecation warnings in logs
   - Plan removal in future release

2. **Verify Field Mapping**
   - Ensure backend accepts snake_case fields: `partner_name`, `personality_type`, `relationship_duration`, `partner_age`
   - All registration flows now send identical payloads

## Backward Compatibility

### Legacy Request Conversion

The new `RegistrationRequest` can convert from legacy models:

```swift
// From SignUpRequest
let legacyRequest = SignUpRequest(...)
let newRequest = RegistrationRequest(from: legacyRequest)

// From RegisterRequest  
let legacyRequest = RegisterRequest(...)
let newRequest = RegistrationRequest(from: legacyRequest)
```

### Factory Methods

Convenient factory methods for common scenarios:

```swift
// Basic registration
let request = RegistrationRequest.basic(email: "user@example.com", password: "password123")

// With name
let request = RegistrationRequest.withName(email: "user@example.com", password: "password123", name: "User")

// Complete registration
let request = RegistrationRequest.complete(
    email: "user@example.com", 
    password: "password123", 
    name: "User",
    partnerName: "Partner",
    personalityType: "INTJ"
)
```

## Testing

### Running Tests

```bash
# Run specific registration tests
xcodebuild test -scheme BlueBoxy -only-testing:BlueBoxyTests/RegistrationServiceTests

# Run all tests to ensure no regression
xcodebuild test -scheme BlueBoxy
```

### Key Test Coverage

- ✅ All registration services use canonical endpoint
- ✅ Payload format consistency (snake_case fields)
- ✅ Legacy request model compatibility
- ✅ Builder pattern functionality
- ✅ Validation logic
- ✅ Error handling

## Verification Checklist

- [ ] All registration calls use `/api/auth/register`
- [ ] All payloads use snake_case field mapping
- [ ] No registration calls use `/auth/signup`
- [ ] Tests pass without modification
- [ ] Backend receives consistent payloads
- [ ] Legacy SignUpRequest/RegisterRequest still work (converted automatically)

## Rollback Plan

If issues arise, you can temporarily revert individual services:

1. **AuthService rollback:**
   ```swift
   // Revert to direct endpoint call in signUp() method
   let endpoint = Endpoint(path: "/auth/signup", method: .POST, body: SignUpRequest(...))
   ```

2. **SessionViewModel rollback:**
   ```swift
   // Revert to inline RegisterBody struct and direct endpoint call
   ```

However, this would re-introduce the inconsistency issues.

## Benefits

1. **Consistency**: All registration uses same endpoint and payload format
2. **Maintainability**: Single source of truth for registration logic
3. **Testability**: Centralized service is easier to mock and test
4. **Future-proofing**: Changes to registration logic only need to happen in one place
5. **Error Handling**: Unified error handling across all registration flows

## Support

If you encounter issues with the migration:
1. Check the test suite for examples of proper usage
2. Review the `RegistrationDTO.swift` file for all available methods
3. Ensure you're using the canonical endpoint `/api/auth/register`
4. Verify your payload uses snake_case field names