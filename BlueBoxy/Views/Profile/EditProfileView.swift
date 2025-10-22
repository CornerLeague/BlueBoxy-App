import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var name: String = ""
    @State private var partnerName: String = ""
    @State private var relationshipDuration: String = ""
    @State private var partnerAge: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    
    // Form validation
    @State private var nameError: String = ""
    @State private var partnerAgeError: String = ""
    
    // UI state
    @State private var isLoading = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    
    var isFormValid: Bool {
        !name.isEmpty && nameError.isEmpty && partnerAgeError.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                profileImageSection
                personalInformationSection
                relationshipDetailsSection
                personalitySection
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .buttonStyle(CompactButtonStyle(isLoading: isLoading))
                    .disabled(!isFormValid || isLoading)
                }
            }
            .alert("Discard Changes", isPresented: $showingDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                Task {
                    if let newPhoto = newPhoto {
                        await loadProfileImage(from: newPhoto)
                    }
                }
            }
            .onChange(of: name) { _, _ in validateForm() }
            .onChange(of: partnerAge) { _, _ in validateForm() }
        }
        .onAppear {
            loadUserData()
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }
    
    // MARK: - Form Sections
    
    @ViewBuilder
    private var profileImageContent: some View {
        if let profileImage = profileImage {
            profileImage
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Default placeholder since user model doesn't have profileImageUrl
            Circle()
                .fill(.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.gray)
                }
        }
    }
    
    private var profileImageSection: some View {
        Section {
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // Current profile image
                    profileImageContent
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.quaternary, lineWidth: 2)
                    )
                    
                    // Photo picker
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                            Text("Change Photo")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var personalInformationSection: some View {
        Section("Personal Information") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Your name", text: $name)
                    .textFieldStyle(AuthTextFieldStyle(
                        isFocused: false,
                        validationState: nameError.isEmpty ? .valid : .invalid(nameError)
                    ))
                    .onChange(of: name) { _, _ in hasUnsavedChanges = true }
                
                if !nameError.isEmpty {
                    Text(nameError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    private var relationshipDetailsSection: some View {
        Section("Relationship Details") {
            TextField("Partner's name (optional)", text: $partnerName)
                .textFieldStyle(AuthTextFieldStyle(
                    isFocused: false,
                    validationState: .empty
                ))
                .onChange(of: partnerName) { _, _ in hasUnsavedChanges = true }
            
            TextField("How long together? (optional)", text: $relationshipDuration)
                .textFieldStyle(AuthTextFieldStyle(
                    isFocused: false,
                    validationState: .empty
                ))
                .onChange(of: relationshipDuration) { _, _ in hasUnsavedChanges = true }
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Partner's age (optional)", text: $partnerAge)
                    .textFieldStyle(AuthTextFieldStyle(
                        isFocused: false,
                        validationState: partnerAgeError.isEmpty ? .empty : .invalid(partnerAgeError)
                    ))
                    .keyboardType(.numberPad)
                    .onChange(of: partnerAge) { _, _ in hasUnsavedChanges = true }
                
                if !partnerAgeError.isEmpty {
                    Text(partnerAgeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    private var personalitySection: some View {
        Section("Personality Assessment") {
            if let user = authViewModel.user, let personalityType = user.personalityType {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text(personalityType)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                }
                
                Button("Retake Assessment") {
                    // Navigate to assessment
                }
                .foregroundStyle(.purple)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                        Text("Complete your personality assessment to get better recommendations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Take Assessment") {
                        // Navigate to assessment
                    }
                    .buttonStyle(CompactButtonStyle(variant: .primary))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() {
        guard let user = authViewModel.user else { return }
        
        name = user.name
        partnerName = user.partnerName ?? ""
        relationshipDuration = user.relationshipDuration ?? ""
        partnerAge = user.partnerAge.map(String.init) ?? ""
    }
    
    private func validateForm() {
        // Validate name
        if name.isEmpty {
            nameError = "Name is required"
        } else if name.count < 2 {
            nameError = "Name must be at least 2 characters"
        } else {
            nameError = ""
        }
        
        // Validate partner age
        if !partnerAge.isEmpty {
            if let age = Int(partnerAge) {
                if age < 18 || age > 120 {
                    partnerAgeError = "Please enter a valid age (18-120)"
                } else {
                    partnerAgeError = ""
                }
            } else {
                partnerAgeError = "Please enter a valid number"
            }
        } else {
            partnerAgeError = ""
        }
    }
    
    private func loadProfileImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }
        
        profileImage = Image(uiImage: uiImage)
        hasUnsavedChanges = true
    }
    
    private func handleCancel() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    @MainActor
    private func saveProfile() async {
        isLoading = true
        
        do {
            // Create update request
            let updateRequest = UpdateProfileRequest(
                name: name.isEmpty ? nil : name,
                partnerName: partnerName.isEmpty ? nil : partnerName,
                relationshipDuration: relationshipDuration.isEmpty ? nil : relationshipDuration,
                partnerAge: partnerAge.isEmpty ? nil : Int(partnerAge),
                personalityType: nil,
                preferences: nil,
                location: nil
            )
            
            // Update profile through API
            let _: Empty = try await APIClient.shared.request(.userProfileUpdate(updateRequest))
            
            // Refresh user data in auth view model
            await authViewModel.refreshUser()
            
            // Upload profile image if changed
            if let profileImage = profileImage {
                // TODO: Implement image upload
                // try await authViewModel.uploadProfileImage(profileImage)
            }
            
            hasUnsavedChanges = false
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Types

struct UserUpdateRequest: Codable {
    let name: String?
    let partnerName: String?
    let relationshipDuration: String?
    let partnerAge: Int?
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
