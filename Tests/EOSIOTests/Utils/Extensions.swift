import EOSIO
import Foundation

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

extension Data {
    var utf8String: String {
        return String(bytes: self, encoding: .utf8)!
    }

    var normalizedJSON: Data {
        return self.utf8String.normalizedJSON.utf8Data
    }
}

extension String {
    var utf8Data: Data {
        return Data(self.utf8)
    }

    /// Decodes and re-encodes a JSON string with sorted keys and formatting.
    /// Also removes null keys, see: https://bugs.swift.org/browse/SR-9232
    var normalizedJSON: String {
        let obj = try! JSONSerialization.jsonObject(with: self.data(using: .utf8)!, options: [.allowFragments])
        let opts: JSONSerialization.WritingOptions
        #if os(Linux)
            opts = [.prettyPrinted, .sortedKeys]
        #else
            if #available(macOS 10.13, *) {
                opts = [.prettyPrinted, .sortedKeys]
            } else {
                opts = [.prettyPrinted]
            }
        #endif
        let data = try! JSONSerialization.data(withJSONObject: obj, options: opts)
        return String(bytes: data, encoding: .utf8)!
    }
}
