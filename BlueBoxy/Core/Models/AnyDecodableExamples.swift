//
//  AnyDecodableExamples.swift
//  BlueBoxy
//
//  Examples showing how to use AnyDecodable for flexible JSON handling
//  Useful for dynamic API responses and user preferences
//

import Foundation

// MARK: - Example Usage of AnyDecodable

class AnyDecodableExamples {
    
    // MARK: - User Preferences Example
    
    /// Example showing how to handle dynamic user preferences
    func processUserPreferences(_ preferences: [String: AnyDecodable]) {
        // Access string preference
        if let theme = preferences["theme"]?.stringValue {
            print("User theme: \(theme)")
        }
        
        // Access boolean preference
        if let notifications = preferences["notifications_enabled"]?.boolValue {
            print("Notifications enabled: \(notifications)")
        }
        
        // Access numeric preference
        if let fontSize = preferences["font_size"]?.intValue {
            print("Font size: \(fontSize)")
        }
        
        // Access array preference
        if let interests = preferences["interests"]?.arrayValue {
            let stringInterests = interests.compactMap { $0.stringValue }
            print("User interests: \(stringInterests)")
        }
        
        // Access nested object preference
        if let location = preferences["location"]?.dictionaryValue {
            let city = location["city"]?.stringValue ?? "Unknown"
            let country = location["country"]?.stringValue ?? "Unknown"
            print("User location: \(city), \(country)")
        }
    }
    
    // MARK: - API Response Handling
    
    /// Example showing how to handle mixed API responses
    func handleDynamicAPIResponse(_ json: String) throws {
        let data = json.data(using: .utf8)!
        
        // Decode dynamic response
        let response = try JSONDecoder().decode([String: AnyDecodable].self, from: data)
        
        // Handle different response formats
        if let success = response["success"]?.boolValue {
            print("Request successful: \(success)")
        }
        
        // Handle dynamic data field
        if let dataField = response["data"]?.dictionaryValue {
            processDataField(dataField)
        } else if let dataArray = response["data"]?.arrayValue {
            print("Received \(dataArray.count) items")
        }
        
        // Handle optional message
        if let message = response["message"]?.stringValue {
            print("API message: \(message)")
        }
        
        // Handle metadata that might be different types
        if let metadata = response["metadata"]?.dictionaryValue {
            processMetadata(metadata)
        }
    }
    
    private func processDataField(_ data: [String: AnyDecodable]) {
        // Example of processing dynamic data
        for (key, value) in data {
            print("Field \(key): ", terminator: "")
            
            if let stringVal = value.stringValue {
                print("(string) \(stringVal)")
            } else if let intVal = value.intValue {
                print("(int) \(intVal)")
            } else if let boolVal = value.boolValue {
                print("(bool) \(boolVal)")
            } else if value.isNull {
                print("(null)")
            } else {
                print("(complex) \(value)")
            }
        }
    }
    
    private func processMetadata(_ metadata: [String: AnyDecodable]) {
        // Handle timestamp that could be string or number
        if let timestamp = metadata["timestamp"] {
            if let timeString = timestamp.stringValue {
                print("Timestamp (string): \(timeString)")
            } else if let timeInt = timestamp.intValue {
                print("Timestamp (unix): \(timeInt)")
            }
        }
        
        // Handle version that could be string or number
        if let version = metadata["version"] {
            if let versionString = version.stringValue {
                print("Version: \(versionString)")
            } else if let versionNumber = version.doubleValue {
                print("Version: \(versionNumber)")
            }
        }
    }
    
    // MARK: - Real-world Examples
    
