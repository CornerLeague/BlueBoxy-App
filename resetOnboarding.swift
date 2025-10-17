#!/usr/bin/env swift

import Foundation

// Reset the onboarding completion status
UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")

// Synchronize the changes
UserDefaults.standard.synchronize()

print("✅ Onboarding status has been reset. The app will now show onboarding on next launch.")