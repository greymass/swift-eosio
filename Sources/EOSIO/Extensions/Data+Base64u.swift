/// Base64u encoding and decoding extensions for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public extension Data {
    init?(base64uEncoded string: String) {
        let len = string.count
        let base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: len + (4 - (len % 4)), withPad: "=", startingAt: 0)
        guard let instance = Data(base64Encoded: base64) else {
            return nil
        }
        self = instance
    }

    func base64uEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(["="]))
    }
}
