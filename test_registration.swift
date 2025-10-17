#!/usr/bin/env swift

import Foundation

// Test registration flow with detailed error reporting
print("🔍 BlueBoxy Registration Flow Test")
print("===================================")

func testRegistration(email: String, password: String, name: String) {
    print("\n📝 Testing registration for: \(email)")
    
    let url = URL(string: "http://localhost:3001/api/auth/register")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("BlueBoxy iOS/1.0.0", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 20 // Same as app config
    
    let requestBody: [String: Any] = [
        "email": email,
        "password": password,
        "name": name,
        "partner_name": nil as Any?, // Test snake_case fields
        "personality_type": nil as Any?
    ]
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
        request.httpBody = jsonData
        
        print("📤 Request body:")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var httpResponse: HTTPURLResponse?
        
        let startTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            responseData = data
            responseError = error
            httpResponse = response as? HTTPURLResponse
        }
        
        print("⏱️  Starting request...")
        task.resume()
        
        let timeoutResult = semaphore.wait(timeout: .now() + 25) // Slightly longer than request timeout
        let elapsed = Date().timeIntervalSince(startTime)
        
        if timeoutResult == .timedOut {
            print("⏰ Request timed out after \(elapsed) seconds")
            task.cancel()
            return
        }
        
        print("⏱️  Request completed in \(String(format: "%.2f", elapsed)) seconds")
        
        if let error = responseError {
            print("❌ Network error: \(error.localizedDescription)")
            
            // Detailed error analysis
            let nsError = error as NSError
            print("📋 Error domain: \(nsError.domain)")
            print("📋 Error code: \(nsError.code)")
            
            if nsError.code == NSURLErrorTimedOut {
                print("💡 This is a genuine timeout error")
            } else if nsError.code == NSURLErrorCannotConnectToHost {
                print("💡 Cannot connect to host - server might be down")
            } else if nsError.code == NSURLErrorNetworkConnectionLost {
                print("💡 Network connection lost")
            }
            
            return
        }
        
        guard let httpResp = httpResponse else {
            print("❌ No HTTP response received")
            return
        }
        
        print("📨 HTTP Status: \(httpResp.statusCode)")
        print("📋 Response headers:")
        for (key, value) in httpResp.allHeaderFields {
            print("   \(key): \(value)")
        }
        
        guard let data = responseData else {
            print("❌ No response data")
            return
        }
        
        print("📄 Response body (\(data.count) bytes):")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
            
            // Try to parse as JSON for better formatting
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("\n📊 Parsed response:")
                    for (key, value) in json {
                        print("   \(key): \(value)")
                    }
                    
                    // Check for token
                    if let token = json["token"] as? String {
                        if token.isEmpty {
                            print("⚠️  Token is empty string!")
                        } else {
                            print("✅ Valid token received (length: \(token.count))")
                        }
                    } else {
                        print("⚠️  No token in response")
                    }
                    
                    // Check for error message
                    if let errorMsg = json["error"] as? String {
                        print("❌ Server error: \(errorMsg)")
                    }
                }
            } catch {
                print("⚠️  Could not parse JSON: \(error)")
            }
        }
        
    } catch {
        print("❌ Failed to create request: \(error)")
    }
}

// Test scenarios
let scenarios = [
    ("Existing email", "test@example.com", "password123", "Test User"),
    ("New unique email", "unique-\(Int.random(in: 1000...9999))@example.com", "password123", "Unique User"),
    ("Invalid email", "not-an-email", "password123", "Invalid Email User"),
    ("Empty password", "empty@example.com", "", "Empty Password User")
]

for (name, email, password, userName) in scenarios {
    print("\n" + String(repeating: "=", count: 50))
    print("🧪 Test: \(name)")
    testRegistration(email: email, password: password, name: userName)
    
    // Brief pause between tests
    Thread.sleep(forTimeInterval: 1)
}

print("\n" + String(repeating: "=", count: 50))
print("✨ Registration flow testing complete!")
print("\n💡 If you see 'User already exists' errors, try:")
print("   • Use a different email address")
print("   • Clear your backend database")
print("   • Add DELETE endpoint to remove test users")
print("\n🔧 If you see genuine timeouts, try:")
print("   • Check server logs for slow queries")
print("   • Increase timeout in APIConfiguration.swift")
print("   • Verify database connectivity")