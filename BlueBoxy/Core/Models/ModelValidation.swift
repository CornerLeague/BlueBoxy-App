//
//  ModelValidation.swift
//  BlueBoxy
//
//  Model validation utilities to verify optionality patterns
//  These utilities help ensure our models correctly handle optional/required fields
//

import Foundation

#if DEBUG
struct ModelValidation {
    
    // MARK: - User Model Validation
    
    /// Validates that BasicUser model has correct required field patterns
    static func validateBasicUser(_ user: BasicUser) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields validation (non-empty/valid)
        if user.id <= 0 {
            issues.append("BasicUser.id must be positive integer")
        }
        
        if user.email.isEmpty {
            issues.append("BasicUser.email is required and cannot be empty")
        }
        
        // name is optional in BasicUser, but when present should not be empty
        if let name = user.name, name.isEmpty {
            issues.append("BasicUser.name when present should not be empty")
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Validates that DomainUser model has correct required/optional field patterns
    static func validateDomainUser(_ user: DomainUser) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields validation (non-empty/valid)
        if user.id <= 0 {
            issues.append("DomainUser.id must be positive integer")
        }
        
        if user.email.isEmpty {
            issues.append("DomainUser.email is required and cannot be empty")
        }
        
        if user.name.isEmpty {
            issues.append("DomainUser.name is required and cannot be empty")
        }
        
        // Optional fields validation (when present, should be valid)
        if let partnerName = user.partnerName, partnerName.isEmpty {
            issues.append("DomainUser.partnerName when present should not be empty")
        }
        
        if let relationshipDuration = user.relationshipDuration, relationshipDuration.isEmpty {
            issues.append("DomainUser.relationshipDuration when present should not be empty")
        }
        
        if let partnerAge = user.partnerAge, partnerAge <= 0 {
            issues.append("DomainUser.partnerAge when present should be positive")
        }
        
        if let personalityType = user.personalityType, personalityType.isEmpty {
            issues.append("DomainUser.personalityType when present should not be empty")
        }
        
        // PersonalityInsight validation (when present, all fields required)
        if let insight = user.personalityInsight {
            if insight.description.isEmpty {
                issues.append("PersonalityInsight.description is required when insight is present")
            }
            if insight.loveLanguage.isEmpty {
                issues.append("PersonalityInsight.loveLanguage is required when insight is present")
            }
            if insight.communicationStyle.isEmpty {
                issues.append("PersonalityInsight.communicationStyle is required when insight is present")
            }
            if insight.idealActivities.isEmpty {
                issues.append("PersonalityInsight.idealActivities is required when insight is present")
            }
            if insight.stressResponse.isEmpty {
                issues.append("PersonalityInsight.stressResponse is required when insight is present")
            }
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Calendar Event Validation
    
    /// Validates ExternalCalendarEvent required fields
    static func validateExternalCalendarEvent(_ event: ExternalCalendarEvent) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields
        if event.id.isEmpty {
            issues.append("ExternalCalendarEvent.id is required")
        }
        
        if event.title.isEmpty {
            issues.append("ExternalCalendarEvent.title is required")
        }
        
        if event.start.isEmpty {
            issues.append("ExternalCalendarEvent.start is required")
        }
        
        if event.end.isEmpty {
            issues.append("ExternalCalendarEvent.end is required")
        }
        
        if event.providerId.isEmpty {
            issues.append("ExternalCalendarEvent.providerId is required")
        }
        
        if event.externalId.isEmpty {
            issues.append("ExternalCalendarEvent.externalId is required")
        }
        
        // Optional fields validation (when present, should be valid)
        if let description = event.description, description.isEmpty {
            issues.append("ExternalCalendarEvent.description when present should not be empty")
        }
        
        if let location = event.location, location.isEmpty {
            issues.append("ExternalCalendarEvent.location when present should not be empty")
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Validates CalendarEventDB required fields
    static func validateCalendarEventDB(_ event: CalendarEventDB) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields
        if event.id <= 0 {
            issues.append("CalendarEventDB.id must be positive integer")
        }
        
        if event.userId <= 0 {
            issues.append("CalendarEventDB.userId must be positive integer")
        }
        
        if event.title.isEmpty {
            issues.append("CalendarEventDB.title is required")
        }
        
        if event.startTime.isEmpty {
            issues.append("CalendarEventDB.startTime is required")
        }
        
        if event.endTime.isEmpty {
            issues.append("CalendarEventDB.endTime is required")
        }
        
        if event.eventType.isEmpty {
            issues.append("CalendarEventDB.eventType is required")
        }
        
        // Optional fields validation (when present, should be valid)
        if let description = event.description, description.isEmpty {
            issues.append("CalendarEventDB.description when present should not be empty")
        }
        
        if let location = event.location, location.isEmpty {
            issues.append("CalendarEventDB.location when present should not be empty")
        }
        
        if let status = event.status, status.isEmpty {
            issues.append("CalendarEventDB.status when present should not be empty")
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Recommendation Validation
    
    /// Validates GrokActivityRecommendation required fields
    static func validateGrokActivityRecommendation(_ rec: GrokActivityRecommendation) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields
        if rec.id.isEmpty {
            issues.append("GrokActivityRecommendation.id is required")
        }
        
        if rec.name.isEmpty {
            issues.append("GrokActivityRecommendation.name is required")
        }
        
        if rec.description.isEmpty {
            issues.append("GrokActivityRecommendation.description is required")
        }
        
        if rec.category.isEmpty {
            issues.append("GrokActivityRecommendation.category is required")
        }
        
        // Optional fields validation (when present, should be valid)
        if let rating = rec.rating, rating < 0 || rating > 5 {
            issues.append("GrokActivityRecommendation.rating when present should be between 0-5")
        }
        
        if let distance = rec.distance, distance < 0 {
            issues.append("GrokActivityRecommendation.distance when present should be non-negative")
        }
        
        // String optionals validation
        let stringOptionals: [(String?, String)] = [
            (rec.price, "price"),
            (rec.address, "address"), 
            (rec.phone, "phone"),
            (rec.website, "website"),
            (rec.atmosphere, "atmosphere"),
            (rec.estimatedCost, "estimatedCost"),
            (rec.recommendedTime, "recommendedTime"),
            (rec.personalityMatch, "personalityMatch")
        ]
        
        for (value, fieldName) in stringOptionals {
            if let value = value, value.isEmpty {
                issues.append("GrokActivityRecommendation.\(fieldName) when present should not be empty")
            }
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Validates AIPoweredActivity required fields
    static func validateAIPoweredActivity(_ activity: AIPoweredActivity) -> ModelValidationResult {
        var issues: [String] = []
        
        // Required fields
        if activity.id <= 0 {
            issues.append("AIPoweredActivity.id must be positive integer")
        }
        
        if activity.name.isEmpty {
            issues.append("AIPoweredActivity.name is required")
        }
        
        if activity.description.isEmpty {
            issues.append("AIPoweredActivity.description is required")
        }
        
        if activity.category.isEmpty {
            issues.append("AIPoweredActivity.category is required")
        }
        
        // Optional fields validation
        if let rating = activity.rating, rating < 0 || rating > 5 {
            issues.append("AIPoweredActivity.rating when present should be between 0-5")
        }
        
        let stringOptionals: [(String?, String)] = [
            (activity.personalityMatch, "personalityMatch"),
            (activity.distance, "distance"),
            (activity.imageUrl, "imageUrl"),
            (activity.location, "location")
        ]
        
        for (value, fieldName) in stringOptionals {
            if let value = value, value.isEmpty {
                issues.append("AIPoweredActivity.\(fieldName) when present should not be empty")
            }
        }
        
        return ModelValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Date Validation
    
    /// Validates ISO-8601 date string format
    static func validateISO8601DateString(_ dateString: String, fieldName: String) -> ModelValidationResult {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try both with and without fractional seconds
        let formatters = [
            iso8601Formatter,
            ISO8601DateFormatter() // Default format
        ]
        
        for formatter in formatters {
            if formatter.date(from: dateString) != nil {
                return ModelValidationResult(isValid: true, issues: [])
            }
        }
        
        return ModelValidationResult(
            isValid: false, 
            issues: ["\(fieldName) '\(dateString)' is not a valid ISO-8601 date string"]
        )
    }
    
    // MARK: - JSONValue Validation
    
    /// Validates that JSONValue can be encoded/decoded properly
    static func validateJSONValue(_ jsonValue: JSONValue, fieldName: String) -> ModelValidationResult {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(jsonValue)
            
            let decoder = JSONDecoder()
            let _ = try decoder.decode(JSONValue.self, from: data)
            
            return ModelValidationResult(isValid: true, issues: [])
        } catch {
            return ModelValidationResult(
                isValid: false,
                issues: ["\(fieldName) JSONValue failed encode/decode test: \(error.localizedDescription)"]
            )
        }
    }
}

// MARK: - Validation Result

struct ModelValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var description: String {
        if isValid {
            return "✅ Valid"
        } else {
            return "❌ Invalid:\n" + issues.map { "  • \($0)" }.joined(separator: "\n")
        }
    }
}

#endif