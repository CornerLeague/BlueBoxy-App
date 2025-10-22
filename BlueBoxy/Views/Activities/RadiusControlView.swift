//
//  RadiusControlView.swift
//  BlueBoxy
//
//  Radius control slider for activity search
//  Range: 1-50 miles with visual feedback and persistence
//

import SwiftUI
import Combine

struct RadiusControlView: View {
    @Binding var radius: Double
    @State private var isDragging: Bool = false
    @State private var debouncedRadius: Double = 25.0
    private let debounceSubject = PassthroughSubject<Double, Never>()
    
    // Persistence key
    private let radiusKey = "activities_search_radius"
    
    var onRadiusChanged: ((Double) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with current value
            HStack {
                Label("Search Radius", systemImage: "circle.dashed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(Int(radius))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .contentTransition(.numericText())
                        .animation(.default, value: radius)
                    
                    Text("mi")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Slider
            VStack(spacing: 8) {
                Slider(
                    value: $radius,
                    in: 1...50,
                    step: 1,
                    onEditingChanged: { editing in
                        isDragging = editing
                        if !editing {
                            saveRadius()
                            debounceSubject.send(radius)
                        }
                    }
                )
                .accentColor(.blue)
                .animation(.spring(response: 0.3), value: radius)
                
                // Mile markers
                HStack {
                    markerView(value: 1, label: "1 mi")
                    Spacer()
                    markerView(value: 25, label: "25 mi", isHighlighted: true)
                    Spacer()
                    markerView(value: 50, label: "50 mi")
                }
            }
            .padding(.vertical, 4)
            
            // Visual feedback bar
            radiusVisualizationBar
            
            // Description text
            Text(radiusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDragging ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal)
        .onAppear {
            loadRadius()
            setupDebouncing()
        }
    }
    
    // MARK: - Subviews
    
    private func markerView(value: Double, label: String, isHighlighted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(isHighlighted ? Color.blue : Color.gray.opacity(0.5))
                .frame(width: 2, height: isHighlighted ? 8 : 6)
            
            Text(label)
                .font(.caption2)
                .fontWeight(isHighlighted ? .medium : .regular)
                .foregroundColor(isHighlighted ? .blue : .secondary)
        }
    }
    
    private var radiusVisualizationBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: radiusGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth(in: geometry), height: 4)
                
                // Thumb indicator
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                    .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: progressWidth(in: geometry) - 6)
            }
        }
        .frame(height: 12)
    }
    
    private var radiusGradientColors: [Color] {
        if radius <= 10 {
            return [.green, .blue]
        } else if radius <= 30 {
            return [.blue, .purple]
        } else {
            return [.purple, .red]
        }
    }
    
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (radius - 1) / 49 // 1-50 range
        return geometry.size.width * percentage
    }
    
    private var radiusDescription: String {
        switch radius {
        case 1..<5:
            return "Very close - perfect for quick, spontaneous activities nearby"
        case 5..<15:
            return "Local area - convenient activities in your neighborhood"
        case 15..<30:
            return "City-wide - explore activities across your city"
        case 30..<40:
            return "Regional - discover activities in nearby areas"
        default:
            return "Extended area - find unique activities in surrounding regions"
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveRadius() {
        UserDefaults.standard.set(radius, forKey: radiusKey)
        print("💾 Saved radius: \(Int(radius)) miles")
    }
    
    private func loadRadius() {
        let savedRadius = UserDefaults.standard.double(forKey: radiusKey)
        if savedRadius > 0 {
            radius = savedRadius
            debouncedRadius = savedRadius
            print("📖 Loaded saved radius: \(Int(savedRadius)) miles")
        } else {
            // Set default to 25 miles
            radius = 25.0
            debouncedRadius = 25.0
            saveRadius()
        }
    }
    
    private func setupDebouncing() {
        debounceSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [self] debouncedValue in
                print("🎯 Radius changed (debounced): \(Int(debouncedValue)) miles")
                onRadiusChanged?(debouncedValue)
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RadiusControlView(radius: .constant(25)) { newRadius in
            print("Radius changed to: \(newRadius)")
        }
        
        RadiusControlView(radius: .constant(5)) { newRadius in
            print("Radius changed to: \(newRadius)")
        }
        
        RadiusControlView(radius: .constant(40)) { newRadius in
            print("Radius changed to: \(newRadius)")
        }
        
        Spacer()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
