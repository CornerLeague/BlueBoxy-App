//
//  FixtureLoader.swift
//  BlueBoxyTests
//
//  Utility for loading JSON fixture data in tests
//  Provides type-safe loading with proper error handling
//

import XCTest
import Foundation
@testable import BlueBoxy

/// Utility class for loading test fixtures with proper error handling
final class FixtureLoader {
    
    /// Load JSON fixture and decode to specified type
    /// - Parameters:
    ///   - name: Name of the fixture file (without .json extension)
    ///   - type: Type to decode to (inferred if not specified)
    ///   - bundle: Bundle to search in (defaults to test bundle)
    /// - Returns: Decoded object of specified type
    /// - Throws: Loading or decoding errors
    static func load<T: Decodable>(
        _ name: String, 
        as type: T.Type = T.self,
        from bundle: Bundle? = nil
    ) throws -> T {
        let testBundle = bundle ?? Bundle(for: Self.self)
        
        // Look for the fixture file
        guard let url = testBundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.fileNotFound(name)
        }
        
        // Load data from file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FixtureError.loadError(name, error)
        }
        
        // Decode with proper strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw FixtureError.decodeError(name, type, error)
        }
    }
    
    /// Load raw JSON data without decoding
    /// - Parameters:
    ///   - name: Name of the fixture file (without .json extension)
    ///   - bundle: Bundle to search in (defaults to test bundle)
    /// - Returns: Raw Data from the file
    /// - Throws: Loading errors
    static func loadRaw(
        _ name: String,
        from bundle: Bundle? = nil
    ) throws -> Data {
        let testBundle = bundle ?? Bundle(for: Self.self)
        
        guard let url = testBundle.url(forResource: name, withExtension: "json") else {
            throw FixtureError.fileNotFound(name)
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            throw FixtureError.loadError(name, error)
        }
    }
    
    /// Load and parse as generic JSON object
    /// - Parameters:
    ///   - name: Name of the fixture file (without .json extension)  
    ///   - bundle: Bundle to search in (defaults to test bundle)
    /// - Returns: Parsed JSON as [String: Any]
    /// - Throws: Loading or parsing errors
    static func loadJSON(
        _ name: String,
        from bundle: Bundle? = nil
    ) throws -> [String: Any] {
        let data = try loadRaw(name, from: bundle)
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FixtureError.invalidJSON(name)
            }
            return json
        } catch {
            throw FixtureError.parseError(name, error)
        }
    }
    
    /// List all available fixtures in a directory
    /// - Parameters:
    ///   - directory: Directory path within the bundle (e.g., "auth", "messages")
    ///   - bundle: Bundle to search in (defaults to test bundle)
    /// - Returns: Array of fixture names (without extensions)
    static func listFixtures(
        in directory: String? = nil,
        from bundle: Bundle? = nil
    ) -> [String] {
        let testBundle = bundle ?? Bundle(for: Self.self)
        
        guard let resourcePath = testBundle.resourcePath else {
            return []
        }
        
        let searchPath = directory.map { "\(resourcePath)/\($0)" } ?? resourcePath
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: searchPath)
            return files
                .filter { $0.hasSuffix(".json") }
                .map { String($0.dropLast(5)) } // Remove .json extension
                .sorted()
        } catch {
            return []
        }
    }
    
    /// Validate that fixture can be loaded and decoded without throwing
    /// - Parameters:
    ///   - name: Name of the fixture file
    ///   - type: Type to decode to
    ///   - bundle: Bundle to search in
    /// - Returns: True if fixture loads and decodes successfully
    static func validate<T: Decodable>(
        _ name: String,
        as type: T.Type,
        from bundle: Bundle? = nil
    ) -> Bool {
        do {
            let _ = try load(name, as: type, from: bundle)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Fixture Errors

/// Errors that can occur during fixture loading
enum FixtureError: Error, LocalizedError {
    case fileNotFound(String)
    case loadError(String, Error)
    case decodeError(String, Any.Type, Error)
    case parseError(String, Error)
    case invalidJSON(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Fixture file '\(name).json' not found in test bundle"
        case .loadError(let name, let error):
            return "Failed to load fixture '\(name).json': \(error.localizedDescription)"
        case .decodeError(let name, let type, let error):
            return "Failed to decode fixture '\(name).json' as \(type): \(error.localizedDescription)"
        case .parseError(let name, let error):
            return "Failed to parse fixture '\(name).json' as JSON: \(error.localizedDescription)"
        case .invalidJSON(let name):
            return "Fixture '\(name).json' does not contain valid JSON object"
        }
    }
}

// MARK: - Convenience Extensions

extension FixtureLoader {
    
    /// Load auth fixtures
    static func loadAuth<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("auth/\(name)", as: type)
    }
    
    /// Load message fixtures  
    static func loadMessages<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("messages/\(name)", as: type)
    }
    
    /// Load activity fixtures
    static func loadActivities<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("activities/\(name)", as: type)
    }
    
    /// Load recommendation fixtures
    static func loadRecommendations<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("recommendations/\(name)", as: type)
    }
    
    /// Load event fixtures
    static func loadEvents<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("events/\(name)", as: type)
    }
    
    /// Load user fixtures
    static func loadUser<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("user/\(name)", as: type)
    }
    
    /// Load assessment fixtures
    static func loadAssessment<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("assessment/\(name)", as: type)
    }
    
    /// Load calendar fixtures
    static func loadCalendar<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        return try load("calendar/\(name)", as: type)
    }
}

// MARK: - Debug Utilities

#if DEBUG
extension FixtureLoader {
    
    /// Print all available fixtures for debugging
    static func debugPrintAllFixtures() {
        let categories = ["auth", "messages", "activities", "recommendations", "events", "user", "assessment", "calendar"]
        
        print("📋 Available Test Fixtures:")
        
        for category in categories {
            let fixtures = listFixtures(in: category)
            if !fixtures.isEmpty {
                print("  \(category):")
                for fixture in fixtures {
                    print("    - \(fixture)")
                }
            }
        }
        
        // Also list root level fixtures
        let rootFixtures = listFixtures()
        if !rootFixtures.isEmpty {
            print("  root:")
            for fixture in rootFixtures {
                print("    - \(fixture)")
            }
        }
    }
    
    /// Validate all fixtures can be parsed as JSON
    static func validateAllFixturesParseableAsJSON() -> Bool {
        let categories = ["auth", "messages", "activities", "recommendations", "events", "user", "assessment", "calendar"]
        var allValid = true
        
        for category in categories {
            let fixtures = listFixtures(in: category)
            for fixture in fixtures {
                do {
                    let _ = try loadJSON("\(category)/\(fixture)")
                } catch {
                    print("❌ Invalid JSON in \(category)/\(fixture): \(error)")
                    allValid = false
                }
            }
        }
        
        return allValid
    }
}
#endif