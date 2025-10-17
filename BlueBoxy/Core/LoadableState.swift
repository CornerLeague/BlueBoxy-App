//
//  LoadableState.swift
//  BlueBoxy
//
//  Enhanced loadable state enum for comprehensive async state management in SwiftUI
//

import Foundation
import SwiftUI

// MARK: - Loadable State

/// Represents the loading state of asynchronous operations with comprehensive error handling and UI integration
enum Loadable<T> {
    case idle
    case loading(progress: Double? = nil, message: String? = nil)
    case loaded(T)
    case failed(NetworkError)
    
    // MARK: - Computed Properties
    
    /// Whether the state is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// Whether the state has successfully loaded
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
    
    /// Whether the state has failed
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// Whether the state is idle (initial state)
    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
    
    /// Get the loaded value if available
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    /// Get the error if in failed state
    var error: NetworkError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    /// Get loading progress if available (0.0 - 1.0)
    var progress: Double? {
        if case .loading(let progress, _) = self {
            return progress
        }
        return nil
    }
    
    /// Get loading message if available
    var loadingMessage: String? {
        if case .loading(_, let message) = self {
            return message
        }
        return nil
    }
    
    // MARK: - Transformation Methods
    
    /// Transform the loaded value to another type
    func map<U>(_ transform: (T) -> U) -> Loadable<U> {
        switch self {
        case .idle:
            return .idle
        case .loading(let progress, let message):
            return .loading(progress: progress, message: message)
        case .loaded(let value):
            return .loaded(transform(value))
        case .failed(let error):
            return .failed(error)
        }
    }
    
    /// Flat map to chain loadable operations
    func flatMap<U>(_ transform: (T) -> Loadable<U>) -> Loadable<U> {
        switch self {
        case .idle:
            return .idle
        case .loading(let progress, let message):
            return .loading(progress: progress, message: message)
        case .loaded(let value):
            return transform(value)
        case .failed(let error):
            return .failed(error)
        }
    }
    
    /// Filter the loaded value based on a predicate
    func filter(_ predicate: (T) -> Bool, orError error: NetworkError) -> Loadable<T> {
        switch self {
        case .loaded(let value):
            return predicate(value) ? .loaded(value) : .failed(error)
        default:
            return self
        }
    }
    
    /// Provide a default value if loading fails
    func replaceError(with defaultValue: T) -> Loadable<T> {
        switch self {
        case .failed:
            return .loaded(defaultValue)
        default:
            return self
        }
    }
    
    /// Combine with another loadable to create a tuple
    func combineWith<U>(_ other: Loadable<U>) -> Loadable<(T, U)> {
        switch (self, other) {
        case (.loaded(let value1), .loaded(let value2)):
            return .loaded((value1, value2))
        case (.failed(let error), _), (_, .failed(let error)):
            return .failed(error)
        case (.loading(let progress1, let message1), .loading(let progress2, let message2)):
            let combinedProgress = [progress1, progress2].compactMap { $0 }.reduce(0, +) / 2
            let combinedMessage = [message1, message2].compactMap { $0 }.joined(separator: ", ")
            return .loading(progress: combinedProgress, message: combinedMessage.isEmpty ? nil : combinedMessage)
        case (.loading(let progress, let message), _), (_, .loading(let progress, let message)):
            return .loading(progress: progress, message: message)
        default:
            return .idle
        }
    }
}

// MARK: - Equatable Conformance

extension Loadable: Equatable where T: Equatable {
    static func == (lhs: Loadable<T>, rhs: Loadable<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading(let progress1, let message1), .loading(let progress2, let message2)):
            return progress1 == progress2 && message1 == message2
        case (.loaded(let value1), .loaded(let value2)):
            return value1 == value2
        case (.failed(let error1), .failed(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}

// MARK: - Hashable Conformance

extension Loadable: Hashable where T: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .idle:
            hasher.combine("idle")
        case .loading(let progress, let message):
            hasher.combine("loading")
            hasher.combine(progress)
            hasher.combine(message)
        case .loaded(let value):
            hasher.combine("loaded")
            hasher.combine(value)
        case .failed(let error):
            hasher.combine("failed")
            hasher.combine(error)
        }
    }
}

// MARK: - Codable Conformance

extension Loadable: Codable where T: Codable {
    private enum CodingKeys: String, CodingKey {
        case state, progress, message, value, error
    }
    
    private enum State: String, Codable {
        case idle, loading, loaded, failed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(State.self, forKey: .state)
        
        switch state {
        case .idle:
            self = .idle
        case .loading:
            let progress = try container.decodeIfPresent(Double.self, forKey: .progress)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .loading(progress: progress, message: message)
        case .loaded:
            let value = try container.decode(T.self, forKey: .value)
            self = .loaded(value)
        case .failed:
            let error = try container.decode(NetworkError.self, forKey: .error)
            self = .failed(error)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .idle:
            try container.encode(State.idle, forKey: .state)
        case .loading(let progress, let message):
            try container.encode(State.loading, forKey: .state)
            try container.encodeIfPresent(progress, forKey: .progress)
            try container.encodeIfPresent(message, forKey: .message)
        case .loaded(let value):
            try container.encode(State.loaded, forKey: .state)
            try container.encode(value, forKey: .value)
        case .failed(let error):
            try container.encode(State.failed, forKey: .state)
            try container.encode(error, forKey: .error)
        }
    }
}

