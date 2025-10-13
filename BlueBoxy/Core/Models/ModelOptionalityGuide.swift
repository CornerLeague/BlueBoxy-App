//
//  ModelOptionalityGuide.swift
//  BlueBoxy
//
//  Documentation of optionality patterns from schema and routes
//  This file serves as a reference for understanding which fields are optional
//

import Foundation

/*
 OPTIONALITY PATTERNS FROM BACKEND SCHEMA AND ROUTES
 
 This documentation outlines the optionality rules for all backend models,
 derived from the database schema and API route analysis.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## User Model Optionality
 
 ### REQUIRED fields:
 - id: Int
 - email: String  
 - name: String
 
 ### OPTIONAL fields:
 - partnerName: String?
 - relationshipDuration: String?
 - partnerAge: Int?
 - personalityType: String?
 - personalityInsight: PersonalityInsight?  // Entire block optional
 - preferences: [String: JSONValue]?        // JSON blob
 - location: [String: JSONValue]?           // JSON blob
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## PersonalityInsight Model Optionality
 
 ### OPTIONAL at User level:
 - The entire PersonalityInsight can be nil on User
 
 ### REQUIRED when present:
 - description: String
 - loveLanguage: String
 - communicationStyle: String
 - idealActivities: [String]
 - stressResponse: String
 
 Note: When PersonalityInsight exists, all its fields are required/non-null.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Calendar Events Optionality
 
 ### ExternalCalendarEvent (Google/Outlook provider events):
 REQUIRED:
 - id: String
 - title: String
 - start: String (ISO-8601)
 - end: String (ISO-8601)
 - providerId: String
 - externalId: String
 
 OPTIONAL:
 - description: String?
 - location: String?
 - attendees: [String]?
 
 ### CalendarEventDB (App's own database events):
 REQUIRED:
 - id: Int
 - userId: Int
 - title: String
 - startTime: String (ISO-8601)
 - endTime: String (ISO-8601) 
 - allDay: Bool
 - eventType: String
 
 OPTIONAL:
 - description: String?
 - location: String?
 - status: String?
 - externalEventId: String?
 - calendarProvider: String?
 - reminders: JSONValue?    // JSON blob
 - metadata: JSONValue?     // JSON blob
 - createdAt: String?       // ISO-8601
 - updatedAt: String?       // ISO-8601
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Recommendation Models Optionality
 
 ### GrokActivityRecommendation:
 REQUIRED:
 - id: String
 - name: String
 - description: String
 - category: String
 
 OPTIONAL (many fields):
 - rating: Double?
 - distance: Double?
 - price: String?
 - address: String?
 - phone: String?
 - website: String?
 - specialties: [String]?
 - atmosphere: String?
 - estimatedCost: String?
 - recommendedTime: String?
 - personalityMatch: String?
 
 ### AIPoweredActivity:
 REQUIRED:
 - id: Int
 - name: String
 - description: String
 - category: String
 
 OPTIONAL:
 - rating: Double?
 - personalityMatch: String?
 - distance: String?
 - imageUrl: String?
 - location: String?
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Preferences Response Optionality
 
 ### PreferencesSaveResponse.PreferencesUser:
 REQUIRED:
 - id: Int
 - name: String
 
 OPTIONAL:
 - preferences: [String: JSONValue]?  // JSON blob
 - location: [String: JSONValue]?     // JSON blob
 
 ### PreferencesUpdateResponse:
 REQUIRED:
 - success: Bool
 - user: User  // But user itself has optional fields as documented above
 
 OPTIONAL:
 - preferences: [String: JSONValue]?  // JSON blob, can be separate from user.preferences
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Date Field Notes
 
 ### Date Handling Strategy:
 - All date fields from backend are ISO-8601 strings
 - Fields ending in "At" (createdAt, updatedAt, completedAt, lastSync) are strings
 - Event start/end times are strings: "startTime", "endTime", "start", "end"
 - Use JSONDecoder.dateDecodingStrategy = .iso8601 only when field type is Date
 - Current implementation keeps all dates as String for consistency with backend
 
 ### Date Fields by Model:
 - AssessmentSavedResponse.completedAt: String (ISO-8601)
 - CalendarEventDB.{createdAt, updatedAt}: String? (ISO-8601, optional)
 - CalendarEventDB.{startTime, endTime}: String (ISO-8601, required)
 - ExternalCalendarEvent.{start, end}: String (ISO-8601, required)
 - CalendarProvider.lastSync: String? (ISO-8601, optional)
 - UserStatsResponse.{createdAt, updatedAt}: String? (ISO-8601, optional)
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## JSON Blob Fields (using JSONValue)
 
 These fields contain arbitrary JSON that can't be strongly typed:
 
 - User.preferences: [String: JSONValue]?
 - User.location: [String: JSONValue]?
 - PreferencesSaveResponse.PreferencesUser.preferences: [String: JSONValue]?
 - PreferencesSaveResponse.PreferencesUser.location: [String: JSONValue]?
 - PreferencesUpdateResponse.preferences: [String: JSONValue]?
 - CalendarEventDB.reminders: JSONValue?
 - CalendarEventDB.metadata: JSONValue?
 - GuestAssessmentResponse.onboardingData: JSONValue?
 
 JSONValue enum handles: bool, int, double, string, array, object, null
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Provider Naming Differences
 
 ### External Calendar Events (Google/Outlook):
 - start: String
 - end: String
 
 ### Database Calendar Events (App's own):
 - startTime: String  
 - endTime: String
 
 This difference is intentional and reflects the actual API response structure.
 No CodingKeys mapping is needed as the backend already uses camelCase.
 
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## Error Handling Optionality
 
 ### APIErrorEnvelope:
 - success: Bool?        // May or may not be present
 - error: APIErrorBody?  // May be nil
 
 ### APIErrorEnvelope.APIErrorBody:
 - code: String?     // Optional error code
 - message: String?  // Optional error message
 
 ### MessageGenerationResponse:
 - error: String?  // Present only when there's an error
 
 ═══════════════════════════════════════════════════════════════════════════════
 */