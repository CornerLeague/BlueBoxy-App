//
//  FixtureLoader.swift
//  BlueBoxyTests
//
//  Utility for loading JSON fixtures in tests
//

import XCTest
import Foundation

final class FixtureLoader {
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}