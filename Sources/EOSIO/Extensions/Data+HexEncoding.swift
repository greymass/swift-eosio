/// Hex encoding and decoding extensions for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public extension Data {
    init(hexEncoded string: String) {
        let nibbles = string.unicodeScalars
            .map { $0.hexNibble }
            .filter { $0 != nil }
        var bytes = [UInt8](repeating: 0, count: (nibbles.count + 1) >> 1)
        for (index, nibble) in nibbles.enumerated() {
            var n = nibble!
            if index & 1 == 0 {
                n <<= 4
            }
            bytes[index >> 1] |= n
        }
        self = Data(bytes)
    }

    struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}

public extension UnicodeScalar {
    var hexNibble: UInt8? {
        let value = self.value
        if value >= 48, value <= 57 {
            return UInt8(value - 48)
        } else if value >= 65, value <= 70 {
            return UInt8(value - 55)
        } else if value >= 97, value <= 102 {
            return UInt8(value - 87)
        }
        return nil
    }
}
