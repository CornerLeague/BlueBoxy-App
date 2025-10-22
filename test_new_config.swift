#!/usr/bin/env swift

import Foundation

print("🔧 Testing New Component-Based URL Configuration")
print("=" + String(repeating: "=", count: 50))

// Test URL building like the new APIConfiguration does
func testURLBuilding() {
    let scheme = "http"
    let host = "127.0.0.1"
    let port = 3001
    
    print("📋 Testing URL components:")
    print("   Scheme: \(scheme)")
    print("   Host: \(host)")
    print("   Port: \(port)")
    
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.port = port
    
    if let url = components.url {
        print("✅ Successfully built URL: \(url)")
        
        // Test health endpoint
        Task {
            do {
                let healthURL = url.appendingPathComponent("api/health")
                print("🔍 Testing: \(healthURL)")
                
                let (data, response) = try await URLSession.shared.data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("✅ Health check: HTTP \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Response: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 {
                        print("🎉 Configuration working perfectly!")
                    }
                }
            } catch {
                print("❌ Health check failed: \(error)")
            }
        }
        
    } else {
        print("❌ Failed to build URL from components")
    }
}

testURLBuilding()

// Keep script running for async task
RunLoop.main.run(until: Date().addingTimeInterval(3))