// MARK: - SwiftUI Integration

extension Loadable {
    
    /// Create a ViewBuilder that handles all loadable states
    @ViewBuilder
    func render<Content: View, LoadingView: View, ErrorView: View>(
        @ViewBuilder content: (T) -> Content,
        @ViewBuilder loading: () -> LoadingView = { ProgressView() },
        @ViewBuilder error: (NetworkError) -> ErrorView
    ) -> some View {
        switch self {
        case .idle:
            ProgressView("Preparing...")
                .foregroundColor(.secondary)
        case .loading(let progress, let message):
            VStack(spacing: 8) {
                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                } else {
                    loading()
                }
                
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .loaded(let value):
            content(value)
        case .failed(let networkError):
            error(networkError)
        }
    }
    
    /// Simplified render method for common use cases
    @ViewBuilder
    func render<Content: View>(
        @ViewBuilder content: (T) -> Content,
        loadingMessage: String = "Loading..."
    ) -> some View {
        render(
            content: content,
            loading: { 
                VStack {
                    ProgressView()
                    Text(loadingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            },
            error: { networkError in
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 4) {
                        Text(networkError.title)
                            .font(.headline)
                        
                        Text(networkError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        )
    }
}

// MARK: - Convenience Initializers

extension Loadable {
    
    /// Create a loading state with progress
    static func loading(progress: Double, message: String? = nil) -> Loadable<T> {
        return .loading(progress: progress, message: message)
    }
    
    /// Create a loading state with just a message
    static func loading(message: String) -> Loadable<T> {
        return .loading(progress: nil, message: message)
    }
    
    /// Create a failed state from any error
    static func failedWithError(_ error: Error) -> Loadable<T> {
        return .failed(ErrorMapper.map(error))
    }
}

// MARK: - Array Extensions

extension Array where Element: LoadableType {
    
    /// Check if all elements are loaded
    var allLoaded: Bool {
        return allSatisfy { $0.isLoaded }
    }
    
    /// Check if any element is loading
    var anyLoading: Bool {
        return contains { $0.isLoading }
    }
    
    /// Check if any element has failed
    var anyFailed: Bool {
        return contains { $0.isFailed }
    }
    
    /// Get all loaded values
    var loadedValues: [Element.LoadedType] {
        return compactMap { $0.value }
    }
    
    /// Get all errors
    var errors: [NetworkError] {
        return compactMap { $0.error }
    }
}

// MARK: - LoadableType Protocol

protocol LoadableType {
    associatedtype LoadedType
    
    var isLoading: Bool { get }
    var isLoaded: Bool { get }
    var isFailed: Bool { get }
    var value: LoadedType? { get }
    var error: NetworkError? { get }
}

extension Loadable: LoadableType {
    typealias LoadedType = T
}

// MARK: - Combine Integration

import Combine

extension Loadable {
    
    /// Convert to AnyPublisher
    func publisher() -> AnyPublisher<Loadable<T>, Never> {
        return Just(self).eraseToAnyPublisher()
    }
    
    /// Create from a Future
    static func from<P: Publisher>(_ publisher: P) -> AnyPublisher<Loadable<T>, Never> 
    where P.Output == T, P.Failure == Never {
        return publisher
            .map { Loadable.loaded($0) }
            .prepend(.loading())
            .eraseToAnyPublisher()
    }
    
    /// Create from a throwing Future
    static func from<P: Publisher>(_ publisher: P) -> AnyPublisher<Loadable<T>, Never> 
    where P.Output == T, P.Failure == Error {
        return publisher
            .map { Loadable.loaded($0) }
            .catch { error in
                Just(Loadable.failed(ErrorMapper.map(error)))
            }
            .prepend(.loading())
            .eraseToAnyPublisher()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension Loadable: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .idle:
            return "Loadable.idle"
        case .loading(let progress, let message):
            let progressDesc = progress.map { String(format: "%.1f%%", $0 * 100) } ?? "unknown"
            let messageDesc = message ?? "no message"
            return "Loadable.loading(progress: \(progressDesc), message: \(messageDesc))"
        case .loaded(let value):
            return "Loadable.loaded(\(value))"
        case .failed(let error):
            return "Loadable.failed(\(error.debugDescription))"
        }
    }
}

extension Loadable {
    /// Create sample loadable states for testing/previews
    static func sampleStates() -> [Loadable<T>] where T == String {
        return [
            .idle,
            .loading(progress: 0.3, message: "Loading data..."),
            .loaded("Sample data" as! T),
            .failed(.connectivity("No internet connection"))
        ]
    }
}
#endif