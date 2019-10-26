@testable import EOSIO
import Foundation
import XCTest

/// Loads a file from the Tests/Resources directory.
func loadTestResource(_ name: String) -> Data {
    let path = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("../Resources", isDirectory: true)
        .appendingPathComponent(name)
    return try! Data(contentsOf: path)
}

/// Loads a testing data json and binary pair from test resources directory.
func loadTestDataPair(_ name: String) -> (json: String, bin: Data) {
    let json = String(bytes: loadTestResource("\(name).json"), encoding: .utf8)!
    let bin = loadTestResource("\(name).bin")
    return (json, bin)
}

/// Decodes and re-encodes a JSON string with sorted keys and formatting.
/// Also removes null keys, see: https://bugs.swift.org/browse/SR-9232
func normalizeJSON(_ json: String) -> String {
    let obj = try! JSONSerialization.jsonObject(with: json.data(using: .utf8)!, options: [])
    let opts: JSONSerialization.WritingOptions
    #if os(Linux)
        opts = [.prettyPrinted, .sortedKeys]
    #else
        if #available(macOS 10.13, *) {
            opts = [.prettyPrinted, .sortedKeys]
        } else {
            opts = .prettyPrinted
        }
    #endif
    let data = try! JSONSerialization.data(withJSONObject: obj, options: opts)
    return String(bytes: data, encoding: .utf8)!
}

/// Asserts that given value encodes both to expected json and binary abi and back.
func AssertABICodable<T: ABICodable & Equatable>(_ value: T,
                                                 _ expectedJson: String,
                                                 _ expectedAbi: Data,
                                                 file: StaticString = #file,
                                                 line: UInt = #line) {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    jsonEncoder.dataEncodingStrategy = .custom { data, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(data.hexEncodedString())
    }
    let jsonDecoder = JSONDecoder()
    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    jsonDecoder.dataDecodingStrategy = .custom { decoder -> Data in
        let container = try decoder.singleValueContainer()
        return Data(hexEncoded: try container.decode(String.self))
    }
    let actualAbi: Data
    let actualJson: String
    let valueFromAbi: T
    let valueFromJson: T
    let valueFromExpectedAbi: T
    do {
        actualAbi = try ABIEncoder.encode(value)
        let actualJsonData = try jsonEncoder.encode(value)
        actualJson = String(bytes: actualJsonData, encoding: .utf8)!
        valueFromAbi = try ABIDecoder.decode(T.self, data: actualAbi)
        valueFromJson = try jsonDecoder.decode(T.self, from: actualJsonData)
        valueFromExpectedAbi = try ABIDecoder.decode(T.self, data: expectedAbi)
    } catch {
        XCTFail("Coding error: \(error)", file: file, line: line)
        return
    }
    XCTAssertEqual(actualAbi.hexEncodedString(), expectedAbi.hexEncodedString(), file: file, line: line)
    XCTAssertEqual(normalizeJSON(actualJson), normalizeJSON(expectedJson), file: file, line: line)
    XCTAssertEqual(valueFromAbi, value, file: file, line: line)
    XCTAssertEqual(valueFromJson, value, file: file, line: line)
    XCTAssertEqual(valueFromExpectedAbi, value, file: file, line: line)
}

extension Data: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(hexEncoded: value.removingAllWhitespacesAndNewlines)
    }
}

extension StringProtocol where Self: RangeReplaceableCollection {
    var removingAllWhitespacesAndNewlines: Self {
        return filter { !$0.isNewline && !$0.isWhitespace }
    }

    mutating func removeAllWhitespacesAndNewlines() {
        removeAll { $0.isNewline || $0.isWhitespace }
    }
}

extension String {
    var utf8Data: Data {
        return Data(self.utf8)
    }
}