    /// Example processing BlueBoxy user preferences
    func processBlueboxyPreferences(_ user: DomainUser) {
        guard let preferences = user.preferences else {
            print("No preferences found")
            return
        }
        
        // Relationship preferences
        if let communicationStyle = preferences["communication_style"]?.stringValue {
            print("Communication style: \(communicationStyle)")
        }
        
        // Activity preferences (could be array of strings or objects)
        if let activities = preferences["preferred_activities"] {
            if let activityStrings = activities.arrayValue?.compactMap({ $0.stringValue }) {
                print("Preferred activities: \(activityStrings.joined(separator: ", "))")
            }
        }
        
        // Notification settings (nested object)
        if let notifications = preferences["notifications"]?.dictionaryValue {
            let dailyMessages = notifications["daily_messages"]?.boolValue ?? true
            let weeklyInsights = notifications["weekly_insights"]?.boolValue ?? true
            print("Notifications - Daily: \(dailyMessages), Weekly: \(weeklyInsights)")
        }
        
        // Theme preferences
        if let themePrefs = preferences["theme"]?.dictionaryValue {
            let colorScheme = themePrefs["color_scheme"]?.stringValue ?? "auto"
            let fontSize = themePrefs["font_size"]?.intValue ?? 16
            print("Theme - Color: \(colorScheme), Font size: \(fontSize)")
        }
    }
    
    /// Example processing location data
    func processLocationData(_ user: DomainUser) {
        guard let location = user.location else {
            print("No location data found")
            return
        }
        
        // Basic location info
        let city = location["city"]?.stringValue ?? "Unknown"
        let country = location["country"]?.stringValue ?? "Unknown"
        
        // Coordinates (could be strings, numbers, or nested object)
        if let coords = location["coordinates"]?.dictionaryValue {
            let lat = coords["lat"]?.doubleValue ?? 0.0
            let lng = coords["lng"]?.doubleValue ?? 0.0
            print("Location: \(city), \(country) (\(lat), \(lng))")
        } else {
            print("Location: \(city), \(country)")
        }
        
        // Timezone (could be string offset or timezone name)
        if let timezone = location["timezone"]?.stringValue {
            print("Timezone: \(timezone)")
        }
        
        // Privacy settings
        if let locationPrivacy = location["privacy_level"]?.stringValue {
            print("Location privacy: \(locationPrivacy)")
        }
    }
}

// MARK: - Extension for Converting AnyDecodable to Strongly Typed Models

extension DomainUser {
    /// Convert flexible preferences to strongly typed preferences
    func getTypedPreferences() -> UserPreferences? {
        guard let prefs = preferences else { return nil }
        
        // Convert AnyDecodable values to a JSON-serializable dictionary
        var jsonDict: [String: Any] = [:]
        
        for (key, value) in prefs {
            if let stringVal = value.stringValue {
                jsonDict[key] = stringVal
            } else if let intVal = value.intValue {
                jsonDict[key] = intVal
            } else if let boolVal = value.boolValue {
                jsonDict[key] = boolVal
            } else if let arrayVal = value.arrayValue {
                // Convert array of AnyDecodable to array of Any
                let arrayItems: [Any] = arrayVal.compactMap { item in
                    if let stringVal = item.stringValue {
                        return stringVal as Any
                    } else if let intVal = item.intValue {
                        return intVal as Any
                    } else if let boolVal = item.boolValue {
                        return boolVal as Any
                    }
                    return nil
                }
                jsonDict[key] = arrayItems
            } else if let dictVal = value.dictionaryValue {
                // Recursively convert nested dictionaries
                var nestedDict: [String: Any] = [:]
                for (nestedKey, nestedValue) in dictVal {
                    if let nestedStringVal = nestedValue.stringValue {
                        nestedDict[nestedKey] = nestedStringVal
                    } else if let nestedBoolVal = nestedValue.boolValue {
                        nestedDict[nestedKey] = nestedBoolVal
                    }
                }
                jsonDict[key] = nestedDict
            }
        }
        
        // Convert to UserPreferences
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDict)
            return try JSONDecoder().decode(UserPreferences.self, from: data)
        } catch {
            print("Failed to convert preferences: \(error)")
            return nil
        }
    }
}
