//
//  GenerationControlView.swift
//  BlueBoxy
//
//  Generation control button with progress tracking
//  Handles initial, generate more, and reset states
//

import SwiftUI

struct GenerationControlView: View {
    let generationInfo: GenerationDisplayInfo
    let isLoading: Bool
    let onGenerate: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if generationInfo.currentCount == 0 {
                // Initial state - large prominent button
                initialStateView
            } else {
                // After first generation - compact view with progress
                compactStateView
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Initial State (0 generations)
    
    private var initialStateView: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, options: .repeating, value: isLoading)
            }
            
            // Title and description
            VStack(spacing: 8) {
                Text("Generate AI Activities")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(generationInfo.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Generate button
            Button(action: onGenerate) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: generationInfo.buttonIcon)
                            .font(.title3)
                    }
                    
                    Text(isLoading ? "Generating..." : generationInfo.buttonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isLoading ? [.gray, .gray] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Compact State (1-3 generations)
    
    private var compactStateView: some View {
        VStack(spacing: 12) {
            // Progress indicator
            generationProgressBar
            
            // Button and info
            HStack(spacing: 12) {
                // Status info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(generationInfo.getStatusEmoji(count: generationInfo.currentCount))
                            .font(.title3)
                        
                        Text("\(generationInfo.currentCount) of \(generationInfo.maxCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Text(generationInfo.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if generationInfo.isAtLimit {
                        // Reset button
                        Button(action: onReset) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                                Text("Reset")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .disabled(isLoading)
                    } else {
                        // Generate More button
                        Button(action: onGenerate) {
                            HStack(spacing: 6) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: generationInfo.buttonIcon)
                                        .font(.subheadline)
                                }
                                
                                Text(isLoading ? "Generating..." : generationInfo.buttonTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: isLoading ? [.gray, .gray] : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(isLoading || !generationInfo.canGenerateMore)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var generationProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressGradient)
                    .frame(width: geometry.size.width * generationInfo.progressPercentage, height: 8)
                    .animation(.spring(response: 0.5), value: generationInfo.progressPercentage)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 16)
    }
    
    private var progressGradient: LinearGradient {
        let percentage = generationInfo.progressPercentage
        
        if percentage <= 0.33 {
            return LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
        } else if percentage <= 0.66 {
            return LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Helper Extension

extension GenerationDisplayInfo {
    func getStatusEmoji(count: Int) -> String {
        switch count {
        case 0:
            return "✨"
        case 1:
            return "🎯"
        case 2:
            return "⚡"
        case 3...:
            return "🔒"
        default:
            return "✨"
        }
    }
}

// MARK: - Preview

#Preview("Initial State") {
    VStack(spacing: 20) {
        GenerationControlView(
            generationInfo: GenerationDisplayInfo(
                currentCount: 0,
                maxCount: 3,
                remaining: 3,
                canGenerateMore: true,
                isAtLimit: false,
                message: "Get fresh recommendations tailored to your preferences"
            ),
            isLoading: false,
            onGenerate: {
                print("Generate tapped")
            },
            onReset: {
                print("Reset tapped")
            }
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Loading State") {
    VStack(spacing: 20) {
        GenerationControlView(
            generationInfo: GenerationDisplayInfo(
                currentCount: 0,
                maxCount: 3,
                remaining: 3,
                canGenerateMore: true,
                isAtLimit: false,
                message: "Get fresh recommendations tailored to your preferences"
            ),
            isLoading: true,
            onGenerate: {},
            onReset: {}
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("After First Generation") {
    VStack(spacing: 20) {
        GenerationControlView(
            generationInfo: GenerationDisplayInfo(
                currentCount: 1,
                maxCount: 3,
                remaining: 2,
                canGenerateMore: true,
                isAtLimit: false,
                message: "2 more generations available"
            ),
            isLoading: false,
            onGenerate: {},
            onReset: {}
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("After Second Generation") {
    VStack(spacing: 20) {
        GenerationControlView(
            generationInfo: GenerationDisplayInfo(
                currentCount: 2,
                maxCount: 3,
                remaining: 1,
                canGenerateMore: true,
                isAtLimit: false,
                message: "Last generation available! Make it count."
            ),
            isLoading: false,
            onGenerate: {},
            onReset: {}
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("At Limit") {
    VStack(spacing: 20) {
        GenerationControlView(
            generationInfo: GenerationDisplayInfo(
                currentCount: 3,
                maxCount: 3,
                remaining: 0,
                canGenerateMore: false,
                isAtLimit: true,
                message: "You've reached the generation limit. Reset to get new recommendations."
            ),
            isLoading: false,
            onGenerate: {},
            onReset: {}
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
