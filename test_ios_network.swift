#!/usr/bin/env swift

import Foundation

// Test the same network path that iOS app will use
func testIOSNetworkPath() async {
    print("🔍 Testing iOS Network Path")
    print("=" + String(repeating: "=", count: 40))
    
    // Test the exact URL that iOS app will use based on our config
    let baseURL = "http://192.168.1.41:3001"
    
    print("📡 Testing connection to: \(baseURL)")
    
    // Test 1: Health check
    print("\n1️⃣ Health Check...")
    do {
        let healthURL = URL(string: "\(baseURL)/api/health")!
        let (data, response) = try await URLSession.shared.data(from: healthURL)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   ✅ Health check: HTTP \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   📄 Response: \(responseString)")
            }
        }
    } catch {
        print("   ❌ Health check failed: \(error)")
        if let urlError = error as? URLError {
            print("      Error code: \(urlError.code)")
            print("      Description: \(urlError.localizedDescription)")
        }
        return
    }
    
    // Test 2: Registration endpoint test
    print("\n2️⃣ Registration Endpoint Test...")
    do {
        let regURL = URL(string: "\(baseURL)/api/auth/register")!
        var request = URLRequest(url: regURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BlueBoxy iOS/1.0.0 (1)", forHTTPHeaderField: "User-Agent")
        
        // Simple test payload
        let testData = [
            "email": "networktest-\(Int.random(in: 1000...9999))@example.com",
            "password": "testpass123",
            "name": "Network Test"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: testData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   ✅ Registration endpoint: HTTP \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   📄 Response: \(responseString)")
            }
            
            // Check if we got a successful registration
            if httpResponse.statusCode == 201 {
                print("   🎉 Registration successful!")
            } else if httpResponse.statusCode == 400 {
                print("   ⚠️ Client error (expected for validation)")
            } else {
                print("   ❌ Unexpected status code")
            }
        }
        
    } catch {
        print("   ❌ Registration test failed: \(error)")
        if let urlError = error as? URLError {
            print("      Error code: \(urlError.code)")
            print("      Description: \(urlError.localizedDescription)")
        }
    }
    
    // Test 3: Timeout test
    print("\n3️⃣ Timeout Test...")
    do {
        let timeoutURL = URL(string: "\(baseURL)/api/health")!
        var request = URLRequest(url: timeoutURL)
        request.timeoutInterval = 5.0 // 5 second timeout
        
        let start = Date()
        let (_, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(start)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   ✅ Request completed in \(String(format: "%.2f", duration))s")
            print("   📊 Status: \(httpResponse.statusCode)")
        }
        
    } catch {
        print("   ❌ Timeout test failed: \(error)")
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                print("      ⏰ Request timed out")
            case .cannotConnectToHost:
                print("      🚫 Cannot connect to host")
            default:
                print("      🔍 Other error: \(urlError.localizedDescription)")
            }
        }
    }
}

// Run test
Task {
    await testIOSNetworkPath()
}

// Keep alive
RunLoop.main.run(until: Date().addingTimeInterval(10))