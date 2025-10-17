//
//  NetworkError.swift
//  BlueBoxy
//
//  User-facing error types and mapping from lower-level errors
//  Provides consistent error messaging for ViewModels and UI
//

import Foundation

// MARK: - Network Error

/// User-facing network error that ViewModels should use
enum NetworkError: Error, LocalizedError, Equatable, Hashable, Codable {
    case unauthorized              // 401 - User needs to log in again
    case forbidden                 // 403 - User doesn't have permission
    case notFound                  // 404 - Resource doesn't exist
    case badRequest(message: String) // 400 - Client sent invalid data
    case server(message: String)   // 5xx - Server-side issue
    case decoding(String)         // JSON parsing failed
    case connectivity(String)     // Network connectivity issues
    case cancelled                // User cancelled the request
    case rateLimited              // 429 - Too many requests
    case unknown(status: Int?)    // Unexpected error
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case type, message, status, details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "unauthorized":
            self = .unauthorized
        case "forbidden":
            self = .forbidden
        case "notFound":
            self = .notFound
        case "badRequest":
            let message = try container.decode(String.self, forKey: .message)
            self = .badRequest(message: message)
        case "server":
            let message = try container.decode(String.self, forKey: .message)
            self = .server(message: message)
        case "decoding":
            let details = try container.decode(String.self, forKey: .details)
            self = .decoding(details)
        case "connectivity":
            let details = try container.decode(String.self, forKey: .details)
            self = .connectivity(details)
        case "cancelled":
            self = .cancelled
        case "rateLimited":
            self = .rateLimited
        case "unknown":
            let status = try container.decodeIfPresent(Int.self, forKey: .status)
            self = .unknown(status: status)
        default:
            self = .unknown(status: nil)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .unauthorized:
            try container.encode("unauthorized", forKey: .type)
        case .forbidden:
            try container.encode("forbidden", forKey: .type)
        case .notFound:
            try container.encode("notFound", forKey: .type)
        case .badRequest(let message):
            try container.encode("badRequest", forKey: .type)
            try container.encode(message, forKey: .message)
        case .server(let message):
            try container.encode("server", forKey: .type)
            try container.encode(message, forKey: .message)
        case .decoding(let details):
            try container.encode("decoding", forKey: .type)
            try container.encode(details, forKey: .details)
        case .connectivity(let details):
            try container.encode("connectivity", forKey: .type)
            try container.encode(details, forKey: .details)
        case .cancelled:
            try container.encode("cancelled", forKey: .type)
        case .rateLimited:
            try container.encode("rateLimited", forKey: .type)
        case .unknown(let status):
            try container.encode("unknown", forKey: .type)
            try container.encodeIfPresent(status, forKey: .status)
        }
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "You're not signed in. Please log in to continue."
        case .forbidden:
            return "You don't have permission to access this content."
        case .notFound:
            return "We couldn't find what you're looking for."
        case .badRequest(let message):
            return message.isEmpty ? "There was a problem with your request." : message
        case .server(let message):
            return message.isEmpty ? "We're experiencing server issues. Please try again later." : message
        case .decoding(_):
            return "We couldn't process the server response. Please try again."
        case .connectivity(let details):
            return details.isEmpty ? "Please check your internet connection and try again." : details
        case .cancelled:
            return "Request was cancelled."
        case .rateLimited:
            return "You're making requests too quickly. Please wait a moment and try again."
        case .unknown(let status):
            if let status = status {
                return "Something unexpected happened (Error \(status)). Please try again."
            } else {
                return "Something unexpected happened. Please try again."
            }
        }
    }
    
    /// Short description for UI alerts
    var title: String {
        switch self {
        case .unauthorized:
            return "Sign In Required"
        case .forbidden:
            return "Access Denied"
        case .notFound:
            return "Not Found"
        case .badRequest:
            return "Invalid Request"
        case .server:
            return "Server Error"
        case .decoding:
            return "Data Error"
        case .connectivity:
            return "Connection Error"
        case .cancelled:
            return "Cancelled"
        case .rateLimited:
            return "Too Many Requests"
        case .unknown:
            return "Error"
        }
    }
    
    /// Whether this error suggests the user should retry
    var isRetryable: Bool {
        switch self {
        case .connectivity, .server, .rateLimited, .unknown:
            return true
        case .unauthorized, .forbidden, .notFound, .badRequest, .decoding, .cancelled:
            return false
        }
    }
    
    /// Whether this is an authentication-related error
    var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .forbidden:
            return true
        default:
            return false
        }
    }
    
    /// Whether this indicates a client-side problem
    var isClientError: Bool {
        switch self {
        case .badRequest, .unauthorized, .forbidden, .notFound, .decoding:
            return true
        default:
            return false
        }
    }
    
    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to your account and try again."
        case .forbidden:
            return "Contact support if you believe you should have access to this content."
        case .connectivity:
            return "Check your internet connection and try again."
        case .server:
            return "Our servers are experiencing issues. Please try again in a few minutes."
        case .rateLimited:
            return "Wait a few moments before making another request."
        case .badRequest:
            return "Please check your input and try again."
        default:
            return "Try again, and contact support if the problem persists."
        }
    }
}

// MARK: - Error Mapper

/// Maps low-level errors to user-friendly NetworkError
struct ErrorMapper {
    
