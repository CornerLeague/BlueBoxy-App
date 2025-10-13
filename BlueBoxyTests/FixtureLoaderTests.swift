//
//  FixtureLoaderTests.swift
//  BlueBoxyTests
//
//  Tests to verify the fixture loading infrastructure works correctly
//

import Testing
import Foundation
@testable import BlueBoxy

struct FixtureLoaderTests {
    
    @Test func testFixtureLoaderCanLoadJSON() async throws {
        // Test that FixtureLoader can load and parse JSON
        // Use a simple decodable struct instead of [String: Any] which doesn't conform to Decodable
        struct TestJSON: Decodable {
            let user: [String: AnyDecodable]
        }
        
        let data = try FixtureLoader.load("Fixtures/auth/me_success", as: TestJSON.self)
        #expect(data.user.isEmpty == false)
    }
    
    @Test func testAllRequiredFixturesExist() async throws {
        // Verify all required fixture files are present and loadable
        let requiredFixtures = [
            "Fixtures/auth/me_success",
            "Fixtures/messages/generate_success", 
            "Fixtures/activities/list_success",
            "Fixtures/events/create_success",
            "Fixtures/recommendations/ai_powered_success"
        ]
        
        let bundle = Bundle(for: FixtureLoader.self)
        
        for fixture in requiredFixtures {
            let url = bundle.url(forResource: fixture, withExtension: "json")
            #expect(url != nil, "Missing fixture: \(fixture).json")
            
            if let url = url {
                let data = try Data(contentsOf: url)
                #expect(data.count > 0, "Empty fixture: \(fixture).json")
                
                // Verify it's valid JSON
                let json = try JSONSerialization.jsonObject(with: data)
                #expect(json != nil, "Invalid JSON in fixture: \(fixture).json")
            }
        }
    }
    
    @Test func testFixtureLoaderHandlesDecodingErrors() async throws {
        // Test that FixtureLoader properly propagates decoding errors
        struct InvalidModel: Decodable {
            let nonExistentField: String
        }
        
        // This should throw a decoding error
        do {
            let _ = try FixtureLoader.load("Fixtures/auth/me_success", as: InvalidModel.self)
            #expect(Bool(false), "Should have thrown decoding error")
        } catch {
            // Expected to throw - test passes
            #expect(true)
        }
    }
}