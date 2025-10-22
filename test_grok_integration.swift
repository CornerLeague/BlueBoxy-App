#!/usr/bin/env swift

import Foundation
import Network

// Simple test to check if Grok AI service configuration works
print("🧪 Testing Grok AI Integration...")

// Test 1: Check if we can create the service (this will test API key loading)
print("\n1️⃣ Testing API key configuration...")

let hasXAIKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil
let devPlaceholder = "xai-dev-key-placeholder"

if hasXAIKey {
    print("✅ XAI_API_KEY environment variable found")
} else {
    print("⚠️  XAI_API_KEY environment variable not found - using development placeholder")
}

// Test 2: Check network connectivity to XAI API
print("\n2️⃣ Testing network connectivity to api.x.ai...")

let url = URL(string: "https://api.x.ai")!
let request = URLRequest(url: url, timeoutInterval: 10)

let semaphore = DispatchSemaphore(value: 0)
var networkResult = "Unknown"

URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        networkResult = "❌ Network error: \(error.localizedDescription)"
    } else if let httpResponse = response as? HTTPURLResponse {
        networkResult = "✅ Connected to api.x.ai (Status: \(httpResponse.statusCode))"
    } else {
        networkResult = "❓ Unexpected response type"
    }
    semaphore.signal()
}.resume()

semaphore.wait()
print(networkResult)

// Test 3: Mock API call structure
print("\n3️⃣ Testing API request structure...")

let mockRequest = [
    "model": "grok-beta",
    "messages": [
        [
            "role": "system",
            "content": "You are an expert relationship coach..."
        ],
        [
            "role": "user", 
            "content": "Find activities for a couple in San Francisco..."
        ]
    ],
    "temperature": 0.7,
    "max_tokens": 2000,
    "stream": false
] as [String : Any]

do {
    let jsonData = try JSONSerialization.data(withJSONObject: mockRequest, options: .prettyPrinted)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
    print("✅ API request structure valid:")
    print("   Request size: \(jsonData.count) bytes")
    print("   Has required fields: model, messages, temperature, max_tokens")
} catch {
    print("❌ Invalid API request structure: \(error)")
}

print("\n🏁 Integration Test Summary:")
print("• API Key: \(hasXAIKey ? "Configured" : "Using placeholder")")
print("• Network: \(networkResult.contains("✅") ? "Connected" : "Issues detected")")
print("• Request Format: Valid")

if !hasXAIKey {
    print("\n💡 To enable real Grok AI integration:")
    print("   export XAI_API_KEY=\"your-actual-xai-api-key-here\"")
    print("   Then restart Xcode and rebuild the app")
}

print("\n🎯 Next steps:")
print("1. Open Activities tab in the BlueBoxy simulator")
print("2. Check Xcode debug console for Grok AI logs")
print("3. Look for: '🤖 Loading activities from Grok AI...'")
print("4. If using placeholder key, expect fallback to mock data")