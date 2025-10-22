#!/usr/bin/env swift

import Foundation

// Test real XAI API call with your key
print("🧪 Testing Real XAI API Call...")

let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "missing"
print("API Key format: \(apiKey.prefix(10))...\(apiKey.suffix(4)) (Length: \(apiKey.count))")

// Validate key format
if apiKey.hasPrefix("xai-") {
    print("✅ API key has correct 'xai-' prefix")
} else {
    print("❌ API key should start with 'xai-'")
}

// Test actual API call
let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let testPayload = [
    "model": "grok-3",
    "messages": [
        [
            "role": "system",
            "content": "You are a helpful assistant. Respond with exactly one sentence."
        ],
        [
            "role": "user",
            "content": "Say hello and confirm you're working."
        ]
    ],
    "temperature": 0.7,
    "max_tokens": 50
] as [String : Any]

do {
    let jsonData = try JSONSerialization.data(withJSONObject: testPayload, options: [])
    request.httpBody = jsonData
    
    print("\n🌐 Making API call to Grok AI...")
    
    let semaphore = DispatchSemaphore(value: 0)
    var result = "No response"
    
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
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        
        if httpResponse.statusCode == 200 {
            // Parse successful response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                result = "✅ SUCCESS: Grok AI responded: '\(content.trimmingCharacters(in: .whitespacesAndNewlines))'"
            } else {
                result = "✅ API call successful but couldn't parse response: \(responseString)"
            }
        } else {
            result = "❌ API Error (\(httpResponse.statusCode)): \(responseString)"
        }
    }.resume()
    
    semaphore.wait()
    print(result)
    
} catch {
    print("❌ Failed to create request: \(error)")
}

print("\n🎯 If you see a SUCCESS message above, your Grok AI integration is working!")
print("If you see errors, check:")
print("1. API key is valid and active at https://console.x.ai")
print("2. API key hasn't expired or been revoked")
print("3. Your account has sufficient credits")
print("4. Network connection is stable")