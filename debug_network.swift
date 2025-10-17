#!/usr/bin/env swift

import Foundation
import Network

// Network diagnostics script for BlueBoxy API connection issues
print("🔍 BlueBoxy Network Diagnostics")
print("===============================")

// 1. Check if localhost:3001 is reachable
func checkPortConnectivity(host: String, port: Int) {
    print("\n📡 Testing connection to \(host):\(port)...")
    
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkMonitor")
    
    monitor.pathUpdateHandler = { path in
        if path.status == .satisfied {
            print("✅ Device has network connectivity")
        } else {
            print("❌ No network connectivity detected")
        }
        monitor.cancel()
    }
    
    monitor.start(queue: queue)
    
    // Test direct connection
    let connection = NWConnection(
        to: NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        ),
        using: .tcp
    )
    
    connection.stateUpdateHandler = { state in
        switch state {
        case .setup:
            print("⏳ Setting up connection...")
        case .waiting(let error):
            print("⏰ Connection waiting: \(error)")
        case .preparing:
            print("⏳ Preparing connection...")
        case .ready:
            print("✅ Successfully connected to \(host):\(port)")
            connection.cancel()
        case .failed(let error):
            print("❌ Connection failed: \(error)")
            if error.localizedDescription.contains("refused") {
                print("💡 This usually means no server is running on port \(port)")
            } else if error.localizedDescription.contains("timeout") {
                print("💡 Connection timed out - server might be slow or unreachable")
            }
            connection.cancel()
        case .cancelled:
            break
        @unknown default:
            print("❓ Unknown connection state")
        }
    }
    
    connection.start(queue: queue)
    
    // Wait a bit for connection test
    Thread.sleep(forTimeInterval: 3)
}

// 2. Test with a simple HTTP request
func testHTTPRequest(url: String) {
    print("\n🌐 Testing HTTP request to: \(url)")
    
    guard let requestURL = URL(string: url) else {
        print("❌ Invalid URL: \(url)")
        return
    }
    
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 10
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("BlueBoxy-Debug/1.0", forHTTPHeaderField: "User-Agent")
    
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ HTTP Request failed: \(error.localizedDescription)")
            if error.localizedDescription.contains("timeout") {
                print("💡 Request timed out after 10 seconds")
            } else if error.localizedDescription.contains("could not connect") {
                print("💡 Could not connect to server - make sure backend is running")
            }
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ HTTP Response received: \(httpResponse.statusCode)")
            print("📋 Headers: \(httpResponse.allHeaderFields)")
            
            if let data = data, !data.isEmpty {
                let responseString = String(data: data, encoding: .utf8) ?? "<binary data>"
                print("📄 Response body (first 500 chars): \(String(responseString.prefix(500)))")
            }
        }
    }
    
    task.resume()
    semaphore.wait()
}

// Run diagnostics
print("\n🔧 Running diagnostics for BlueBoxy backend...")

// Test basic connectivity
checkPortConnectivity(host: "localhost", port: 3001)

// Test HTTP endpoints
let baseURL = "http://localhost:3001"
let testEndpoints = [
    "\(baseURL)/health",
    "\(baseURL)/api/health", 
    "\(baseURL)/api/auth/register",
    "\(baseURL)/"
]

for endpoint in testEndpoints {
    testHTTPRequest(url: endpoint)
    Thread.sleep(forTimeInterval: 1) // Brief pause between requests
}

print("\n🎯 Diagnosis and Solutions:")
print("==========================")
print("If you're seeing connection failures:")
print("1️⃣  Make sure your backend server is running on localhost:3001")
print("2️⃣  Check if the backend has the /api/auth/register endpoint")
print("3️⃣  Verify your backend accepts JSON requests with correct headers")
print("4️⃣  Consider increasing timeout values if server is slow")
print("5️⃣  Test backend directly with curl: curl -X POST http://localhost:3001/api/auth/register")

print("\n📝 Common fixes:")
print("• Start your backend server: npm start / yarn start / docker-compose up")
print("• Change BASE_URL in Debug.xcconfig if using different host/port")
print("• Add CORS headers if testing from browser")
print("• Check firewall settings blocking port 3001")

print("\n✨ Diagnostics complete!")