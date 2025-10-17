#!/usr/bin/swift

import Foundation

// Reset onboarding status to test the full flow
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
UserDefaults.standard.synchronize()

print("✅ Onboarding status reset - app should show onboarding flow")