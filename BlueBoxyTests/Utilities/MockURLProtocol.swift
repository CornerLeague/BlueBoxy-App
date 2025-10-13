//
//  MockURLProtocol.swift
//  BlueBoxyTests
//
//  Mock URLProtocol for testing API client behavior without real network calls
//  Provides controllable request/response testing infrastructure
//

import Foundation
@testable import BlueBoxy

/// Mock URLProtocol for intercepting and mocking network requests in tests
final class MockURLProtocol: URLProtocol {
    
    // MARK: - Handler Configuration
    
    /// Handler configuration for mock responses
    struct Handler {
        let requestValidator: ((URLRequest) -> Void)?
        let response: HTTPURLResponse
        let data: Data
        let delay: TimeInterval?
        let error: Error?
        
        init(requestValidator: ((URLRequest) -> Void)? = nil,
             response: HTTPURLResponse,
             data: Data = Data(),
             delay: TimeInterval? = nil,
             error: Error? = nil) {
            self.requestValidator = requestValidator
            self.response = response
            self.data = data
            self.delay = delay
            self.error = error
        }
    }
    
    /// Current handler for requests
    static var handler: Handler?
    
    /// Request history for validation
    static private(set) var requestHistory: [URLRequest] = []
    
    /// Reset mock state
    static func reset() {
        handler = nil
        requestHistory.removeAll()
    }
    
    // MARK: - URLProtocol Implementation
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        // Record request for validation
        Self.requestHistory.append(request)
        
