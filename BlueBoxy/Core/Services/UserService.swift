//
//  UserService.swift
//  BlueBoxy
//
//  User-related API service demonstrating authenticated requests
//

import Foundation

@MainActor
class UserService: ObservableObject {
    private let apiClient = APIClient.shared
    
    func getCurrentUser() async throws -> User {
        let endpoint = Endpoint(
            path: "/api/user/me",
            method: .GET,
            requiresUser: true
        )
        let response: UserResponse = try await apiClient.request(endpoint)
        return response.user
    }
    
    func updateUser(name: String) async throws -> User {
        struct UpdateUserRequest: Encodable {
            let name: String
        }
        
        let endpoint = Endpoint(
            path: "/api/user/me",
            method: .PUT,
            body: UpdateUserRequest(name: name),
            requiresUser: true
        )
        let response: UserResponse = try await apiClient.request(endpoint)
        return response.user
    }
    
    func getUsers() async throws -> [User] {
        let endpoint = Endpoint(
            path: "/api/users",
            method: .GET,
            requiresUser: true
        )
        let response: UsersResponse = try await apiClient.request(endpoint)
        return response.users
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let queryItems = [URLQueryItem(name: "q", value: query)]
        
        let endpoint = Endpoint(
            path: "/api/users/search",
            method: .GET,
            query: queryItems,
            requiresUser: true
        )
        let response: UsersResponse = try await apiClient.request(endpoint)
        return response.users
    }
    
    // Example of a public endpoint (no auth required)
    func getPublicUserProfile(userId: Int) async throws -> User {
        let endpoint = Endpoint(
            path: "/api/users/\(userId)/profile",
            method: .GET,
            requiresUser: false
        )
        let response: UserResponse = try await apiClient.request(endpoint)
        return response.user
    }
    
    // Example of DELETE request that returns Empty
    func deleteUser() async throws {
        let endpoint = Endpoint(
            path: "/api/user/me",
            method: .DELETE,
            requiresUser: true
        )
        let _: Empty = try await apiClient.request(endpoint)
    }
}
