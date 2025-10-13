//
//  Event.swift
//  BlueBoxy
//
//  Model for calendar events from the backend API
//

import Foundation

struct Event: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let location: String?
    let startTime: Date
    let endTime: Date
    let allDay: Bool
    let eventType: String
    let status: String
    let externalEventId: String?
    let calendarProvider: String?
    let reminders: [String] // Simplified for now
    let metadata: [String: AnyDecodable]?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, title, description, location, allDay, eventType, status, reminders, metadata
        case startTime = "startTime"
        case endTime = "endTime"
        case externalEventId = "externalEventId"
        case calendarProvider = "calendarProvider"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
    }
}