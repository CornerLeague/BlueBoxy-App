import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditProfile = false
    @State private var showingPreferences = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = authViewModel.user {
                        ProfileHeaderView(user: user)
                        ProfileDetailsView(user: user)
                        PreferencesOverview(user: user) {
                            showingPreferences = true
                        }
                        PersonalityInsightView(user: user)
                        AccountActionsView(onSignOut: { showingSignOutAlert = true })
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesEditView()
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authViewModel.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct ProfileHeaderView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: user.profileImageUrl ?? "https://via.placeholder.com/100")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.gray)
                    }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.quaternary, lineWidth: 2)
            )
            
            // User Info
            VStack(spacing: 6) {
                Text(user.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Personality Type Badge
                if let personalityType = user.personalityType {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                        Text(personalityType)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(16)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .cornerRadius(20)
    }
}

struct ProfileDetailsView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Relationship Details")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                if let partnerName = user.partnerName, !partnerName.isEmpty {
                    DetailRow(
                        icon: "person.2.fill",
                        title: "Partner",
                        value: partnerName
                    )
                }
                
                if let duration = user.relationshipDuration, !duration.isEmpty {
                    DetailRow(
                        icon: "calendar.badge.clock",
                        title: "Together for",
                        value: duration
                    )
                }
                
                if let age = user.partnerAge {
                    DetailRow(
                        icon: "number.circle.fill",
                        title: "Partner's age",
                        value: "\(age) years"
                    )
                }
                
                if user.partnerName == nil && user.relationshipDuration == nil {
                    InfoCard(
                        icon: "info.circle.fill",
                        title: "Complete your profile",
                        subtitle: "Add relationship details to get better recommendations",
                        accent: .blue
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

// Using DetailRow from UIComponents.swift

struct PreferencesOverview: View {
    let user: User
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.purple)
                    Text("Preferences")
                        .font(.headline)
                }
                
                Spacer()
                
                Button("Edit", action: onEdit)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            if let preferences = user.preferences, !preferences.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(preferences.keys.prefix(4)), id: \.self) { key in
                        PreferenceChip(
                            key: key,
                            value: preferences[key] ?? ""
                        )
                    }
                }
                
                if preferences.count > 4 {
                    HStack {
                        Text("+ \(preferences.count - 4) more preferences")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } else {
                InfoCard(
                    icon: "slider.horizontal.3",
                    title: "Set your preferences",
                    subtitle: "Get personalized activity recommendations",
                    accent: .purple
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

struct PreferenceChip: View {
    let key: String
    let value: Any
    
    var body: some View {
        HStack(spacing: 6) {
            Text(key.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text(String(describing: value))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PersonalityInsightView: View {
    let user: User
    
    var body: some View {
        if let insight = user.personalityInsight {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                        Text("AI Insights")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Button("Retake") {
                        // Navigate to assessment
                    }
                    .font(.caption)
                    .buttonStyle(CompactButtonStyle(variant: .secondary))
                }
                
                Text(insight)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                
                Button("View Full Analysis") {
                    // Show full insight
                }
                .font(.subheadline)
                .foregroundStyle(.purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

struct AccountActionsView: View {
    let onSignOut: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button("Privacy Settings") {
                // Navigate to privacy settings
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button("Help & Support") {
                // Navigate to help
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button("Sign Out") {
                onSignOut()
            }
            .buttonStyle(DestructiveButtonStyle())
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}