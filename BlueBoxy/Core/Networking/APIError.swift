//
//  APIError.swift
//  BlueBoxy
//
//  API error handling for mixed error response formats
//

import Foundation

struct APIErrorEnvelope: Decodable {
    let success: Bool?
    let error: APIErrorBody?

    struct APIErrorBody: Decodable {
        let code: String?
        let message: String?
    }
}

struct SimpleErrorEnvelope: Decodable {
    let error: String
}

enum APIServiceError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case badRequest(message: String)
    case server(message: String)
    case decoding(Error)
    case network(Error)
    case invalidURL
    case missingAuth
    case unknown(status: Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Unauthorized"
        case .forbidden: return "Forbidden"
        case .notFound: return "Not found"
        case .badRequest(let m): return m
        case .server(let m): return m
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .invalidURL: return "Invalid URL"
        case .missingAuth: return "Missing authentication"
        case .unknown(let s): return "Unexpected status: \(s)"
        }
    }
}