    /// Convert any error to NetworkError for UI consumption
    static func map(_ error: Error) -> NetworkError {
        // Handle cancellation first (common case)
        if (error as NSError).code == NSURLErrorCancelled {
            return .cancelled
        }
        
        // Map URLSession errors to connectivity issues
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }
        
        // Map our APIServiceError to NetworkError
        if let apiError = error as? APIServiceError {
            return mapAPIServiceError(apiError)
        }
        
        // Handle direct decoding errors
        if let decodingError = error as? DecodingError {
            return .decoding(decodingError.localizedDescription)
        }
        
        // Handle NSError codes
        if let nsError = error as NSError? {
            return mapNSError(nsError)
        }
        
        // Fallback for unknown errors
        return .unknown(status: nil)
    }
    
    // MARK: - Private Mapping Methods
    
    private static func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:
            return .connectivity("The request timed out. Please try again.")
        case .notConnectedToInternet:
            return .connectivity("No internet connection available.")
        case .cannotFindHost, .cannotConnectToHost:
            return .connectivity("Cannot reach the server. Please check your connection.")
        case .dnsLookupFailed:
            return .connectivity("Cannot resolve server address.")
        case .networkConnectionLost:
            return .connectivity("Network connection was lost. Please try again.")
        case .cannotParseResponse:
            return .decoding("Invalid response from server.")
        case .badServerResponse:
            return .server(message: "Server returned an invalid response.")
        case .userCancelledAuthentication:
            return .cancelled
        case .secureConnectionFailed:
            return .connectivity("Secure connection failed. Please try again.")
        case .serverCertificateHasBadDate, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot:
            return .connectivity("Server certificate is not trusted.")
        case .redirectToNonExistentLocation:
            return .server(message: "Server configuration error.")
        case .badURL:
            return .badRequest(message: "Invalid request URL.")
        case .unsupportedURL:
            return .badRequest(message: "Unsupported URL scheme.")
        case .httpTooManyRedirects:
            return .server(message: "Too many redirects from server.")
        case .resourceUnavailable:
            return .server(message: "Resource temporarily unavailable.")
        case .internationalRoamingOff:
            return .connectivity("International roaming is disabled.")
        case .callIsActive:
            return .connectivity("Cannot connect while on a phone call.")
        case .dataNotAllowed:
            return .connectivity("Data connection not allowed.")
        case .requestBodyStreamExhausted:
            return .connectivity("Upload data was exhausted.")
        default:
            return .connectivity(error.localizedDescription)
        }
    }
    
    private static func mapAPIServiceError(_ error: APIServiceError) -> NetworkError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .badRequest(let message):
            return .badRequest(message: message)
        case .server(let message):
            return .server(message: message)
        case .decoding(let decodingError):
            return .decoding(decodingError.localizedDescription)
        case .network(let networkError):
            // Recursively map the wrapped network error
            return map(networkError)
        case .unknown(let status):
            // Check for rate limiting
            if status == 429 {
                return .rateLimited
            }
            return .unknown(status: status)
        case .missingAuth:
            return .unauthorized
        case .invalidURL:
            return .badRequest(message: "Invalid request configuration.")
        case .noContent:
            return .server(message: "Server returned no content when data was expected.")
        }
    }
    
    private static func mapNSError(_ error: NSError) -> NetworkError {
        switch error.domain {
        case NSURLErrorDomain:
            // This should be handled by URLError mapping above, but just in case
            return .connectivity(error.localizedDescription)
        case NSCocoaErrorDomain:
            if error.code == NSUserCancelledError {
                return .cancelled
            }
            return .unknown(status: error.code)
        default:
            return .unknown(status: error.code)
        }
    }
}

// MARK: - Convenience Extensions

extension NetworkError {
    /// Create a connectivity error with custom message
    static func connectionFailed(_ message: String = "Connection failed") -> NetworkError {
        return .connectivity(message)
    }
    
    /// Create a server error with custom message  
    static func serverError(_ message: String = "Server error occurred") -> NetworkError {
        return .server(message: message)
    }
    
    /// Create a bad request error with custom message
    static func invalidRequest(_ message: String = "Invalid request") -> NetworkError {
        return .badRequest(message: message)
    }
}

// MARK: - Result Extensions

extension Result where Failure == NetworkError {
    /// Create a success result with NetworkError as the failure type
    static func networkSuccess(_ value: Success) -> Result<Success, NetworkError> {
        return .success(value)
    }
    
    /// Create a failure result from any error, mapping it to NetworkError
    static func networkFailure(_ error: Error) -> Result<Success, NetworkError> {
        return .failure(ErrorMapper.map(error))
    }
    
    /// Create a connectivity failure
    static func connectionFailed(_ message: String = "Connection failed") -> Result<Success, NetworkError> {
        return .failure(.connectionFailed(message))
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension NetworkError: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .unauthorized:
            return "NetworkError.unauthorized"
        case .forbidden:
            return "NetworkError.forbidden"
        case .notFound:
            return "NetworkError.notFound"
        case .badRequest(let message):
            return "NetworkError.badRequest(\(message))"
        case .server(let message):
            return "NetworkError.server(\(message))"
        case .decoding(let details):
            return "NetworkError.decoding(\(details))"
        case .connectivity(let details):
            return "NetworkError.connectivity(\(details))"
        case .cancelled:
            return "NetworkError.cancelled"
        case .rateLimited:
            return "NetworkError.rateLimited"
        case .unknown(let status):
            return "NetworkError.unknown(status: \(status?.description ?? "nil"))"
        }
    }
}
#endif