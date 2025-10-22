#!/usr/bin/env swift

import Foundation

// Direct test of the Grok AI API to debug hanging issue
// Replace with your actual API key or get from environment
let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? "YOUR_XAI_API_KEY_HERE"

print("🧪 Testing Grok AI Service Directly...")
print("   This will simulate the exact call the app makes")

// Create the exact request structure from GrokAIService
let requestPayload = [
    "model": "grok-3",
    "messages": [
        [
            "role": "system",
            "content": """
You are an expert relationship coach and local activity curator with deep knowledge of personality psychology and couple dynamics. Your role is to recommend meaningful, personalized activities for couples based on their personality types, relationship stage, and location.

Key principles:
- Tailor recommendations to personality types and communication styles
- Consider the relationship duration and suggest appropriate intimacy levels
- Include practical details like cost, duration, and timing
- Provide actionable tips for making each activity special
- Focus on experiences that build connection and create lasting memories
- Always respond with valid JSON in the exact GrokActivitiesResponse format

When making recommendations:
- Be specific about locations and venues when possible
- Provide realistic cost estimates
- Consider accessibility and practical logistics
- Offer alternatives for different preferences
- Explain the psychological benefits of each activity
"""
        ],
        [
            "role": "user",
            "content": """
I need personalized activity recommendations for a couple based on these criteria:

📍 Location: your area
📏 Search radius: 25 miles

✨ Ideal Activities: 
❤️ Love Language: 
🗣️ Communication Style: 

🌸 Season: winter

Please provide 5-8 specific, actionable activity recommendations in valid JSON format matching the GrokActivitiesResponse structure. Include real places and businesses when possible, estimate realistic costs, and explain why each recommendation matches their personality and relationship dynamics. Focus on activities that would strengthen their connection and create memorable experiences together.
"""
        ]
    ],
    "temperature": 0.7,
    "max_tokens": 2000,
    "stream": false
] as [String : Any]

let url = URL(string: "https://api.x.ai/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.timeoutInterval = 30.0

do {
    let jsonData = try JSONSerialization.data(withJSONObject: requestPayload, options: [])
    request.httpBody = jsonData
    
    print("\n🌐 Making Grok AI request...")
    print("   Request size: \(jsonData.count) bytes")
    print("   Timeout: 30 seconds")
    
    let start = Date()
    
    let semaphore = DispatchSemaphore(value: 0)
    var result: (data: Data?, response: URLResponse?, error: Error?) = (nil, nil, nil)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        result = (data, response, error)
        semaphore.signal()
    }
    
    task.resume()
    
    // Add timeout check
    let timeoutResult = semaphore.wait(timeout: .now() + 35.0)
    let elapsed = Date().timeIntervalSince(start)
    
    if timeoutResult == .timedOut {
        task.cancel()
        print("⏰ Request timed out after 35 seconds")
        print("   This is likely why the app hangs!")
    } else {
        print("⏱️ Request completed in \(String(format: "%.2f", elapsed))s")
        
        if let error = result.error {
            print("❌ Network error: \(error.localizedDescription)")
        } else if let httpResponse = result.response as? HTTPURLResponse {
            print("📡 HTTP Status: \(httpResponse.statusCode)")
            
            if let data = result.data {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                print("📄 Response (\(data.count) bytes):")
                
                if httpResponse.statusCode == 200 {
                    print("✅ SUCCESS! Grok AI responded:")
                    print(responseString.prefix(500))
                    if responseString.count > 500 {
                        print("... (truncated, \(responseString.count) total chars)")
                    }
                } else {
                    print("❌ API Error: \(responseString)")
                }
            } else {
                print("❌ No response data")
            }
        }
    }
    
} catch {
    print("❌ Failed to create request: \(error)")
}

print("\n🎯 Analysis:")
print("If this test hangs or times out, it explains why your app spins forever.")
print("If this test works, the issue is in the app's async handling.")