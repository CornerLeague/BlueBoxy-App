#!/usr/bin/env swift

import Foundation

// Quick test that exactly mimics your iOS app's registration flow
print("🚀 Quick Registration Test - iOS App Flow")
print("=" + String(repeating: "=", count: 50))

// Step 1: Verify configuration
print("\n📋 Step 1: Checking Configuration...")
let baseURLString = "http://192.168.1.41:3001"
print("   Base URL: \(baseURLString)")

guard let baseURL = URL(string: baseURLString) else {
    print("❌ Invalid base URL")
    exit(1)
}

// Step 2: Test APIConfiguration-style URL building
print("\n🔧 Step 2: Testing URL Building...")
guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
    print("❌ Failed to create URL components")
    exit(1)
}

let cleanPath = "api/auth/register"
if components.path.hasSuffix("/") {
    components.path += cleanPath
} else {
    components.path += "/\(cleanPath)"
}

guard let finalURL = components.url else {
    print("❌ Failed to build final URL")
    exit(1)
}

print("   Final URL: \(finalURL)")

// Step 3: Create exact RegistrationRequest like your app
print("\n📝 Step 3: Creating Registration Request...")

struct RegistrationRequest: Encodable {
    let email: String
    let password: String
    let name: String?
    let partnerName: String?
    let personalityType: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name
        case partnerName = "partner_name"
        case personalityType = "personality_type"
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
    }
}

let request = RegistrationRequest(
    email: "quicktest-\(Int.random(in: 1000...9999))@example.com",
    password: "testpassword123",
    name: "Quick Test User",
    partnerName: "Test Partner",
    personalityType: nil, // AuthViewModel passes nil
    relationshipDuration: "2 years",
    partnerAge: 25
)

print("   Email: \(request.email)")
print("   Name: \(request.name ?? "nil")")
print("   Partner Name: \(request.partnerName ?? "nil")")

// Step 4: Create URLRequest exactly like APIClient
print("\n🌐 Step 4: Creating URLRequest...")

var urlRequest = URLRequest(url: finalURL)
urlRequest.httpMethod = "POST"

// Add exact headers from APIConfiguration
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
urlRequest.setValue("BlueBoxy iOS/1.0.0 (1)", forHTTPHeaderField: "User-Agent")

// Encode with exact same settings as APIConfiguration
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .useDefaultKeys
encoder.dateEncodingStrategy = .iso8601
#if DEBUG
encoder.outputFormatting = .prettyPrinted
#endif

do {
    let jsonData = try encoder.encode(request)
    urlRequest.httpBody = jsonData
    
    print("   Method: \(urlRequest.httpMethod ?? "nil")")
    print("   Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
    print("   Body size: \(jsonData.count) bytes")
    
    if let bodyString = String(data: jsonData, encoding: .utf8) {
        print("   Body preview: \(bodyString.prefix(100))...")
    }
    
} catch {
    print("❌ Failed to encode request: \(error)")
    exit(1)
}

// Step 5: Make request with exact same session configuration
print("\n🚀 Step 5: Making Request...")

// Create URLSession with same config as APIConfiguration
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 20
configuration.timeoutIntervalForResource = 60
configuration.waitsForConnectivity = true
configuration.allowsCellularAccess = true
configuration.allowsExpensiveNetworkAccess = true
configuration.allowsConstrainedNetworkAccess = true
configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

let session = URLSession(configuration: configuration)

let semaphore = DispatchSemaphore(value: 0)
var testResult: (success: Bool, message: String)?

let task = session.dataTask(with: urlRequest) { data, response, error in
    defer { semaphore.signal() }
    
    if let error = error {
        print("❌ Request failed: \(error)")
        if let urlError = error as? URLError {
            print("   URLError code: \(urlError.code)")
            print("   URLError description: \(urlError.localizedDescription)")
            
            switch urlError.code {
            case .cannotConnectToHost:
                testResult = (false, "Cannot connect to host - check server and network")
            case .timedOut:
                testResult = (false, "Request timed out - server might be slow")
            case .notConnectedToInternet:
                testResult = (false, "No internet connection")
            default:
                testResult = (false, "Network error: \(urlError.localizedDescription)")
            }
        } else {
            testResult = (false, "Unknown error: \(error.localizedDescription)")
        }
        return
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
        testResult = (false, "Invalid HTTP response")
        return
    }
    
    print("📥 Response received:")
    print("   Status: \(httpResponse.statusCode)")
    print("   Headers: \(httpResponse.allHeaderFields)")
    
    guard let data = data else {
        testResult = (false, "No response data")
        return
    }
    
    print("   Data size: \(data.count) bytes")
    
    if let responseString = String(data: data, encoding: .utf8) {
        print("   Response: \(responseString)")
    }
    
    if httpResponse.statusCode == 201 {
        testResult = (true, "Registration successful!")
    } else {
        testResult = (false, "Server returned status \(httpResponse.statusCode)")
    }
}

print("⏳ Sending request...")
let startTime = Date()
task.resume()

// Wait up to 30 seconds for response
let waitResult = semaphore.wait(timeout: .now() + 30)

if waitResult == .timedOut {
    print("⏰ Test timed out after 30 seconds")
    task.cancel()
    exit(1)
}

let duration = Date().timeIntervalSince(startTime)
print("⏱️ Request completed in \(String(format: "%.2f", duration)) seconds")

// Step 6: Results
print("\n🎯 Step 6: Results")
if let result = testResult {
    if result.success {
        print("✅ \(result.message)")
        print("   The iOS app should be able to register successfully!")
        print("   If it's still failing, the issue might be in:")
        print("   - Session/token handling after successful registration")
        print("   - UI state management")
        print("   - Error display logic")
    } else {
        print("❌ \(result.message)")
        print("   This explains why your iOS app registration is failing.")
        print("   Check the specific error above for the solution.")
    }
} else {
    print("❓ Unexpected result - no test outcome recorded")
}