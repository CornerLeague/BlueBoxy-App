# Color Setup Guide

This guide shows how to set up the design system colors in `Assets.xcassets`.

## Required Color Sets

Add these color sets to your `Assets.xcassets` catalog:

### Base Colors
- **Background** - Main background color
  - Light: `#FFFFFF` (White)
  - Dark: `#000000` (Black)

- **Foreground** - Main text color
  - Light: `#000000` (Black)
  - Dark: `#FFFFFF` (White)

- **Primary** - Brand primary color
  - Light: `#3B82F6` (Blue-500)
  - Dark: `#60A5FA` (Blue-400)

- **Accent** - Accent/secondary brand color
  - Light: `#8B5CF6` (Purple-500)
  - Dark: `#A78BFA` (Purple-400)

### Status Colors
- **Success** - Success state color
  - Light: `#10B981` (Emerald-500)
  - Dark: `#34D399` (Emerald-400)

- **Warning** - Warning state color
  - Light: `#F59E0B` (Amber-500)
  - Dark: `#FBB84F` (Amber-400)

- **Error** - Error state color
  - Light: `#EF4444` (Red-500)
  - Dark: `#F87171` (Red-400)

- **Destructive** - Destructive action color
  - Light: `#DC2626` (Red-600)
  - Dark: `#EF4444` (Red-500)

- **Info** - Information color
  - Light: `#3B82F6` (Blue-500)
  - Dark: `#60A5FA` (Blue-400)

### Semantic Colors
- **CardBackground** - Card/surface background
  - Light: `#F9FAFB` (Gray-50)
  - Dark: `#1F2937` (Gray-800)

- **Border** - Border color
  - Light: `#E5E7EB` (Gray-200)
  - Dark: `#374151` (Gray-700)

- **Muted** - Muted background color
  - Light: `#F3F4F6` (Gray-100)
  - Dark: `#111827` (Gray-900)

- **MutedForeground** - Muted text color
  - Light: `#6B7280` (Gray-500)
  - Dark: `#9CA3AF` (Gray-400)

## How to Add Colors in Xcode

1. Open `Assets.xcassets` in Xcode
2. Right-click and select "New Color Set"
3. Name it exactly as shown above (e.g., "Background")
4. Set the Universal color value
5. For dark mode support:
   - Click the "Appearances" button in Attributes Inspector
   - Select "Any, Dark"
   - Set different colors for Light and Dark appearances

## Using System Colors as Fallbacks

The DesignSystem.swift already includes system color fallbacks:

```swift
// System Colors (fallbacks if Assets don't exist)
static let systemBackground = Color(.systemBackground)
static let systemForeground = Color(.label)
static let systemSecondary = Color(.secondaryLabel)
static let systemTertiary = Color(.tertiaryLabel)
```

If you don't create custom color assets, the app will use these system colors and work correctly with light/dark mode.

## Tailwind CSS Equivalent

These colors map to Tailwind CSS classes:

- Primary: `bg-blue-500 text-blue-500`
- Success: `bg-emerald-500 text-emerald-500`  
- Warning: `bg-amber-500 text-amber-500`
- Error: `bg-red-500 text-red-500`
- Muted: `bg-gray-100 text-gray-500`

This ensures consistency if you have a web version of your app.