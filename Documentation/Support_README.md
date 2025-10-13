# Support

This directory contains supporting files and utilities that don't fit into Core or Features.

## Structure

- **Config**: Configuration files (xcconfig, Info.plist files)
- **Extensions**: Swift extensions and small utility functions
- **Logging**: Logging utilities and configuration

## Config Directory

Contains environment-specific configuration:
- `Debug.xcconfig` - Development configuration
- `Release.xcconfig` - Production configuration  
- `Info-Debug.plist` - Debug Info.plist with ATS exceptions
- `Info-Release.plist` - Production Info.plist (HTTPS-only)

## Extensions Directory

Should contain small, reusable extensions:
```swift
// Example: String+Extensions.swift
// Example: View+Extensions.swift  
// Example: Color+Extensions.swift
```

## Logging Directory

Centralized logging configuration and utilities.