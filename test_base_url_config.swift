#!/usr/bin/env swift

import Foundation

// Test BASE_URL configuration loading exactly like the iOS app
print("🔧 Testing BASE_URL Configuration")
print("=" + String(repeating: "=", count: 40))

// Simulate Bundle.main.object call like APIConfiguration does
print("📋 Testing Info.plist loading...")

// Since we can't access the actual app bundle from a script, let's test both approaches
let testURLs = [
    "http://127.0.0.1:3001",
    "http://localhost:3001",
    "http://192.168.1.41:3001"
]

for (index, urlString) in testURLs.enumerated() {
    print("\n\(index + 1)️⃣ Testing URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
        print("   ❌ Invalid URL format")
        continue
    }
    
    // Test health endpoint
    do {
        let (data, response) = try await URLSession.shared.data(from: url.appendingPathComponent("api/health"))
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   ✅ Health check: HTTP \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                print("   🎉 This URL works!")
            }
        }
    } catch {
        print("   ❌ Failed: \(error)")
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost:
                print("      Cannot connect to host")
            case .timedOut:
                print("      Request timed out")
            default:
                print("      \(urlError.localizedDescription)")
            }
        }
    }
}

// Test URL building like APIClient does
print("\n🔧 Testing APIClient-style URL building...")

func testURLBuilding(baseURLString: String, path: String) {
    print("\n📌 Base URL: \(baseURLString)")
    print("   Path: \(path)")
    
    guard let baseURL = URL(string: baseURLString) else {
        print("   ❌ Invalid base URL")
        return
    }
    
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
        print("   ❌ Failed to create URLComponents")
        return
    }
    
    let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    if components.path.hasSuffix("/") {
        components.path += cleanPath
    } else {
        components.path += "/\(cleanPath)"
    }
    
    guard let finalURL = components.url else {
        print("   ❌ Failed to build final URL")
        return
    }
    
    print("   ✅ Final URL: \(finalURL)")
    
    // Quick connectivity test
    Task {
        do {
            let (_, response) = try await URLSession.shared.data(from: finalURL)
            if let httpResponse = response as? HTTPURLResponse {
                print("   ✅ Response: HTTP \(httpResponse.statusCode)")
            }
        } catch {
            print("   ❌ Connection failed: \(error)")
        }
    }
}

// Test the combinations that the app might use
testURLBuilding(baseURLString: "http://127.0.0.1:3001", path: "/api/auth/register")
testURLBuilding(baseURLString: "http://127.0.0.1:3001", path: "api/auth/register")
testURLBuilding(baseURLString: "http://127.0.0.1:3001", path: "/api/user/stats")

print("\n⏳ Waiting for async operations to complete...")

// Give async operations time to complete
RunLoop.main.run(until: Date().addingTimeInterval(3))