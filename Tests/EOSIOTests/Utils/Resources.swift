import Foundation
import XCTest

/// Path to `./Tests/Resources` directory.
let resourcePath = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .appendingPathComponent("../../Resources", isDirectory: true)
    .standardizedFileURL

/// Loads a file from the resources directory.
func loadTestResource(_ name: String) -> Data {
    return try! Data(contentsOf: resourcePath.appendingPathComponent(name))
}

/// Loads a testing data json and binary pair from test resources directory.
func loadTestDataPair(_ name: String) -> (json: String, bin: Data) {
    let json = String(bytes: loadTestResource("\(name).json"), encoding: .utf8)!
    let bin = loadTestResource("\(name).bin")
    return (json, bin)
}
