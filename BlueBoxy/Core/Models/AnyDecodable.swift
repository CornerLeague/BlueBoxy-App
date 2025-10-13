//
//  AnyDecodable.swift
//  BlueBoxy
//
//  Flexible decoding helper for handling dynamic JSON structures
//  Useful for APIs that return mixed types or optional fields
//

import Foundation

struct AnyDecodable: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as common types in order of specificity
        if let v = try? container.decode(Bool.self) { 
            value = v
            return 
        }
        if let v = try? container.decode(Int.self) { 
            value = v
            return 
        }
        if let v = try? container.decode(Double.self) { 
            value = v
            return 
        }
        if let v = try? container.decode(String.self) { 
            value = v
            return 
        }
        if let v = try? container.decode([String: AnyDecodable].self) { 
            value = v
            return 
        }
        if let v = try? container.decode([AnyDecodable].self) { 
            value = v
            return 
        }
        
        // Handle null values
        if container.decodeNil() {
            value = NSNull()
            return
        }
        
        throw DecodingError.typeMismatch(
            AnyDecodable.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported type for AnyDecodable"
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        // Encode based on the stored value type
        switch value {
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [String: AnyDecodable]:
            try container.encode(v)
        case let v as [AnyDecodable]:
            try container.encode(v)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported type for AnyDecodable encoding: \(type(of: value))"
                )
            )
        }
    }
}

// MARK: - Convenience Extensions

extension AnyDecodable {
    /// Get the underlying value as a specific type
    func get<T>() -> T? {
        return value as? T
    }
    
    /// Get as Bool
    var boolValue: Bool? {
        return value as? Bool
    }
    
    /// Get as Int
    var intValue: Int? {
        return value as? Int
    }
    
    /// Get as Double
    var doubleValue: Double? {
        return value as? Double
    }
    
    /// Get as String
    var stringValue: String? {
        return value as? String
    }
    
    /// Get as Dictionary
    var dictionaryValue: [String: AnyDecodable]? {
        return value as? [String: AnyDecodable]
    }
    
    /// Get as Array
    var arrayValue: [AnyDecodable]? {
        return value as? [AnyDecodable]
    }
    
    /// Check if value is null
    var isNull: Bool {
        return value is NSNull
    }
}

// MARK: - Debug Support

extension AnyDecodable: CustomStringConvertible {
    var description: String {
        switch value {
        case is NSNull:
            return "null"
        case let bool as Bool:
            return "\(bool)"
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return "\(double)"
        case let string as String:
            return "\"\(string)\""
        case let dict as [String: AnyDecodable]:
            let pairs = dict.map { "\"\($0.key)\": \($0.value)" }
            return "{\(pairs.joined(separator: ", "))}"
        case let array as [AnyDecodable]:
            return "[\(array.map { "\($0)" }.joined(separator: ", "))]"
        default:
            return "\(value)"
        }
    }
}