//
//  PreviewData.swift
//  BlueBoxy
//
//  Preview data provider using fixtures for SwiftUI previews
//  Provides sample data for all major models using real API responses
//

import Foundation

#if DEBUG
/// Preview data provider using real API fixture data
enum PreviewData {
    
    // MARK: - Core Loading Methods
    
    /// Load JSON preview data from the app bundle
    /// - Parameters:
    ///   - filename: The filename (with or without .json extension)
    ///   - type: The type to decode to (can be inferred)
    /// - Returns: Decoded object of the specified type
    static func load<T: Decodable>(_ filename: String, as type: T.Type = T.self) -> T {
        let components = filename.split(separator: ".")
        let name = String(components[0])
        let ext = components.count > 1 ? String(components[1]) : "json"
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("Missing preview resource: \(filename). Make sure the file is added to the app bundle.")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode preview data from \(filename): \(error)")
        }
    }
    
    /// Load raw JSON data as a dictionary for flexible parsing
    /// - Parameter filename: The JSON filename
    /// - Returns: JSON dictionary
    static func loadJSON(_ filename: String) -> [String: Any] {
        let components = filename.split(separator: ".")
        let name = String(components[0])
        let ext = components.count > 1 ? String(components[1]) : "json"
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("Missing preview resource: \(filename)")
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fatalError("Invalid JSON format in \(filename)")
            }
            return json
        } catch {
            fatalError("Failed to load JSON from \(filename): \(error)")
        }
    }
    
    /// Check if a preview file exists
    /// - Parameter filename: The filename to check
    /// - Returns: True if file exists in bundle
    static func fileExists(_ filename: String) -> Bool {
        let components = filename.split(separator: ".")
        let name = String(components[0])
        let ext = components.count > 1 ? String(components[1]) : "json"
        return Bundle.main.url(forResource: name, withExtension: ext) != nil
    }
    
    // MARK: - Safe Loading with Fallbacks
    
    /// Helper to safely load fixtures in previews with fallback
    private static func safeLoad<T>(_ loader: () throws -> T, fallback: T) -> T {
        do {
            return try loader()
        } catch {
            print("⚠️ Preview fixture loading failed: \(error.localizedDescription)")
            return fallback
        }
    }
    
    // MARK: - Fixture-Based Preview Data
    
    /// Load user data from auth fixture
    static var user: User {
        safeLoad({
            let domainUser = try FixtureLoader.loadAuthMe().user
            return BasicUser(
                id: domainUser.id,
                email: domainUser.email,
                name: domainUser.name,
                createdAt: domainUser.createdAt,
                updatedAt: domainUser.updatedAt,
                lastLoginAt: domainUser.lastLoginAt
            )
        }, fallback: BasicUser(
            id: 1,
            email: "preview@example.com",
            name: "Preview User",
            createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
            updatedAt: Date().addingTimeInterval(-86400), // 1 day ago
            lastLoginAt: Date() // now
        ))
    }
    
    /// Load activities from fixture
    static var activities: [Activity] {
        safeLoad({
            try FixtureLoader.loadActivitiesList()
        }, fallback: [
            Activity(
                id: 1,
                name: "Preview Coffee Shop",
                description: "A cozy place perfect for meaningful conversations",
                category: "dining",
                location: "Downtown",
                rating: 4.8,
                distance: "0.3 miles",
                personalityMatch: "Thoughtful Harmonizer",
                imageUrl: "https://images.unsplash.com/photo-1559056199-641a0ac8b55e"
            )
        ])
    }
    
    /// Load messages from fixture
    static var messages: [MessageItem] {
        safeLoad({
            try FixtureLoader.loadMessageGeneration().messages
        }, fallback: [
            MessageItem(
                id: "preview_123",
                content: "Preview message content that shows appreciation",
                category: "appreciation",
                personalityMatch: "Thoughtful Harmonizer",
                tone: "warm",
                estimatedImpact: "high",
                createdAt: Date()
            )
        ])
    }
    
    /// Load calendar events from fixture
    static var calendarEvents: [CalendarEventDB] {
        safeLoad({
            try FixtureLoader.loadEventsList()
        }, fallback: [
            CalendarEventDB(
                id: 1,
                userId: 1,
                title: "Preview Date Night",
                description: "Romantic dinner",
                location: "Downtown",
                startTime: "2025-01-01T19:00:00Z",
                endTime: "2025-01-01T21:00:00Z",
                allDay: false,
                eventType: "date",
                status: "scheduled",
                externalEventId: nil,
                calendarProvider: nil,
                reminders: nil,
                metadata: nil,
                createdAt: "2025-01-01T10:00:00Z",
                updatedAt: "2025-01-01T10:00:00Z"
            )
        ])
    }
    
    /// Load recommendations from fixture
    static var recommendations: [SimpleRecommendation] {
        safeLoad({
            try FixtureLoader.loadSimpleRecommendations()
        }, fallback: [
            SimpleRecommendation(
                title: "Preview Activity",
                description: "A great activity for couples",
                category: "relaxed"
            )
        ])
    }
    
    /// Load calendar providers from fixture
    static var calendarProviders: [CalendarProvider] {
        safeLoad({
            try FixtureLoader.loadCalendarProviders()
        }, fallback: [
            CalendarProvider(
                id: "google",
                name: "google",
                displayName: "Google Calendar",
                icon: "calendar",
                description: "Connect your Google Calendar",
                isConnected: false,
                status: "inactive",
                authUrl: "https://auth.google.com/calendar",
                lastSync: nil,
                errorMessage: nil
            )
        ])
    }
    
    /// Load user stats from fixture
    static var userStats: UserStatsResponse {
        safeLoad({
            try FixtureLoader.loadUserStats()
        }, fallback: UserStatsResponse(
            eventsCreated: 5,
            id: 1,
            userId: 1,
            createdAt: "2025-01-01T10:00:00Z",
            updatedAt: "2025-01-01T10:00:00Z"
        ))
    }
    
    /// Single activity for detail views
    static var sampleActivity: Activity {
        activities.first ?? Activity(
            id: 1,
            name: "Sample Activity",
            description: "Sample description",
            category: "dining",
            location: "Sample Location",
            rating: 4.5,
            distance: "1.0 miles",
            personalityMatch: "Sample Match",
            imageUrl: nil
        )
    }
    
    /// Single message for detail views
    static var sampleMessage: MessageItem {
        messages.first ?? MessageItem(
            id: "sample_123",
            content: "Sample message content",
            category: "appreciation",
            personalityMatch: "Sample Match",
            tone: "warm",
            estimatedImpact: "medium",
            createdAt: Date()
        )
    }
}
#endif
