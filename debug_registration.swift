#!/usr/bin/env swift

import Foundation

// Debug registration issue by testing exact iOS app flow

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String?
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name
        case partnerName = "partner_name"
        case relationshipDuration = "relationship_duration"
        case partnerAge = "partner_age"
    }
}

struct AuthResponse: Decodable {
    let user: User
    let token: String?
    let refreshToken: String?
    
    struct User: Decodable {
        let id: Int
        let email: String
        let name: String
        let partnerName: String?
        let relationshipDuration: String?
        let partnerAge: Int?
        let createdAt: String?
        let updatedAt: String?
        let lastLoginAt: String?
        
        enum CodingKeys: String, CodingKey {
            case id, email, name
            case partnerName = "partnerName"
            case relationshipDuration = "relationshipDuration"
            case partnerAge = "partnerAge"
            case createdAt, updatedAt, lastLoginAt
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case user, token
        case refreshToken = "refresh_token"
    }
}

func testRegistration() async {
    print("🔍 Testing Registration Flow (iOS App Style)")
    print("=" + String(repeating: "=", count: 50))
    
    // Create request exactly like iOS app
    let request = RegisterRequest(
        email: "iostest-\(Int.random(in: 1000...9999))@example.com",
        password: "password123",
        name: "iOS Test User",
        partnerName: "iOS Partner",
        relationshipDuration: "3 years", 
        partnerAge: 30
    )
    
    // Build URL and request like APIClient does
    let baseURL = URL(string: "http://localhost:3001")!
    let url = baseURL.appendingPathComponent("api/auth/register")
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("BlueBoxy iOS/1.0.0 (1)", forHTTPHeaderField: "User-Agent")
    
    // Encode request body
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .useDefaultKeys
    encoder.dateEncodingStrategy = .iso8601
    
    do {
        let jsonData = try encoder.encode(request)
        urlRequest.httpBody = jsonData
        
        // Log the request
        print("📤 Request URL: \(url)")
        print("📤 Request Method: POST")
        print("📤 Request Headers:")
        urlRequest.allHTTPHeaderFields?.forEach { key, value in
            print("   \(key): \(value)")
        }
        if let bodyData = urlRequest.httpBody {
            print("📤 Request Body (\(bodyData.count) bytes):")
            if let bodyString = String(data: bodyData, encoding: .utf8) {
                print(bodyString)
            }
        }
        print("")
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 Response Status: \(httpResponse.statusCode)")
            print("📥 Response Headers:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("   \(key): \(value)")
            }
        }
        
        print("📥 Response Body (\(data.count) bytes):")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        print("")
        
        // Try to decode response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let authResponse = try decoder.decode(AuthResponse.self, from: data)
            print("✅ Successfully decoded response!")
            print("   User ID: \(authResponse.user.id)")
            print("   User Email: \(authResponse.user.email)")
            print("   User Name: \(authResponse.user.name)")
            print("   Token: \(authResponse.token?.prefix(20) ?? "nil")...")
            
        } catch {
            print("❌ Failed to decode response: \(error)")
            
            // Try to decode as error
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                print("   Server error: \(errorMessage)")
            }
        }
        
    } catch {
        print("❌ Request failed: \(error)")
        if let urlError = error as? URLError {
            print("   URL Error Code: \(urlError.code)")
            print("   URL Error Description: \(urlError.localizedDescription)")
        }
    }
}

// Run the test
let task = Task {
    await testRegistration()
}

// Wait for completion
RunLoop.main.run(until: Date().addingTimeInterval(5))