//
//  LocationHeaderView.swift
//  BlueBoxy
//
//  Location header view for Activities tab
//  Displays current location with Update and Preferences buttons
//

import SwiftUI
import CoreLocation

struct LocationHeaderView: View {
    @ObservedObject var locationService: LocationService
    @Binding var showingPreferences: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Location icon with status indicator
            locationIconView
            
            // Location name/status
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                locationTextView
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 12) {
                // Update location button
                Button(action: {
                    locationService.updateLocation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(locationService.isUpdatingLocation)
                
                // Preferences button
                Button(action: {
                    showingPreferences = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(glassEffectBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .onAppear {
            // Request location on appear if not already determined
            if locationService.permissionStatus == .notDetermined {
                locationService.requestLocationPermission()
            } else if locationService.permissionStatus == .granted && locationService.currentLocation == nil {
                locationService.getCurrentLocation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locationPermissionDenied)) { _ in
            // Handle permission denied notification
            showLocationSettingsAlert()
        }
    }
    
    // MARK: - Subviews
    
    private var locationIconView: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 40, height: 40)
            
            Image(systemName: locationIconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
            
            // Loading indicator
            if locationService.isUpdatingLocation {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: locationService.isUpdatingLocation
                    )
            }
        }
    }
    
    private var locationTextView: some View {
        Group {
            if locationService.isUpdatingLocation {
                HStack(spacing: 4) {
                    Text("Detecting location...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    ProgressView()
                        .scaleEffect(0.7)
                }
            } else if let error = locationService.lastError {
                Text(errorMessage(for: error))
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if !locationService.locationName.isEmpty {
                Text(locationService.locationName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            } else {
                Text("Location not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var glassEffectBackground: some View {
        ZStack {
            Color.white.opacity(0.1)
            
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .opacity(0.9)
        }
    }
    
    // MARK: - Computed Properties
    
    private var locationIconName: String {
        switch locationService.permissionStatus {
        case .granted:
            return locationService.currentLocation != nil ? "location.fill" : "location"
        case .denied:
            return "location.slash"
        case .notDetermined:
            return "location"
        }
    }
    
    private var iconColor: Color {
        switch locationService.permissionStatus {
        case .granted:
            return .blue
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        }
    }
    
    private var iconBackgroundColor: Color {
        switch locationService.permissionStatus {
        case .granted:
            return Color.blue.opacity(0.1)
        case .denied:
            return Color.red.opacity(0.1)
        case .notDetermined:
            return Color.gray.opacity(0.1)
        }
    }
    
    // MARK: - Helper Methods
    
    private func errorMessage(for error: LocationError) -> String {
        switch error {
        case .permissionDenied:
            return "Location access denied"
        case .locationUnavailable:
            return "Location unavailable"
        case .timeout:
            return "Location timeout"
        case .networkError:
            return "Network error"
        case .geocodingFailed:
            return locationService.locationName.isEmpty ? "Geocoding failed" : locationService.locationName
        case .unknown:
            return "Location error"
        }
    }
    
    private func showLocationSettingsAlert() {
        // This would be handled by the parent view
        // Could use an alert or action sheet
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Preview with location
        LocationHeaderView(
            locationService: {
                let service = LocationService()
                service.locationName = "San Francisco, California"
                service.permissionStatus = .granted
                return service
            }(),
            showingPreferences: .constant(false)
        )
        
        // Preview loading
        LocationHeaderView(
            locationService: {
                let service = LocationService()
                service.isUpdatingLocation = true
                service.permissionStatus = .granted
                return service
            }(),
            showingPreferences: .constant(false)
        )
        
        // Preview denied
        LocationHeaderView(
            locationService: {
                let service = LocationService()
                service.permissionStatus = .denied
                return service
            }(),
            showingPreferences: .constant(false)
        )
        
        Spacer()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
