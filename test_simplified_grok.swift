#!/usr/bin/env swift

import Foundation

// Test the simplified Grok AI request
// Replace with your actual API key or get from environment
let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "YOUR_XAI_API_KEY_HERE"

print("🧪 Testing Simplified Grok AI Request...")
print("   Reduced tokens: 800 (was 2000)")
print("   Simpler prompt")
print("   Faster timeout: 15s")

// Simplified request
let requestPayload = [
    "model": "grok-3",
    "messages": [
        [
            "role": "system",
            "content": "You are a helpful activity recommendation assistant. Provide activity suggestions in JSON format."
        ],
        [
            "role": "user",
            "content": "Suggest 3 fun activities for a couple in your area. Return as JSON with: name, description, category, location, estimatedCost, duration."
        ]
    ],
    "temperature": 0.7,
    "max_tokens": 800,
    "stream": false
] as [String : Any]

let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.timeoutInterval = 15.0 // Match app timeout

var result: (data: Data?, response: URLResponse?, error: Error?) = (nil, nil, nil)

do {
    let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: [])
    request.httpBody = jsonData
    
    print("\n🌐 Making simplified request...")
    print("   Request size: \(jsonData.count) bytes (was 1795)")
    
    let start = Date()
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        result = (data, response, error)
        semaphore.signal()
    }
    
    task.resume()
    
    let timeoutResult = semaphore.wait(timeout: .now() + 20.0)
    let elapsed = Date().timeIntervalSince(start)
    
    if timeoutResult == .timedOut {
        task.cancel()
        print("⏰ Still timing out after 20 seconds")
        print("   The issue may be with Grok-3 model or API endpoint")
    } else {
        print("⏱️ Completed in \(String(format: "%.2f", elapsed))s")
        
        if let error = result.error {
            print("❌ Error: \(error.localizedDescription)")
        } else if let httpResponse = result.response as? HTTPURLResponse {
            print("📡 Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let data = result.data {
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    print("✅ SUCCESS! (\(data.count) bytes)")
                    print("📄 Response preview:")
                    print(responseString.prefix(300))
                    
                    // Try parsing JSON
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            print("\n🤖 AI Response:")
                            print(content.prefix(200))
                        }
                    }
                } else {
                    print("❌ No data in successful response")
                }
            } else {
                let errorData = result.data ?? Data()
                let errorString = String(data: errorData, encoding: .utf8) ?? "No error details"
                print("❌ API Error: \(errorString)")
            }
        }
    }
    
} catch {
    print("❌ Request creation failed: \(error)")
}

print("\n🎯 Result:")
if result.response != nil {
    print("✅ The simplified request works! Your app should now respond faster.")
    print("   Try the Generate Activities button again.")
} else {
    print("❌ Still having issues. The problem might be:")
    print("   • Grok-3 model availability")
    print("   • Network connectivity")
    print("   • API rate limiting")
}