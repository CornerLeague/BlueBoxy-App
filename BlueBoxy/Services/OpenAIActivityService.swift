//
//  OpenAIActivityService.swift
//  BlueBoxy
//
//  OpenAI integration for personalized activity discovery with geolocation-based recommendations
//

import Foundation
import CoreLocation

// MARK: - OpenAI API Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case max_tokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - Activity Discovery Models

struct GeolocationActivityCriteria: Codable {
    let location: GeolocationCoordinates?
    let cityName: String?
    let radius: Double // in miles
    let personalityType: String?
    let relationshipDuration: String?
    let idealActivities: [String]
    let priceRange: String? // "free", "budget", "moderate", "premium"
    let category: String? // "romantic", "active", "cultural", etc.
    let timeOfDay: String? // "morning", "afternoon", "evening"
    let season: String? // "spring", "summer", "fall", "winter"
    
    // Convenience initializer for CLLocationCoordinate2D
    init(location: CLLocationCoordinate2D? = nil,
         cityName: String? = nil,
         radius: Double,
         personalityType: String? = nil,
         relationshipDuration: String? = nil,
         idealActivities: [String],
         priceRange: String? = nil,
         category: String? = nil,
         timeOfDay: String? = nil,
         season: String? = nil) {
        
        self.location = location.map { GeolocationCoordinates(latitude: $0.latitude, longitude: $0.longitude) }
        self.cityName = cityName
        self.radius = radius
        self.personalityType = personalityType
        self.relationshipDuration = relationshipDuration
        self.idealActivities = idealActivities
        self.priceRange = priceRange
        self.category = category
        self.timeOfDay = timeOfDay
        self.season = season
    }
    
    enum CodingKeys: String, CodingKey {
        case location, radius, idealActivities, priceRange, category, season
        case cityName = "city_name"
        case personalityType = "personality_type"
        case relationshipDuration = "relationship_duration"
        case timeOfDay = "time_of_day"
    }
}

struct GeolocationCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

struct OpenAIActivityRecommendation: Codable {
    let name: String
    let description: String
    let category: String
    let location: String
    let estimated_cost: String
    let duration: String
    let best_time_of_day: String
    let personality_match: String
    let why_recommended: String
    let tips: [String]
    let alternatives: [String]
    
    enum CodingKeys: String, CodingKey {
        case name, description, category, location, duration, tips, alternatives
        case estimated_cost = "estimated_cost"
        case best_time_of_day = "best_time_of_day"
        case personality_match = "personality_match"
        case why_recommended = "why_recommended"
    }
}

struct OpenAIActivitiesResponse: Codable {
    let recommendations: [OpenAIActivityRecommendation]
    let search_context: String
    let personality_insights: String
    let location_notes: String
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case search_context = "search_context"
        case personality_insights = "personality_insights"
        case location_notes = "location_notes"
    }
}

// MARK: - OpenAI Activity Service

@MainActor
class OpenAIActivityService: ObservableObject {
    static let shared = OpenAIActivityService()
    
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1"
    private var apiKey: String { AppConfig.openAIConfig.apiKey }
    
    // MARK: - Configuration
    
    private let defaultModel = "gpt-4" // or "gpt-3.5-turbo" for faster/cheaper responses
    private let maxRetries = 2
    private let timeout: TimeInterval = 75 // Allow extra time for GPT-4 responses
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Activity Discovery
    
    /// Find personalized activities using OpenAI with geolocation
    func findActivities(
        criteria: GeolocationActivityCriteria,
        userPersonality: PersonalityInsight?
    ) async throws -> OpenAIActivitiesResponse {
        
        let prompt = buildActivityPrompt(criteria: criteria, personality: userPersonality)
        
        let request = OpenAIRequest(
            model: defaultModel,
            messages: [
                OpenAIMessage(role: "system", content: getSystemPrompt()),
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            max_tokens: 1500
        )
        
        let response = try await makeOpenAIRequest(request)
        return try parseActivitiesResponse(response)
    }
    
    /// Get activity recommendations based on current trends and user preferences with geolocation
    func getPersonalizedRecommendations(
        for user: DomainUser,
        location: CLLocationCoordinate2D?,
        preferences: [String] = []
    ) async throws -> [OpenAIActivityRecommendation] {
        
        let criteria = GeolocationActivityCriteria(
            location: location,
            cityName: user.typedLocation?.city,
            radius: 25.0, // 25 mile radius
            personalityType: user.personalityType,
            relationshipDuration: user.relationshipDuration,
            idealActivities: user.personalityInsight?.idealActivities ?? [],
            priceRange: nil,
            category: nil,
            timeOfDay: nil,
            season: getCurrentSeason()
        )
        
        let response = try await findActivities(criteria: criteria, userPersonality: user.personalityInsight)
        return response.recommendations
    }
    
    // MARK: - Private Methods
    
    private func makeOpenAIRequest(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenAIActivityError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw OpenAIActivityError.apiError(httpResponse.statusCode, errorMessage)
                }
                
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                return openAIResponse
                
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? OpenAIActivityError.networkError
    }
    