        guard let handler = Self.handler else {
            let error = NSError(domain: "MockURLProtocol", code: 0, userInfo: [NSLocalizedDescriptionKey: "No handler configured"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Validate request if validator provided
        handler.requestValidator?(request)
        
        // Simulate delay if specified
        if let delay = handler.delay {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.sendResponse(with: handler)
            }
        } else {
            sendResponse(with: handler)
        }
    }
    
    override func stopLoading() {
        // Nothing to do
    }
    
    // MARK: - Private Methods
    
    private func sendResponse(with handler: Handler) {
        // Send error if configured
        if let error = handler.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Send successful response
        client?.urlProtocol(self, didReceive: handler.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: handler.data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - Convenience Methods

extension MockURLProtocol {
    
    /// Create a success response handler
    static func successHandler(
        for url: String,
        statusCode: Int = 200,
        headers: [String: String]? = nil,
        data: Data = Data(),
        requestValidator: ((URLRequest) -> Void)? = nil
    ) -> Handler {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        
        return Handler(
            requestValidator: requestValidator,
            response: response,
            data: data
        )
    }
    
    /// Create an error response handler
    static func errorHandler(
        for url: String,
        statusCode: Int,
        headers: [String: String]? = nil,
        data: Data = Data(),
        requestValidator: ((URLRequest) -> Void)? = nil
    ) -> Handler {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        
        return Handler(
            requestValidator: requestValidator,
            response: response,
            data: data
        )
    }
    
    /// Create a network error handler
    static func networkErrorHandler(
        error: Error,
        requestValidator: ((URLRequest) -> Void)? = nil
    ) -> Handler {
        // We need a dummy response, but it won't be used due to the error
        let response = HTTPURLResponse(
            url: URL(string: "http://example.com")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        
        return Handler(
            requestValidator: requestValidator,
            response: response,
            data: Data(),
            error: error
        )
    }
    
    /// Create a delayed response handler
    static func delayedHandler(
        for url: String,
        delay: TimeInterval,
        statusCode: Int = 200,
        data: Data = Data(),
        requestValidator: ((URLRequest) -> Void)? = nil
    ) -> Handler {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        
        return Handler(
            requestValidator: requestValidator,
            response: response,
            data: data,
            delay: delay
        )
    }
}

// MARK: - JSON Response Helpers

extension MockURLProtocol {
    
    /// Create handler with JSON response from Codable object
    static func jsonHandler<T: Encodable>(
        for url: String,
        object: T,
        statusCode: Int = 200,
        headers: [String: String]? = nil,
        requestValidator: ((URLRequest) -> Void)? = nil
    ) throws -> Handler {
        let encoder = APIConfiguration.encoder
        let data = try encoder.encode(object)
        
        var responseHeaders = headers ?? [:]
        responseHeaders["Content-Type"] = "application/json"
        
        return successHandler(
            for: url,
            statusCode: statusCode,
            headers: responseHeaders,
            data: data,
            requestValidator: requestValidator
        )
    }
    
    /// Create handler with JSON response from fixture
    static func fixtureHandler(
        for url: String,
        fixtureName: String,
        statusCode: Int = 200,
        headers: [String: String]? = nil,
        requestValidator: ((URLRequest) -> Void)? = nil
    ) throws -> Handler {
        let data = try FixtureLoader.loadRaw(fixtureName)
        
        var responseHeaders = headers ?? [:]
        responseHeaders["Content-Type"] = "application/json"
        
        return successHandler(
            for: url,
            statusCode: statusCode,
            headers: responseHeaders,
            data: data,
            requestValidator: requestValidator
        )
    }
}

// MARK: - Request Validation Helpers

extension MockURLProtocol {
    
    /// Validate HTTP method
    static func validateMethod(_ expectedMethod: HTTPMethod) -> (URLRequest) -> Void {
        return { request in
            assert(request.httpMethod == expectedMethod.rawValue, 
                   "Expected HTTP method \(expectedMethod.rawValue), got \(request.httpMethod ?? "nil")")
        }
    }
    
    /// Validate request URL path
    static func validatePath(_ expectedPath: String) -> (URLRequest) -> Void {
        return { request in
            let actualPath = request.url?.path ?? ""
            assert(actualPath.hasSuffix(expectedPath), 
                   "Expected path to end with \(expectedPath), got \(actualPath)")
        }
    }
    
    /// Validate request header
    static func validateHeader(_ headerName: String, expectedValue: String) -> (URLRequest) -> Void {
        return { request in
            let actualValue = request.value(forHTTPHeaderField: headerName)
            assert(actualValue == expectedValue, 
                   "Expected header \(headerName) to be \(expectedValue), got \(actualValue ?? "nil")")
        }
    }
    
    /// Validate request body contains string
    static func validateBodyContains(_ expectedContent: String) -> (URLRequest) -> Void {
        return { request in
            guard let bodyData = request.httpBody,
                  let bodyString = String(data: bodyData, encoding: .utf8) else {
                assert(false, "Expected request to have body containing \(expectedContent)")
                return
            }
            assert(bodyString.contains(expectedContent), 
                   "Expected body to contain \(expectedContent), got \(bodyString)")
        }
    }
    
    /// Validate JSON body structure
    static func validateJSONBody<T: Codable>(_ expectedType: T.Type) -> (URLRequest) -> Void {
        return { request in
            guard let bodyData = request.httpBody else {
                assert(false, "Expected request to have JSON body")
                return
            }
            
            do {
                let _ = try APIConfiguration.decoder.decode(expectedType, from: bodyData)
            } catch {
                assert(false, "Expected body to be valid \(expectedType): \(error)")
            }
        }
    }
    
    /// Combine multiple validators
    static func validateAll(_ validators: [(URLRequest) -> Void]...) -> (URLRequest) -> Void {
        return { request in
            validators.forEach { $0(request) }
        }
    }
}

// MARK: - Common Error Responses

extension MockURLProtocol {
    
    /// Standard 401 Unauthorized response
    static func unauthorizedHandler(for url: String) -> Handler {
        let errorBody = SimpleErrorEnvelope(error: "Unauthorized")
        let data = try! APIConfiguration.encoder.encode(errorBody)
        
        return errorHandler(
            for: url,
            statusCode: 401,
            headers: ["Content-Type": "application/json"],
            data: data
        )
    }
    
    /// Standard 403 Forbidden response
    static func forbiddenHandler(for url: String) -> Handler {
        let errorBody = SimpleErrorEnvelope(error: "Forbidden")
        let data = try! APIConfiguration.encoder.encode(errorBody)
        
        return errorHandler(
            for: url,
            statusCode: 403,
            headers: ["Content-Type": "application/json"],
            data: data
        )
    }
    
    /// Standard 404 Not Found response
    static func notFoundHandler(for url: String) -> Handler {
        let errorBody = SimpleErrorEnvelope(error: "Not found")
        let data = try! APIConfiguration.encoder.encode(errorBody)
        
        return errorHandler(
            for: url,
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            data: data
        )
    }
    
    /// Standard 500 Server Error response
    static func serverErrorHandler(for url: String, message: String = "Internal server error") -> Handler {
        let errorBody = SimpleErrorEnvelope(error: message)
        let data = try! APIConfiguration.encoder.encode(errorBody)
        
        return errorHandler(
            for: url,
            statusCode: 500,
            headers: ["Content-Type": "application/json"],
            data: data
        )
    }
    
    /// Standard 429 Rate Limited response
    static func rateLimitedHandler(for url: String) -> Handler {
        let errorBody = SimpleErrorEnvelope(error: "Too many requests")
        let data = try! APIConfiguration.encoder.encode(errorBody)
        
        return errorHandler(
            for: url,
            statusCode: 429,
            headers: [
                "Content-Type": "application/json",
                "Retry-After": "60"
            ],
            data: data
        )
    }
}

// MARK: - Test Helper Extensions

extension MockURLProtocol {
    
    /// Get the most recent request
    static var lastRequest: URLRequest? {
        return requestHistory.last
    }
    
    /// Get request count
    static var requestCount: Int {
        return requestHistory.count
    }
    
    /// Check if any request was made to a specific path
    static func hasRequest(to path: String) -> Bool {
        return requestHistory.contains { request in
            request.url?.path.hasSuffix(path) == true
        }
    }
    
    /// Get all requests to a specific path
    static func requests(to path: String) -> [URLRequest] {
        return requestHistory.filter { request in
            request.url?.path.hasSuffix(path) == true
        }
    }
    
    /// Get all requests with a specific HTTP method
    static func requests(with method: HTTPMethod) -> [URLRequest] {
        return requestHistory.filter { request in
            request.httpMethod == method.rawValue
        }
    }
}

// MARK: - Error Response Models

struct SimpleErrorEnvelope: Codable {
    let error: String
}