//
//  ActivityCategory.swift
//  BlueBoxy
//
//  Activity categories and drink sub-categories with styling and AI prompt instructions
//  Based on ACTIVITIES_TAB_DOCUMENTATION specifications
//

import Foundation
import SwiftUI

// MARK: - Activity Category

enum ActivityCategory: String, CaseIterable, Identifiable {
    case recommended
    case nearMe = "near_me"
    case dining
    case outdoor
    case cultural
    case active
    case drinks
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .recommended: return "Recommended"
        case .nearMe: return "Near Me"
        case .dining: return "Dining"
        case .outdoor: return "Outdoor"
        case .cultural: return "Cultural"
        case .active: return "Active"
        case .drinks: return "Drinks"
        }
    }
    
    var icon: String {
        switch self {
        case .recommended: return "star.fill"
        case .nearMe: return "location.fill"
        case .dining: return "fork.knife"
        case .outdoor: return "leaf.fill"
        case .cultural: return "theatermasks.fill"
        case .active: return "figure.run"
        case .drinks: return "cup.and.saucer.fill"
        }
    }
    
    var emoji: String {
        switch self {
        case .recommended: return "⭐"
        case .nearMe: return "📍"
        case .dining: return "🍽️"
        case .outdoor: return "🌳"
        case .cultural: return "🎭"
        case .active: return "⚡"
        case .drinks: return "🍹"
        }
    }
    
    var color: Color {
        switch self {
        case .recommended: return .blue
        case .nearMe: return .green
        case .dining: return .orange
        case .outdoor: return Color(red: 0.2, green: 0.7, blue: 0.5) // emerald
        case .cultural: return .purple
        case .active: return .red
        case .drinks: return Color(red: 1.0, green: 0.7, blue: 0.0) // amber
        }
    }
    
    var description: String {
        switch self {
        case .recommended:
            return "Highly-rated activities based on your personality type"
        case .nearMe:
            return "Quality activities within 2-3 miles of your location"
        case .dining:
            return "Restaurants, cafes, and unique food experiences"
        case .outdoor:
            return "Parks, hiking trails, and nature activities for couples"
        case .cultural:
            return "Museums, galleries, theaters, and cultural experiences"
        case .active:
            return "Fitness activities, sports, and active pursuits"
        case .drinks:
            return "Bars, cafes, and beverage-focused venues"
        }
    }
    
    /// AI prompt instructions specific to this category
    var aiPromptInstructions: String {
        switch self {
        case .recommended:
            return """
            Focus on highly-rated, personality-matched activities. \
            Consider the user's personality type and relationship preferences. \
            Provide a balanced mix across different activity types. \
            Prioritize experiences that create meaningful moments.
            """
            
        case .nearMe:
            return """
            Prioritize proximity and quality. Include the closest high-quality options within 2-3 miles. \
            Focus on convenience and spontaneity. \
            Ensure all recommendations are actually close and accessible. \
            Perfect for last-minute or spontaneous date ideas.
            """
            
        case .dining:
            return """
            Include restaurants, cafes, and unique food experiences. \
            Consider cuisine variety and dining ambiance. \
            Specify price ranges clearly. \
            Focus on romantic or couple-friendly atmospheres. \
            Include both casual and upscale options.
            """
            
        case .outdoor:
            return """
            Focus on parks, hiking trails, beaches, gardens, and outdoor activities. \
            Consider seasonal appropriateness and weather. \
            Suggest couple-friendly outdoor experiences. \
            Include both active and relaxing outdoor options. \
            Emphasize natural beauty and scenic locations.
            """
            
        case .cultural:
            return """
            Include museums, art galleries, theaters, music venues, and cultural centers. \
            Focus on enriching and educational experiences. \
            Suggest activities that spark conversation and learning. \
            Include both traditional and contemporary cultural venues. \
            Consider special exhibitions or events when relevant.
            """
            
        case .active:
            return """
            Focus on fitness activities, sports, recreation centers, and active pursuits. \
            Match activity level to user preferences. \
            Include both competitive and non-competitive options. \
            Suggest couple-friendly active experiences. \
            Consider skill levels and accessibility.
            """
            
        case .drinks:
            return """
            Include bars, cocktail lounges, wine bars, breweries, and beverage-focused venues. \
            Focus on atmosphere and ambiance suitable for couples. \
            Consider both alcoholic and non-alcoholic options. \
            Emphasize unique or specialty drink experiences. \
            Include cozy and romantic settings.
            """
        }
    }
    
    /// Sorting priority for this category
    var sortingPriority: String {
        switch self {
        case .recommended: return "Personality match score, then rating"
        case .nearMe: return "Distance (closest first), then rating"
        case .dining: return "Rating, then cuisine variety"
        case .outdoor: return "Seasonal relevance, then rating"
        case .cultural: return "Rating, then cultural significance"
        case .active: return "Fitness level match, then rating"
        case .drinks: return "Atmosphere rating, then specialties"
        }
    }
}

// MARK: - Drink Category