    private func buildActivityPrompt(criteria: GeolocationActivityCriteria, personality: PersonalityInsight?) -> String {
        var prompt = "I need personalized activity recommendations for a couple based on these criteria:\n\n"
        
        // Location information
        if let cityName = criteria.cityName {
            prompt += "📍 Location: \(cityName)\n"
        } else if let location = criteria.location {
            prompt += "📍 Coordinates: \(location.latitude), \(location.longitude)\n"
        }
        prompt += "📏 Search radius: \(Int(criteria.radius)) miles\n\n"
        
        // User preferences
        if let personalityType = criteria.personalityType {
            prompt += "🧠 Personality Type: \(personalityType)\n"
        }
        
        if let relationshipDuration = criteria.relationshipDuration {
            prompt += "💑 Relationship Duration: \(relationshipDuration)\n"
        }
        
        if !criteria.idealActivities.isEmpty {
            prompt += "✨ Ideal Activities: \(criteria.idealActivities.joined(separator: ", "))\n"
        }
        
        if let personality = personality {
            prompt += "❤️ Love Language: \(personality.loveLanguage)\n"
            prompt += "🗣️ Communication Style: \(personality.communicationStyle)\n"
        }
        
        // Additional filters
        if let priceRange = criteria.priceRange {
            prompt += "💰 Price Range: \(priceRange)\n"
        }
        
        if let category = criteria.category {
            prompt += "🏷️ Category Preference: \(category)\n"
        }
        
        if let timeOfDay = criteria.timeOfDay {
            prompt += "⏰ Time of Day: \(timeOfDay)\n"
        }
        
        if let season = criteria.season {
            prompt += "🌸 Season: \(season)\n"
        }
        
        prompt += "\n"
        prompt += "Please respond with ONLY a valid JSON object (no markdown, no code blocks) with this exact structure:\n"
        prompt += """
        {
            \"recommendations\": [
                {
                    \"name\": \"Activity Name\",
                    \"description\": \"Detailed description\",
                    \"category\": \"romantic|active|cultural|dining\",
                    \"location\": \"Specific venue and address\",
                    \"estimated_cost\": \"$XX-$XX per person\",
                    \"duration\": \"X-X hours\",
                    \"best_time_of_day\": \"morning|afternoon|evening\",
                    \"personality_match\": \"Why this matches their personality\",
                    \"why_recommended\": \"Why this specific activity\",
                    \"tips\": [\"tip1\", \"tip2\"],
                    \"alternatives\": [\"alternative1\", \"alternative2\"]
                }
            ],
            \"search_context\": \"Brief summary of search parameters\",
            \"personality_insights\": \"How their personality influences these recommendations\",
            \"location_notes\": \"General notes about the location\"
        }
        """
        
        return prompt
    }
    
    private func getSystemPrompt() -> String {
        return """
        You are an expert relationship coach and local activity curator with deep knowledge of personality psychology and couple dynamics. Your role is to recommend meaningful, personalized activities for couples based on their personality types, relationship stage, and specific geolocation.
        
        Key principles:
        - Tailor recommendations to personality types and communication styles
        - Consider the relationship duration and suggest appropriate intimacy levels
        - Include practical details like cost, duration, and timing
        - Provide actionable tips for making each activity special
        - Focus on experiences that build connection and create lasting memories
        - Always respond with valid JSON in the exact OpenAIActivitiesResponse format
        
        When making recommendations:
        - Be specific about venues and locations in the given area
        - Provide realistic cost estimates
        - Consider accessibility and practical logistics
        - Offer alternatives for different preferences
        - Explain the psychological benefits of each activity
        
        Return ONLY valid JSON without any markdown code blocks or additional text.
        """
    }
    
    private func parseActivitiesResponse(_ response: OpenAIResponse) throws -> OpenAIActivitiesResponse {
        guard let firstChoice = response.choices.first else {
            throw OpenAIActivityError.noResponse
        }
        
        let content = firstChoice.message.content
        print("🔧 Debug: OpenAI raw response content:\n\(content)")
        
        // Try to extract JSON from the response
        guard let jsonData = extractJSON(from: content) else {
            throw OpenAIActivityError.invalidJSONResponse
        }
        
        print("🔧 Debug: Extracted JSON:\n\(String(data: jsonData, encoding: .utf8) ?? "Unable to decode")")
        
        do {
            let activitiesResponse = try JSONDecoder().decode(OpenAIActivitiesResponse.self, from: jsonData)
            return activitiesResponse
        } catch {
            print("🔧 Debug: Decoding error details: \(error)")
            throw OpenAIActivityError.decodingError(error)
        }
    }
    
    private func extractJSON(from text: String) -> Data? {
        // Try to find JSON by looking for opening and closing braces
        if let startBrace = text.firstIndex(of: "{"),
           let endBrace = text.lastIndex(of: "}") {
            let jsonString = String(text[startBrace...endBrace])
            return jsonString.data(using: .utf8)
        }
        
        // If no markers found, assume entire response is JSON
        return text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
    }
    
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "spring"
        case 6...8: return "summer"
        case 9...11: return "fall"
        default: return "winter"
        }
    }
}

// MARK: - Error Types

enum OpenAIActivityError: Error, LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case networkError
    case noResponse
    case invalidJSONResponse
    case decodingError(Error)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let code, let message):
            return "OpenAI API error (\(code)): \(message)"
        case .networkError:
            return "Network error communicating with OpenAI"
        case .noResponse:
            return "No response received from OpenAI"
        case .invalidJSONResponse:
            return "Could not parse JSON response from OpenAI"
        case .decodingError(let error):
            return "Error decoding OpenAI response: \(error.localizedDescription)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
