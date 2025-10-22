#!/usr/bin/env swift

import Foundation

print("🔍 Complete Registration Flow Test")
print("=" + String(repeating: "=", count: 50))

// Simulate the exact same registration flow as AuthViewModel
func testCompleteRegistrationFlow() async {
    // Step 1: Test basic connectivity
    print("\n📡 Step 1: Testing basic connectivity...")
    do {
        let url = URL(string: "http://localhost:3001/api/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ Health check: HTTP \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response: \(responseString)")
            }
        }
    } catch {
        print("❌ Health check failed: \(error)")
        return
    }
    
    // Step 2: Test registration endpoint structure
    print("\n📡 Step 2: Testing registration endpoint structure...")
    
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
    
    struct DomainUser: Decodable {
        let id: Int
        let email: String
        let name: String
        let partnerName: String?
        let relationshipDuration: String?
        let partnerAge: Int?
        let personalityType: String?
        let createdAt: String?
        let updatedAt: String?
        let lastLoginAt: String?
        
        enum CodingKeys: String, CodingKey {
            case id, email, name
            case partnerName, relationshipDuration, partnerAge, personalityType
            case createdAt, updatedAt, lastLoginAt
        }
    }
    
    struct AuthEnvelope: Decodable {
        let user: DomainUser
        let token: String?
        let refreshToken: String?
        
        enum CodingKeys: String, CodingKey {
            case user, token
            case refreshToken = "refresh_token"
        }
    }
    
    // Create the exact request that AuthViewModel would create
    let registrationRequest = RegistrationRequest(
        email: "flowtest-\(Int.random(in: 1000...9999))@example.com",
        password: "testpassword123",
        name: "Flow Test User",
        partnerName: "Test Partner",
        personalityType: nil, // AuthViewModel passes nil for this
        relationshipDuration: "2 years",
        partnerAge: 28
    )
    
    print("📤 Creating registration request:")
    print("   Email: \(registrationRequest.email)")
    print("   Password: [HIDDEN]")
    print("   Name: \(registrationRequest.name ?? "nil")")
    print("   Partner Name: \(registrationRequest.partnerName ?? "nil")")
    print("   Relationship Duration: \(registrationRequest.relationshipDuration ?? "nil")")
    print("   Partner Age: \(registrationRequest.partnerAge?.description ?? "nil")")
    
    // Step 3: Make the exact same request as APIClient would
    print("\n📡 Step 3: Making registration request...")
    
    let baseURL = URL(string: "http://localhost:3001")!
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    
    // Handle path like APIClient does
    let cleanPath = "api/auth/register"
    if components.path.hasSuffix("/") {
        components.path += cleanPath
    } else {
        components.path += "/\(cleanPath)"
    }
    
    guard let url = components.url else {
        print("❌ Invalid URL")
        return
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    
    // Add default headers like APIConfiguration does
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("BlueBoxy iOS/1.0.0 (1)", forHTTPHeaderField: "User-Agent")
    
    // Encode body like APIClient does
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .useDefaultKeys
    encoder.dateEncodingStrategy = .iso8601
    
    do {
        let jsonData = try encoder.encode(registrationRequest)
        urlRequest.httpBody = jsonData
        
        print("📤 Final request details:")
        print("   URL: \(url)")
        print("   Method: \(urlRequest.httpMethod ?? "nil")")
        print("   Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        print("   Body size: \(jsonData.count) bytes")
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\n📥 Response received:")
            print("   Status: \(httpResponse.statusCode)")
            print("   Headers: \(httpResponse.allHeaderFields)")
            print("   Body size: \(data.count) bytes")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Body content: \(responseString)")
            }
            
            // Step 4: Try to decode like AuthViewModel would
            print("\n🔍 Step 4: Decoding response...")
            
            if (200..<300).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .useDefaultKeys
                decoder.dateDecodingStrategy = .iso8601
                
                do {
                    let authResponse = try decoder.decode(AuthEnvelope.self, from: data)
                    print("✅ Successfully decoded AuthEnvelope!")
                    print("   User ID: \(authResponse.user.id)")
                    print("   User Email: \(authResponse.user.email)")
                    print("   User Name: \(authResponse.user.name)")
                    print("   Token present: \(authResponse.token != nil)")
                    print("   Token length: \(authResponse.token?.count ?? 0)")
                    print("   RefreshToken present: \(authResponse.refreshToken != nil)")
                    
                    // Step 5: Test token validation
                    if let token = authResponse.token, !token.isEmpty {
                        print("\n🔍 Step 5: Token validation...")
                        print("✅ Token is not empty")
                        print("   Token preview: \(String(token.prefix(20)))...")
                    } else {
                        print("\n❌ Step 5: Token validation failed - token is nil or empty")
                    }
                    
                } catch {
                    print("❌ Failed to decode AuthEnvelope: \(error)")
                    
                    // Try to understand what we got
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("   Raw JSON keys: \(Array(json.keys))")
                        if let user = json["user"] as? [String: Any] {
                            print("   User keys: \(Array(user.keys))")
                        }
                    }
                }
            } else {
                print("❌ Non-success status code: \(httpResponse.statusCode)")
                
                // Try to decode error
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    print("   Server error: \(error)")
                }
            }
        } else {
            print("❌ Invalid HTTP response")
        }
        
    } catch {
        print("❌ Request failed with error: \(error)")
        
        if let urlError = error as? URLError {
            print("   URLError code: \(urlError.code)")
            print("   URLError description: \(urlError.localizedDescription)")
            
            switch urlError.code {
            case .cannotConnectToHost:
                print("   💡 Cannot connect to host - is your server running on localhost:3001?")
            case .timedOut:
                print("   💡 Request timed out - server might be slow or unreachable")
            case .notConnectedToInternet:
                print("   💡 No internet connection")
            default:
                print("   💡 Check network connectivity and server status")
            }
        }
    }
}

// Run the test
Task {
    await testCompleteRegistrationFlow()
}

// Keep script alive
RunLoop.main.run(until: Date().addingTimeInterval(10))