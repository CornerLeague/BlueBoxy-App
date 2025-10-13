//
//  Recommendation.swift
//  BlueBoxy
//
//  Model for AI-powered recommendations from the backend API
//

import Foundation

struct Recommendation: Decodable, Identifiable {
    let id = UUID() // Generate local ID since API doesn't provide one
    let title: String
    let description: String
    let category: String
    
    // Conform to Identifiable with computed id
    private enum CodingKeys: String, CodingKey {
        case title, description, category
    }
}