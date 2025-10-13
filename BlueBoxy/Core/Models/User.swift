//
//  User.swift
//  BlueBoxy
//
//  Basic user model - simplified version for general use
//  See AuthModels.swift for the full domain-specific User model
//

import Foundation

// MARK: - Basic User Model (for simple operations)

struct BasicUser: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String?
    let createdAt: Date?
    let updatedAt: Date?
    let lastLoginAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLoginAt = "last_login_at"
    }
}

// MARK: - API Response Models

struct BasicUserResponse: Codable {
    let user: BasicUser
}

struct BasicUsersResponse: Codable {
    let users: [BasicUser]
}

// MARK: - Type Aliases for Backward Compatibility

typealias User = BasicUser
typealias UserResponse = BasicUserResponse
typealias UsersResponse = BasicUsersResponse
