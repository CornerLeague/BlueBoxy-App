//
//  Activity.swift
//  BlueBoxy
//
//  Model for activities from the backend API
//

import Foundation

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
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, location, rating, distance
        case personalityMatch = "personalityMatch"
        case personalityMatchScore = "personalityMatchScore"
        case imageUrl = "imageUrl"
    }
}
