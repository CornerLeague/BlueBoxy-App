//
//  LocationService.swift
//  BlueBoxy
//
//  Location service for detecting user location and reverse geocoding
//  Based on ACTIVITIES_TAB_DOCUMENTATION requirements adapted for iOS
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationName: String = ""
    @Published var permissionStatus: LocationPermissionStatus = .notDetermined
    @Published var isUpdatingLocation: Bool = false
    @Published var lastError: LocationError?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private let cache = LocationCache()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private let locationTimeoutInterval: TimeInterval = 10.0
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private let highAccuracyDesiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    private let standardDesiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    
    override init() {
        super.init()
        setupLocationManager()
        loadCachedLocation()
    }
    
    // MARK: - Public Methods
    
    /// Request location permission and detect user's current location
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            permissionStatus = .denied
            showLocationSettingsAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            permissionStatus = .granted
            getCurrentLocation()
        @unknown default:
            permissionStatus = .notDetermined
        }
    }
    
    /// Get current location with high accuracy (similar to browser geolocation)
    func getCurrentLocation(useHighAccuracy: Bool = true) {
        guard permissionStatus == .granted else {
            requestLocationPermission()
            return
        }
        
        // Check cache first (5-minute expiration as per documentation)
        if let cachedLocation = cache.getCachedLocation(),
           cache.isCacheValid() {
            currentLocation = cachedLocation.coordinate
            locationName = cachedLocation.name
            return
        }
        
        isUpdatingLocation = true
        lastError = nil
        
        locationManager.desiredAccuracy = useHighAccuracy ? highAccuracyDesiredAccuracy : standardDesiredAccuracy
        locationManager.requestLocation()
        
        // Set timeout for location request (10 seconds as per documentation)
        DispatchQueue.main.asyncAfter(deadline: .now() + locationTimeoutInterval) { [weak self] in
            if self?.isUpdatingLocation == true {
                self?.handleLocationTimeout()
            }
        }
    }
    
    /// Update location (called by "Update" button in UI)
    func updateLocation() {
        cache.clearCache()
        getCurrentLocation(useHighAccuracy: true)
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = highAccuracyDesiredAccuracy
        
        // Update permission status
        updatePermissionStatus(locationManager.authorizationStatus)
    }
    
    private func loadCachedLocation() {
        if let cachedLocation = cache.getCachedLocation(),
           cache.isCacheValid() {
            currentLocation = cachedLocation.coordinate
            locationName = cachedLocation.name
        }
    }
    
    private func updatePermissionStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .denied, .restricted:
            permissionStatus = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            permissionStatus = .granted
        @unknown default:
            permissionStatus = .notDetermined
        }
    }
    
    private func handleLocationTimeout() {
        isUpdatingLocation = false
        lastError = .timeout
        
        // Retry with lower accuracy as fallback
        getCurrentLocation(useHighAccuracy: false)
    }
    
    private func showLocationSettingsAlert() {
        // This would trigger a UI alert in the calling view
        NotificationCenter.default.post(
            name: .locationPermissionDenied,
            object: nil
        )
    }
    
    /// Reverse geocode coordinates to human-readable location name
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        do {
            let locationName = try await BigDataCloudGeocoder.reverseGeocode(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            await MainActor.run {
                self.locationName = locationName
                
                // Cache the location with name
                let cachedLocation = CachedLocation(
                    coordinate: coordinate,
                    name: locationName,
                    timestamp: Date()
                )
                self.cache.saveLocation(cachedLocation)
            }
            
        } catch {
            await MainActor.run {
                // Fallback to coordinate display
                self.locationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
                self.lastError = .geocodingFailed
                
                // Still cache the coordinate
                let cachedLocation = CachedLocation(
                    coordinate: coordinate,
                    name: self.locationName,
                    timestamp: Date()
                )
                self.cache.saveLocation(cachedLocation)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        isUpdatingLocation = false
        currentLocation = location.coordinate
        
        // Perform reverse geocoding
        Task {
            await reverseGeocode(location.coordinate)
        }
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .locationUpdated,
            object: location.coordinate
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isUpdatingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                lastError = .permissionDenied
                permissionStatus = .denied
            case .locationUnknown:
                lastError = .locationUnavailable
            case .network:
                lastError = .networkError
            default:
                lastError = .unknown(error.localizedDescription)
            }
        } else {
            lastError = .unknown(error.localizedDescription)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updatePermissionStatus(status)
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            getCurrentLocation()
        }
    }
}

// MARK: - Supporting Types

enum LocationPermissionStatus {
    case notDetermined
    case granted
    case denied
}

enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout
    case networkError
    case geocodingFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission was denied. Please enable location access in Settings."
        case .locationUnavailable:
            return "Your location is currently unavailable. Please try again."
        case .timeout:
            return "Location request timed out. Please try again."
        case .networkError:
            return "Network error while getting location. Please check your connection."
        case .geocodingFailed:
            return "Could not determine location name."
        case .unknown(let message):
            return message
        }
    }
}

struct CachedLocation {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let timestamp: Date
}

// MARK: - Location Cache

private class LocationCache {
    private let cacheKey = "cached_user_location"
    private let nameKey = "cached_location_name"
    private let timestampKey = "cached_location_timestamp"
    private let expirationInterval: TimeInterval = 300 // 5 minutes
    
    func saveLocation(_ location: CachedLocation) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: location.name,
            timestamp: location.timestamp
        )) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    func getCachedLocation() -> CachedLocation? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let locationData = try? decoder.decode(LocationData.self, from: data) else {
            return nil
        }
        
        return CachedLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: locationData.latitude,
                longitude: locationData.longitude
            ),
            name: locationData.name,
            timestamp: locationData.timestamp
        )
    }
    
    func isCacheValid() -> Bool {
        guard let cachedLocation = getCachedLocation() else { return false }
        return Date().timeIntervalSince(cachedLocation.timestamp) < expirationInterval
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    private struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
        let name: String
        let timestamp: Date
    }
}

// MARK: - BigDataCloud Geocoding Service

struct BigDataCloudGeocoder {
    static func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        let urlString = "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=\(latitude)&longitude=\(longitude)&localityLanguage=en"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(BigDataCloudResponse.self, from: data)
        
        // Format location name as per documentation: "City, State"
        if let city = response.city, let state = response.principalSubdivision, !city.isEmpty {
            return "\(city), \(state)"
        } else if let locality = response.locality, let state = response.principalSubdivision, !locality.isEmpty {
            return "\(locality), \(state)"
        } else if let state = response.principalSubdivision, !state.isEmpty {
            return state
        } else {
            // Fallback to coordinates if city name unavailable
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
    }
}

struct BigDataCloudResponse: Codable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let principalSubdivision: String?
    let locality: String?
    let countryName: String?
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, city, locality, countryName
        case principalSubdivision = "principalSubdivision"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let locationUpdated = Notification.Name("LocationUpdated")
    static let locationPermissionDenied = Notification.Name("LocationPermissionDenied")
}