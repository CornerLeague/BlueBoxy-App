//
//  OnboardingService.swift
//  BlueBoxy
//
//  Service for managing onboarding data submission to backend
//  Handles profile updates, assessment submission, and preferences storage
//

import Foundation

// MARK: - Onboarding Service

final class OnboardingService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Complete Onboarding Flow
    
    /// Submit all onboarding data to backend in the correct sequence
    func submitOnboardingData(_ data: OnboardingData) async throws {
        print("📋 [OnboardingService] Starting onboarding data submission...")
        
        // Step 1: Update user profile with personal information
        try await updateUserProfile(from: data)
        
        // Step 2: Submit assessment results if completed
        if data.hasCompletedAssessment {
            try await submitAssessment(from: data)
        }
        
        // Step 3: Save user preferences including location
        try await savePreferences(from: data)
        
        print("✅ [OnboardingService] All onboarding data submitted successfully")
    }
    
    // MARK: - Individual Submission Methods
    
    /// Update user profile with personal information
    func updateUserProfile(from data: OnboardingData) async throws {
        guard !data.name.isEmpty else {
            throw OnboardingServiceError.missingRequiredData("Name is required")
        }
        
        // Check if user is authenticated before submitting
        guard SessionStore.shared.isSessionValid() else {
            print("⚠️ [OnboardingService] User not authenticated, saving profile data locally for later submission")
            saveProfileDataLocally(data)
            return
        }
        
        print("📝 [OnboardingService] Updating user profile...")
        
        let profileRequest = UpdateProfileRequest(
            name: data.name,
            partnerName: data.partnerName.isEmpty ? nil : data.partnerName,
            relationshipDuration: data.relationshipDuration.isEmpty ? nil : data.relationshipDuration,
            partnerAge: parsePartnerAge(data.partnerAge),
            personalityType: data.personalityType.isEmpty ? nil : data.personalityType,
            preferences: convertPreferencesToAnyEncodable(data.preferences),
            location: convertLocationToAnyEncodable(data.location)
        )
        
        let _: Empty = try await apiClient.request(.userProfileUpdate(profileRequest))
        print("✅ [OnboardingService] User profile updated successfully")
    }
    
    /// Submit assessment responses and personality type
    func submitAssessment(from data: OnboardingData) async throws {
        guard !data.assessmentResponses.isEmpty else {
            throw OnboardingServiceError.missingRequiredData("Assessment responses are required")
        }
        
        // Check if user is authenticated before submitting
        guard SessionStore.shared.isSessionValid() else {
            print("⚠️ [OnboardingService] User not authenticated, saving assessment locally for later submission")
            saveAssessmentDataLocally(data)
            return
        }
        
        print("🧠 [OnboardingService] Submitting assessment results...")
        
        let assessmentRequest = AssessmentResponsesRequest(
            responses: data.assessmentResponses,
            personalityType: data.personalityType.isEmpty ? nil : data.personalityType
        )
        
        let _: Empty = try await apiClient.request(.assessmentSubmit(assessmentRequest))
        print("✅ [OnboardingService] Assessment results submitted successfully")
    }
    
    /// Save user preferences including location data
    func savePreferences(from data: OnboardingData) async throws {
        // Check if user is authenticated before submitting
        guard SessionStore.shared.isSessionValid() else {
            print("⚠️ [OnboardingService] User not authenticated, saving preferences locally for later submission")
            savePreferencesDataLocally(data)
            return
        }
        
        print("⚙️ [OnboardingService] Saving user preferences...")
        
        // Convert preferences dictionary to JSONValue format
        let jsonPreferences = convertPreferencesToJSONValue(data.preferences)
        
        let preferencesRequest = SavePreferencesRequest(
            preferences: jsonPreferences.isEmpty ? nil : jsonPreferences,
            location: data.location,
            partnerAge: parsePartnerAge(data.partnerAge)
        )
        
        let _: Empty = try await apiClient.request(.preferencesSet(preferencesRequest))
        print("✅ [OnboardingService] User preferences saved successfully")
    }
    
    // MARK: - Helper Methods
    
    private func parsePartnerAge(_ ageString: String) -> Int? {
        guard !ageString.isEmpty else { return nil }
        return Int(ageString.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private func convertPreferencesToJSONValue(_ preferences: [String: Any]) -> [String: JSONValue] {
        var jsonPreferences: [String: JSONValue] = [:]
        
        for (key, value) in preferences {
            if let stringValue = value as? String {
                jsonPreferences[key] = .string(stringValue)
            } else if let intValue = value as? Int {
                jsonPreferences[key] = .number(Double(intValue))
            } else if let doubleValue = value as? Double {
                jsonPreferences[key] = .number(doubleValue)
            } else if let boolValue = value as? Bool {
                jsonPreferences[key] = .bool(boolValue)
            } else if let arrayValue = value as? [String] {
                jsonPreferences[key] = .array(arrayValue.map { .string($0) })
            }
        }
        
        return jsonPreferences
    }
    
    private func convertPreferencesToAnyEncodable(_ preferences: [String: Any]) -> [String: AnyEncodable]? {
        guard !preferences.isEmpty else { return nil }
        
        var encodablePreferences: [String: AnyEncodable] = [:]
        
        for (key, value) in preferences {
            // Only encode values that are actually Encodable
            if let encodableValue = value as? Encodable {
                encodablePreferences[key] = AnyEncodable(encodableValue)
            }
        }
        
        return encodablePreferences
    }
    
    private func convertLocationToAnyEncodable(_ location: GeoLocationPayload?) -> [String: AnyEncodable]? {
        guard let location = location else { return nil }
        
        return [
            "latitude": AnyEncodable(location.latitude),
            "longitude": AnyEncodable(location.longitude)
        ]
    }
    
    // MARK: - Local Storage Methods
    
    private func saveProfileDataLocally(_ data: OnboardingData) {
        let profileData = [
            "name": data.name,
            "partnerName": data.partnerName,
            "relationshipDuration": data.relationshipDuration,
            "partnerAge": data.partnerAge,
            "personalityType": data.personalityType
        ]
        UserDefaults.standard.set(profileData, forKey: "onboarding.pending.profile")
        print("💾 [OnboardingService] Profile data saved locally")
    }
    
    private func saveAssessmentDataLocally(_ data: OnboardingData) {
        let assessmentData = [
            "responses": data.assessmentResponses,
            "personalityType": data.personalityType
        ] as [String: Any]
        UserDefaults.standard.set(assessmentData, forKey: "onboarding.pending.assessment")
        print("💾 [OnboardingService] Assessment data saved locally")
    }
    
    private func savePreferencesDataLocally(_ data: OnboardingData) {
        let preferencesData = [
            "preferences": data.preferences,
            "location": data.location?.toDictionary() ?? [:]
        ] as [String: Any]
        UserDefaults.standard.set(preferencesData, forKey: "onboarding.pending.preferences")
        print("💾 [OnboardingService] Preferences data saved locally")
    }
    
    // MARK: - Post-Authentication Submission
    
    /// Submit any pending onboarding data after user authentication
    func submitPendingOnboardingData() async {
        print("📎 [OnboardingService] Checking for pending onboarding data...")
        
        // Check if user is authenticated
        guard SessionStore.shared.isSessionValid() else {
            print("⚠️ [OnboardingService] User not authenticated, cannot submit pending data")
            return
        }
        
        var submissionCount = 0
        
        // Submit pending profile data
        if let profileData = UserDefaults.standard.dictionary(forKey: "onboarding.pending.profile") {
            do {
                let onboardingData = convertDictionaryToOnboardingData(profileData)
                try await updateUserProfile(from: onboardingData)
                UserDefaults.standard.removeObject(forKey: "onboarding.pending.profile")
                submissionCount += 1
            } catch {
                print("❌ [OnboardingService] Failed to submit pending profile data: \(error)")
            }
        }
        
        // Submit pending assessment data
        if let assessmentData = UserDefaults.standard.dictionary(forKey: "onboarding.pending.assessment") {
            do {
                let onboardingData = convertDictionaryToOnboardingData(assessmentData)
                try await submitAssessment(from: onboardingData)
                UserDefaults.standard.removeObject(forKey: "onboarding.pending.assessment")
                submissionCount += 1
            } catch {
                print("❌ [OnboardingService] Failed to submit pending assessment data: \(error)")
            }
        }
        
        // Submit pending preferences data
        if let preferencesData = UserDefaults.standard.dictionary(forKey: "onboarding.pending.preferences") {
            do {
                let onboardingData = convertDictionaryToOnboardingData(preferencesData)
                try await savePreferences(from: onboardingData)
                UserDefaults.standard.removeObject(forKey: "onboarding.pending.preferences")
                submissionCount += 1
            } catch {
                print("❌ [OnboardingService] Failed to submit pending preferences data: \(error)")
            }
        }
        
        if submissionCount > 0 {
            print("✅ [OnboardingService] Successfully submitted \(submissionCount) pending onboarding data items")
        } else {
            print("🔄 [OnboardingService] No pending onboarding data found")
        }
    }
    
    private func convertDictionaryToOnboardingData(_ dict: [String: Any]) -> OnboardingData {
        var data = OnboardingData()
        
        data.name = dict["name"] as? String ?? ""
        data.partnerName = dict["partnerName"] as? String ?? ""
        data.relationshipDuration = dict["relationshipDuration"] as? String ?? ""
        data.partnerAge = dict["partnerAge"] as? String ?? ""
        data.personalityType = dict["personalityType"] as? String ?? ""
        data.assessmentResponses = dict["responses"] as? [String: String] ?? [:]
        data.preferences = dict["preferences"] as? [String: Any] ?? [:]
        
        if let locationDict = dict["location"] as? [String: Double],
           let latitude = locationDict["latitude"],
           let longitude = locationDict["longitude"] {
            data.location = GeoLocationPayload(latitude: latitude, longitude: longitude)
        }
        
        return data
    }
}

// MARK: - Onboarding Service Errors

enum OnboardingServiceError: LocalizedError {
    case missingRequiredData(String)
    case submissionFailed(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredData(let message):
            return "Missing required data: \(message)"
        case .submissionFailed(let message):
            return "Submission failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// UpdateProfileRequest initializer is already defined in AuthModels.swift

// MARK: - OnboardingData Extensions

extension OnboardingData {
    /// Validate that essential onboarding data is present
    func validateForSubmission() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OnboardingServiceError.missingRequiredData("User name is required")
        }
        
        // Additional validations can be added here
        print("✅ [OnboardingData] Validation passed")
    }
    
    /// Generate a summary of collected data for logging
    func generateSummary() -> String {
        var summary = ["Onboarding Data Summary:"]
        summary.append("- Name: \(name.isEmpty ? "Not provided" : "Provided")")
        summary.append("- Partner Name: \(partnerName.isEmpty ? "Not provided" : "Provided")")
        summary.append("- Relationship Duration: \(relationshipDuration.isEmpty ? "Not provided" : relationshipDuration)")
        summary.append("- Partner Age: \(partnerAge.isEmpty ? "Not provided" : partnerAge)")
        summary.append("- Assessment Completed: \(hasCompletedAssessment ? "Yes" : "No")")
        summary.append("- Personality Type: \(personalityType.isEmpty ? "Not determined" : personalityType)")
        summary.append("- Preferences Set: \(hasSetPreferences ? "Yes (\(preferences.count) items)" : "No")")
        summary.append("- Location Provided: \(location != nil ? "Yes" : "No")")
        
        return summary.joined(separator: "\n")
    }
}