enum DrinkCategory: String, CaseIterable, Identifiable {
    case coffee
    case tea
    case alcohol
    case nonAlcohol = "non_alcohol"
    case boba
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .coffee: return "Coffee"
        case .tea: return "Tea"
        case .alcohol: return "Alcohol"
        case .nonAlcohol: return "Non-Alcohol"
        case .boba: return "Boba"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .coffee: return "☕"
        case .tea: return "🍵"
        case .alcohol: return "🍷"
        case .nonAlcohol: return "🥤"
        case .boba: return "🧋"
        case .other: return "🥛"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .tea: return "leaf.fill"
        case .alcohol: return "wineglass.fill"
        case .nonAlcohol: return "drop.fill"
        case .boba: return "circle.grid.2x2.fill"
        case .other: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .coffee: return Color(red: 0.4, green: 0.2, blue: 0.1) // brown
        case .tea: return .green
        case .alcohol: return Color(red: 0.6, green: 0.2, blue: 0.3) // wine red
        case .nonAlcohol: return .blue
        case .boba: return Color(red: 0.8, green: 0.6, blue: 0.9) // light purple
        case .other: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .coffee:
            return "Coffee shops, specialty roasters, artisan cafes"
        case .tea:
            return "Tea houses, bubble tea shops, specialty tea cafes"
        case .alcohol:
            return "Bars, cocktail lounges, wine bars, breweries"
        case .nonAlcohol:
            return "Juice bars, smoothie shops, creative non-alcoholic beverages"
        case .boba:
            return "Bubble tea shops, boba cafes, authentic boba experiences"
        case .other:
            return "Unique beverage spots, specialty drinks, innovative experiences"
        }
    }
    
    /// AI prompt instructions specific to this drink category
    var aiPromptInstructions: String {
        switch self {
        case .coffee:
            return """
            Focus on coffee shops, specialty coffee roasters, and artisan cafes. \
            Include independent shops and unique coffee experiences. \
            Consider ambiance for dates (cozy, romantic, conversation-friendly). \
            Mention signature drinks and coffee quality. \
            Include both trendy and classic coffee spots.
            """
            
        case .tea:
            return """
            Include tea houses, bubble tea shops, and specialty tea cafes. \
            Focus on both traditional tea experiences and modern tea cafes. \
            Mention unique tea selections and preparation methods. \
            Consider atmosphere for couples. \
            Include both authentic and fusion tea experiences.
            """
            
        case .alcohol:
            return """
            Include bars, restaurants with excellent drink menus, cocktail lounges, wine bars, and breweries. \
            Focus on atmosphere and ambiance suitable for dates. \
            Mention signature cocktails or drink specialties. \
            Consider both upscale and casual drinking venues. \
            Emphasize romantic or intimate settings. \
            Include variety: wine, beer, cocktails, spirits.
            """
            
        case .nonAlcohol:
            return """
            Focus on juice bars, smoothie shops, cafes with creative non-alcoholic beverages. \
            Include mocktail bars and alcohol-free venues. \
            Emphasize healthy and innovative drink options. \
            Consider social atmosphere without alcohol focus. \
            Mention unique or specialty non-alcoholic offerings.
            """
            
        case .boba:
            return """
            Include bubble tea shops, boba cafes, and Asian tea houses with authentic boba. \
            Focus on quality of boba pearls and tea base. \
            Mention unique flavors and customization options. \
            Consider trendy and Instagram-worthy locations. \
            Include both traditional and innovative boba experiences.
            """
            
        case .other:
            return """
            Include unique beverage spots that don't fit other categories. \
            Focus on specialty drinks and innovative beverage experiences. \
            Consider kava bars, yerba mate cafes, specialty hot chocolate shops. \
            Include cultural beverage experiences (horchata, lassi, etc.). \
            Emphasize uniqueness and novelty.
            """
        }
    }
}

// MARK: - Category Extensions

extension ActivityCategory {
    /// Get sample activities for this category (for testing/preview)
    var sampleActivities: [String] {
        switch self {
        case .recommended:
            return ["Sunset Dinner Cruise", "Wine Tasting Tour", "Couples Cooking Class"]
        case .nearMe:
            return ["Local Coffee Shop", "Neighborhood Park", "Corner Bistro"]
        case .dining:
            return ["Italian Restaurant", "Sushi Bar", "Farm-to-Table Cafe"]
        case .outdoor:
            return ["Hiking Trail", "Botanical Garden", "Beach Picnic Spot"]
        case .cultural:
            return ["Art Museum", "Theater Performance", "Jazz Club"]
        case .active:
            return ["Rock Climbing Gym", "Bike Trail", "Dance Class"]
        case .drinks:
            return ["Cocktail Lounge", "Wine Bar", "Craft Brewery"]
        }
    }
}

extension DrinkCategory {
    /// Get sample venues for this drink category (for testing/preview)
    var sampleVenues: [String] {
        switch self {
        case .coffee:
            return ["Blue Bottle Coffee", "Local Roasters", "Espresso Bar"]
        case .tea:
            return ["Tea House", "Matcha Cafe", "Bubble Tea Shop"]
        case .alcohol:
            return ["Craft Cocktail Bar", "Wine Lounge", "Speakeasy"]
        case .nonAlcohol:
            return ["Juice Bar", "Smoothie Shop", "Mocktail Bar"]
        case .boba:
            return ["Boba Guys", "Tiger Sugar", "Gong Cha"]
        case .other:
            return ["Kava Bar", "Hot Chocolate Cafe", "Specialty Beverage Shop"]
        }
    }
}
