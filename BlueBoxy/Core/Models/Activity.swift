//
//  Activity.swift
//  BlueBoxy
//
//  Enhanced activity models with OpenAI integration and preference matching
//

import Foundation
import CoreLocation

// MARK: - Core Activity Model

struct Activity: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let category: String
    let location: String?
    let rating: Double?
    let distance: String?
    var personalityMatch: String?
    var personalityMatchScore: Double?
    let imageUrl: String?
    
    // Enhanced properties for AI recommendations
    let estimatedCost: String?
    let duration: String?
    let bestTimeOfDay: String?
    let whyRecommended: String?
    let tips: [String]?
    let alternatives: [String]?
    let coordinates: ActivityCoordinates?
    let tags: [String]?
    let ageAppropriate: String? // "all", "18+", "21+"
    let accessibility: String? // "wheelchair_accessible", "limited_mobility_friendly", etc.
    let seasonality: [String]? // ["spring", "summer", "fall", "winter"]
    let groupSize: String? // "intimate", "small_group", "large_group"
    
    // AI-generated insights
    let aiInsights: AIActivityInsights?
    let lastUpdated: Date?
    let isAIGenerated: Bool // Whether this came from AI or static data
    
    // Default initializer for backward compatibility
    init(id: Int, name: String, description: String, category: String, location: String? = nil, rating: Double? = nil, distance: String? = nil, personalityMatch: String? = nil, personalityMatchScore: Double? = nil, imageUrl: String? = nil, estimatedCost: String? = nil, duration: String? = nil, bestTimeOfDay: String? = nil, whyRecommended: String? = nil, tips: [String]? = nil, alternatives: [String]? = nil, coordinates: ActivityCoordinates? = nil, tags: [String]? = nil, ageAppropriate: String? = nil, accessibility: String? = nil, seasonality: [String]? = nil, groupSize: String? = nil, aiInsights: AIActivityInsights? = nil, lastUpdated: Date? = nil, isAIGenerated: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.location = location
        self.rating = rating
        self.distance = distance
        self.personalityMatch = personalityMatch
        self.personalityMatchScore = personalityMatchScore
        self.imageUrl = imageUrl
        self.estimatedCost = estimatedCost
        self.duration = duration
        self.bestTimeOfDay = bestTimeOfDay
        self.whyRecommended = whyRecommended
        self.tips = tips
        self.alternatives = alternatives
        self.coordinates = coordinates
        self.tags = tags
        self.ageAppropriate = ageAppropriate
        self.accessibility = accessibility
        self.seasonality = seasonality
        self.groupSize = groupSize
        self.aiInsights = aiInsights
        self.lastUpdated = lastUpdated
        self.isAIGenerated = isAIGenerated
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, location, rating, distance, tags
        case personalityMatch = "personalityMatch"
        case personalityMatchScore = "personalityMatchScore"
        case imageUrl = "imageUrl"
        case estimatedCost = "estimated_cost"
        case duration, coordinates, accessibility, seasonality
        case bestTimeOfDay = "best_time_of_day"
        case whyRecommended = "why_recommended"
        case tips, alternatives
        case ageAppropriate = "age_appropriate"
        case groupSize = "group_size"
        case aiInsights = "ai_insights"
        case lastUpdated = "last_updated"
        case isAIGenerated = "is_ai_generated"
    }
}

// MARK: - Supporting Models

struct ActivityCoordinates: Codable {
    let latitude: Double
    let longitude: Double
    
    var clLocationCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct AIActivityInsights: Codable {
    let personalityAlignment: String // Why this matches the user's personality
    let relationshipBenefits: String // How this strengthens the relationship
    let conversationStarters: [String] // Suggested topics to discuss
    let memoryMaking: String // How to make this experience memorable
    let confidenceLevel: Double // 0.0-1.0 how confident AI is in this recommendation
}

// MARK: - Activity Search & Filter Models

struct ActivitySearchRequest: Codable {
    let query: String?
    let category: String?
    let location: ActivityCoordinates?
    let radius: Double? // in miles
    let priceRange: ActivityPriceRange?
    let personalityType: String?
    let relationshipDuration: String?
    let userPreferences: [String]?
    let timeOfDay: String?
    let season: String?
    let useAI: Bool // Whether to use AI for recommendations
    
