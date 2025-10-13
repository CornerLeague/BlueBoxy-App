//
//  APIExamples.swift
//  BlueBoxy
//
//  Examples demonstrating common API patterns with APIClient
//

import Foundation

// MARK: - Example Request/Response Models
// Note: LoginRequest is defined in Core/Models/AuthModels.swift

struct LoginResponse: Decodable {
    let user: User
    let token: String?
}

struct CreatePostRequest: Encodable {
    let title: String
    let content: String
    let publishedAt: Date?
}

struct Post: Codable, Identifiable {
    let id: Int
    let title: String
    let content: String
    let authorId: Int
    let publishedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, content
        case authorId = "author_id"
        case publishedAt = "published_at"
        case createdAt = "created_at"
    }
}

struct PostsResponse: Decodable {
    let posts: [Post]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case posts
        case totalCount = "total_count"
    }
}

// MARK: - Example Service

class ExampleAPIService {
    private let client = APIClient.shared
    
    // POST with body (login example)
    func login(email: String, password: String) async throws -> LoginResponse {
        let endpoint = Endpoint(
            path: "/auth/login",
            method: .POST,
            body: LoginRequest(email: email, password: password),
            requiresUser: false
        )
        return try await client.request(endpoint)
    }
    
    // GET with query parameters and authentication
    func getPosts(page: Int = 1, limit: Int = 20) async throws -> PostsResponse {
        let query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let endpoint = Endpoint(
            path: "/posts",
            method: .GET,
            query: query,
            requiresUser: true
        )
        return try await client.request(endpoint)
    }
    
    // POST with Encodable body and Date handling
    func createPost(title: String, content: String, publishAt: Date? = nil) async throws -> Post {
        let request = CreatePostRequest(
            title: title,
            content: content,
            publishedAt: publishAt
        )
        
        struct CreatePostResponse: Decodable {
            let post: Post
        }
        
        let endpoint = Endpoint(
            path: "/posts",
            method: .POST,
            body: request,
            requiresUser: true
        )
        let response: CreatePostResponse = try await client.request(endpoint)
        
        return response.post
    }
    
    // PUT request with authentication
    func updatePost(id: Int, title: String, content: String) async throws -> Post {
        struct UpdatePostRequest: Encodable {
            let title: String
            let content: String
        }
        
        struct UpdatePostResponse: Decodable {
            let post: Post
        }
        
        let endpoint = Endpoint(
            path: "/posts/\(id)",
            method: .PUT,
            body: UpdatePostRequest(title: title, content: content),
            requiresUser: true
        )
        let response: UpdatePostResponse = try await client.request(endpoint)
        
        return response.post
    }
    
    // DELETE request that returns Empty
    func deletePost(id: Int) async throws {
        let endpoint = Endpoint(
            path: "/posts/\(id)",
            method: .DELETE,
            requiresUser: true
        )
        let _: Empty = try await client.request(endpoint)
    }
    
    // GET request without authentication (public endpoint)
    func getPublicPost(id: Int) async throws -> Post {
        struct PostResponse: Decodable {
            let post: Post
        }
        
        let endpoint = Endpoint(
            path: "/public/posts/\(id)",
            method: .GET,
            requiresUser: false
        )
        let response: PostResponse = try await client.request(endpoint)
        
        return response.post
    }
    
    // Example with complex query parameters
    func searchPosts(
        query: String,
        tags: [String] = [],
        sortBy: String = "created_at",
        sortOrder: String = "desc"
    ) async throws -> PostsResponse {
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "sort_order", value: sortOrder)
        ]
        
        // Add multiple tags as separate query items
        for tag in tags {
            queryItems.append(URLQueryItem(name: "tags[]", value: tag))
        }
        
        let endpoint = Endpoint(
            path: "/posts/search",
            method: .GET,
            query: queryItems,
            requiresUser: false
        )
        return try await client.request(endpoint)
    }
}
