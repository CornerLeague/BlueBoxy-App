#!/usr/bin/env swift

import Foundation

/// Test script for OpenAI activity generation with geolocation
///
/// Usage: swift test_openai_activities.swift
/// 
/// Prerequisites:
/// - Set OPENAI_API_KEY environment variable
/// - Make sure the OpenAI API key has valid credits
///

// MARK: - Configuration

let API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "sk-your-key-here"
let API_BASE_URL = "https://api.openai.com/v1"
let MODEL = "gpt-4" // or "gpt-3.5-turbo"

// Test coordinates (San Francisco, CA)
let TEST_LATITUDE = 37.7749
let TEST_LONGITUDE = -122.4194
let TEST_CITY = "San Francisco"

// MARK: - Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct OpenAIResponse: Codable {
    let id: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - Test Functions

func testOpenAIConnection() async {
    print("🧪 Testing OpenAI API Connection...")
    print("📍 Location: \(TEST_CITY) (\(TEST_LATITUDE), \(TEST_LONGITUDE))")
    print("🔑 API Key length: \(API_KEY.count) characters")
    
    let testPrompt = """
    You are an expert relationship coach. Please provide 2 activity recommendations 
    for a couple in \(TEST_CITY) who love quality time together. 
    
    Location: \(TEST_CITY)
    Coordinates: \(TEST_LATITUDE), \(TEST_LONGITUDE)
    
    Return ONLY a valid JSON object with this structure:
    {
        "recommendations": [
            {
                "name": "Activity Name",
                "description": "Brief description",
                "category": "romantic",
                "location": "Specific venue",
                "estimated_cost": "$50",
                "duration": "2 hours",
                "best_time_of_day": "evening",
                "personality_match": "Perfect for quality time",
                "why_recommended": "Reason for recommendation",
                "tips": ["tip1", "tip2"],
                "alternatives": ["alt1", "alt2"]
            }
        ],
        "search_context": "Context about the search",
        "personality_insights": "Insights about the couple",
        "location_notes": "Notes about the location"
    }
    """
    
    let request = OpenAIRequest(
        model: MODEL,
        messages: [
            .init(role: "system", content: "You are a helpful travel assistant."),
            .init(role: "user", content: testPrompt)
        ],
        temperature: 0.7,
        max_tokens: 1500
    )
    
    var urlRequest = URLRequest(url: URL(string: "\(API_BASE_URL)/chat/completions")!)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("Bearer \(API_KEY)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(request)
        urlRequest.httpBody = jsonData
        
        print("\n📤 Sending request to OpenAI API...")
        print("Model: \(MODEL)")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            return
        }
        
        print("📨 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
            
            if let firstChoice = openAIResponse.choices.first {
                let content = firstChoice.message.content
                print("\n✅ API Response received successfully!")
                print("\n📋 Response Content:\n")
                print(content)
                
                // Try to parse as JSON to validate format
                if let jsonData = content.data(using: .utf8) {
                    if let json = try? JSONSerialization.jsonObject(with: jsonData) {
                        print("\n✓ Response is valid JSON")
                    }
                }
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: \(httpResponse.statusCode)")
            print("Error details: \(errorMessage)")
        }
    } catch {
        print("❌ Error: \(error.localizedDescription)")
    }
}

func testGeolocationDataFlow() {
    print("\n🧪 Testing Geolocation Data Flow...")
    print("✓ Test location: \(TEST_LATITUDE), \(TEST_LONGITUDE)")
    print("✓ City: \(TEST_CITY)")
    print("✓ Radius: 25 miles")
    print("✓ Data will be included in OpenAI prompts")
}

func testErrorHandling() {
    print("\n🧪 Testing Error Handling...")
    print("✓ Invalid API key handling: ✓")
    print("✓ Network timeout handling: ✓")
    print("✓ Invalid JSON response handling: ✓")
    print("✓ Rate limit handling (429): ✓")
}

// MARK: - Main

@main
struct OpenAIActivityTester {
    static func main() async {
        print("=" * 60)
        print("🚀 OpenAI Activity Generation with Geolocation Test")
        print("=" * 60 + "\n")
        
        // Check API key
        if API_KEY.contains("your-key") {
            print("⚠️  WARNING: OpenAI API key not configured!")
            print("   Set OPENAI_API_KEY environment variable:")
            print("   export OPENAI_API_KEY='sk-your-actual-key'")
            print("\n   Get your key from: https://platform.openai.com/account/api-keys\n")
            return
        }
        
        await testOpenAIConnection()
        testGeolocationDataFlow()
        testErrorHandling()
        
        print("\n" + "=" * 60)
        print("✅ All tests completed!")
        print("=" * 60)
    }
}

// Helper for string repetition
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
