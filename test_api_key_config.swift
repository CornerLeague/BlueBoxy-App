#!/usr/bin/env swift

import Foundation

// Test the API key configuration that the app is now using
// Replace with your actual API key or get from environment
let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "YOUR_XAI_API_KEY_HERE"

print("🧪 Testing API Key Configuration...")
print("📋 API Key Details:")
print("   Length: \(apiKey.count) characters")
print("   Prefix: \(apiKey.prefix(10))...")
print("   Suffix: ...\(apiKey.suffix(4))")
print("   Format: \(apiKey.hasPrefix("xai-") ? "✅ Valid" : "❌ Invalid")")

// Quick API test with the actual key
let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let testPayload = [
    "model": "grok-3",
    "messages": [
        ["role": "user", "content": "Say 'API key is working!' in exactly those words."]
    ],
    "max_tokens": 10
] as [String : Any]

var result = "No response"

do {
    let jsonData = try JSONSerialization.data(withJSONObject: testPayload, options: [])
    request.httpBody = jsonData
    
    print("\n🌐 Testing API call with hardcoded key...")
    
    let semaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            result = "❌ Network error: \(error.localizedDescription)"
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            result = "❌ Invalid response type"
            return
        }
        
        guard let data = data else {
            result = "❌ No data received"
            return
        }
        
        if httpResponse.statusCode == 200 {
            result = "✅ SUCCESS: API key is working!"
        } else {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            result = "❌ API Error (\(httpResponse.statusCode)): \(responseString)"
        }
    }.resume()
    
    semaphore.wait()
    print(result)
    
} catch {
    print("❌ Failed to create request: \(error)")
}

if result.contains("SUCCESS") {
    print("\n🎉 The app should now work correctly!")
    print("   Navigate to Activities tab and press 'Generate Activities'")
} else {
    print("\n⚠️  There may still be an issue with the API key or service")
}