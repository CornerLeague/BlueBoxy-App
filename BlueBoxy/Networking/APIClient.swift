//
//  APIClient.swift
//  BlueBoxy
//
//  Generic API client with request execution, auth integration,
//  error mapping, and comprehensive logging
//

import Foundation
import os

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Auth Provider Protocol

protocol AuthProviding {
    var userId: Int? { get }
    var authToken: String? { get }
}

// MARK: - Session Auth Provider

final class SessionAuthProvider: AuthProviding {
    var userId: Int? {
        // Replace with your actual SessionStore implementation
        SessionStore.shared.userId
    }
    
    var authToken: String? {
        // Replace with your actual auth token storage
        SessionStore.shared.authToken
    }
}

// MARK: - Endpoint Definition

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let query: [URLQueryItem]?
    let headers: [String: String]?
    let body: Encodable?
    let requiresUser: Bool
    let requiresAuth: Bool

    init(path: String,
         method: HTTPMethod,
         query: [URLQueryItem]? = nil,
         headers: [String: String]? = nil,
         body: Encodable? = nil,
         requiresUser: Bool = false,
         requiresAuth: Bool = false) {
        self.path = path
        self.method = method
        self.query = query
        self.headers = headers
        self.body = body
        self.requiresUser = requiresUser
        self.requiresAuth = requiresAuth
    }
}

// MARK: - Error Types
// APIServiceError, APIErrorEnvelope, and SimpleErrorEnvelope are defined in Core/Networking/APIError.swift

// MARK: - Network Logging

enum NetLog {
    static let logger = Logger(subsystem: "com.yourcompany.BlueBoxy", category: "network")
    
    static func request(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        logger.debug("➡️ \(method, privacy: .public) \(url, privacy: .public)")
        
        // Log headers (excluding sensitive data)
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers where !key.lowercased().contains("auth") {
                logger.debug("📋 \(key, privacy: .public): \(value, privacy: .public)")
            }
        }
        
        // Log body size
        if let body = request.httpBody {
            logger.debug("📦 Body size: \(body.count, privacy: .public) bytes")
        }
        #endif
    }
    
    static func response(_ response: HTTPURLResponse, data: Data, started: Date) {
        #if DEBUG
        let duration = Date().timeIntervalSince(started)
        let durationMs = String(format: "%.1fms", duration * 1000)
        let dataSize = data.count
        
        logger.debug("⬅️ \(response.statusCode, privacy: .public) in \(durationMs, privacy: .public) (\(dataSize, privacy: .public) bytes)")
        
        // Log response snippet (first 500 chars)
        if dataSize > 0 {
            let snippet = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            logger.debug("📄 Response: \(snippet, privacy: .public)")
        }
        #endif
    }
    
    static func failure(_ error: Error, started: Date) {
        #if DEBUG
        let duration = Date().timeIntervalSince(started)
        let durationMs = String(format: "%.1fms", duration * 1000)
        logger.error("❌ \(error.localizedDescription, privacy: .public) after \(durationMs, privacy: .public)")
        #endif
    }
}

// MARK: - API Client

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let auth: AuthProviding

    init(baseURL: URL = APIConfiguration.baseURL,
         session: URLSession = APIConfiguration.session,
         decoder: JSONDecoder = APIConfiguration.decoder,
         encoder: JSONEncoder = APIConfiguration.encoder,
         auth: AuthProviding = SessionAuthProvider()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.auth = auth
    }

    // MARK: - Main Request Method

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Build URL
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIServiceError.invalidURL
        }
        
        // Handle path
        let cleanPath = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path
        if components.path.hasSuffix("/") {
            components.path += cleanPath
        } else {
            components.path += "/\(cleanPath)"
        }
        
        // Add query parameters
        if let queryItems = endpoint.query, !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        
        guard let url = components.url else {
            throw APIServiceError.invalidURL
        }

        // Build URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add default headers
        APIConfiguration.defaultHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add endpoint-specific headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add authentication
        try addAuthentication(to: &request, endpoint: endpoint)

        // Add request body
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        // Execute request
        return try await executeRequest(request)
    }
    
    // MARK: - Convenience Methods
    
    /// Perform request expecting no response body
    func requestEmpty(_ endpoint: Endpoint) async throws {
        let _: Empty = try await request(endpoint)
    }
    
    /// Perform request with optional response (returns nil on 204 No Content)
    func requestOptional<T: Decodable>(_ endpoint: Endpoint) async throws -> T? {
        do {
            return try await request(endpoint)
        } catch APIServiceError.unknown(let status) where status == 204 {
            return nil
        }
    }

    // MARK: - Private Methods

    private func addAuthentication(to request: inout URLRequest, endpoint: Endpoint) throws {
        if endpoint.requiresAuth {
            guard let token = auth.authToken else {
                throw APIServiceError.missingAuth
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if endpoint.requiresUser {
            guard let userId = auth.userId else {
                throw APIServiceError.missingAuth
            }
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")
        }
    }

    private func executeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        NetLog.request(request)
        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknown(status: -1)
            }
            
            NetLog.response(httpResponse, data: data, started: startTime)
            
            // Handle successful responses
            if (200..<300).contains(httpResponse.statusCode) {
                // Handle empty responses
                if T.self == Empty.self {
                    return Empty() as! T
                }
                
                // Handle 204 No Content
                if httpResponse.statusCode == 204 {
                    return Empty() as! T
                }
                
                // Decode response
                return try decoder.decode(T.self, from: data)
            } else {
                // Handle error responses
                throw try mapErrorResponse(data: data, statusCode: httpResponse.statusCode)
            }
            
        } catch let error as APIServiceError {
            NetLog.failure(error, started: startTime)
            throw error
        } catch {
            let networkError = APIServiceError.network(error)
            NetLog.failure(networkError, started: startTime)
            throw networkError
        }
    }

    private func mapErrorResponse(data: Data, statusCode: Int) throws -> APIServiceError {
        // Try to decode structured error response
        if let errorEnvelope = try? decoder.decode(APIErrorEnvelope.self, from: data),
           let errorMessage = errorEnvelope.error?.message {
            return mapStatusToError(statusCode, message: errorMessage)
        }
        
        // Try simple error format
        if let simpleError = try? decoder.decode(SimpleErrorEnvelope.self, from: data) {
            return mapStatusToError(statusCode, message: simpleError.error)
        }
        
        // Fallback to status code mapping
        return mapStatusToError(statusCode, message: nil)
    }

    private func mapStatusToError(_ statusCode: Int, message: String?) -> APIServiceError {
        let defaultMessage = message ?? "An error occurred"
        
        switch statusCode {
        case 400:
            return .badRequest(message: defaultMessage)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 500...599:
            return .server(message: defaultMessage)
        default:
            return .unknown(status: statusCode)
        }
    }
}

// MARK: - Supporting Types

/// Type-erased encodable wrapper
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    
    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

/// Empty response type for requests with no response body
struct Empty: Codable {}

// MARK: - Session Store
// Using shared SessionStore from Core/Services/SessionStore.swift