    // Convenience initializer for CLLocationCoordinate2D
    init(query: String? = nil,
         category: String? = nil,
         location: CLLocationCoordinate2D? = nil,
         radius: Double? = nil,
         priceRange: ActivityPriceRange? = nil,
         personalityType: String? = nil,
         relationshipDuration: String? = nil,
         userPreferences: [String]? = nil,
         timeOfDay: String? = nil,
         season: String? = nil,
         useAI: Bool = false) {
        
        self.query = query
        self.category = category
        self.location = location.map { ActivityCoordinates(latitude: $0.latitude, longitude: $0.longitude) }
        self.radius = radius
        self.priceRange = priceRange
        self.personalityType = personalityType
        self.relationshipDuration = relationshipDuration
        self.userPreferences = userPreferences
        self.timeOfDay = timeOfDay
        self.season = season
        self.useAI = useAI
    }
    
    enum CodingKeys: String, CodingKey {
        case query, category, radius, location
        case priceRange = "price_range"
        case personalityType = "personality_type"
        case relationshipDuration = "relationship_duration"
        case userPreferences = "user_preferences"
        case timeOfDay = "time_of_day"
        case season
        case useAI = "use_ai"
    }
}

enum ActivityPriceRange: String, Codable, CaseIterable {
    case free = "free"
    case budget = "budget" // $0-25
    case moderate = "moderate" // $25-75
    case premium = "premium" // $75+
    case all = "all"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .budget: return "Budget ($0-25)"
        case .moderate: return "Moderate ($25-75)"
        case .premium: return "Premium ($75+)"
        case .all: return "All Prices"
        }
    }
    
    var range: ClosedRange<Double>? {
        switch self {
        case .free: return 0...0
        case .budget: return 0...25
        case .moderate: return 25...75
        case .premium: return 75...1000
        case .all: return nil
        }
    }
}

// MARK: - Activity Response Models

struct ActivitiesResponse: Codable {
    let activities: [Activity]
    let totalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case activities
        case totalCount = "total_count"
    }
}

struct ActivitySearchResponse: Codable {
    let activities: [Activity]
    let totalCount: Int
    let searchContext: String?
    let aiInsights: String? // General insights from AI about the search
    let suggestedRefinements: [String]? // Suggested search refinements
    
    enum CodingKeys: String, CodingKey {
        case activities
        case totalCount = "total_count"
        case searchContext = "search_context"
        case aiInsights = "ai_insights"
        case suggestedRefinements = "suggested_refinements"
    }
}

// MARK: - Activity Search Criteria Model

struct ActivitySearchCriteria: Codable {
    let location: ActivityCoordinates?
    let cityName: String?
    let radius: Double
    let personalityType: String?
    let relationshipDuration: String?
    let idealActivities: [String]
    let priceRange: String?
    let category: String?
    let timeOfDay: String?
    let season: String?
    
    enum CodingKeys: String, CodingKey {
        case location, radius, idealActivities, priceRange, category, season
        case cityName = "city_name"
        case personalityType = "personality_type"
        case relationshipDuration = "relationship_duration"
        case timeOfDay = "time_of_day"
    }
}

struct PersonalizedActivityResponse: Codable {
    let recommendations: [Activity]
    let personalityInsights: String
    let relationshipTips: [String]
    let alternativeCategories: [String]?
    let searchCriteria: ActivitySearchCriteria?
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case personalityInsights = "personality_insights"
        case relationshipTips = "relationship_tips"
        case alternativeCategories = "alternative_categories"
        case searchCriteria = "search_criteria"
    }
}
