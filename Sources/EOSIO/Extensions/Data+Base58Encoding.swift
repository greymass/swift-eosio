/// Base58 encoding and decoding extensions for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import crypto
import Foundation

internal extension Data {
    /// Base58 encoding and decoding options.
    struct Base58CheckOptions: OptionSet {
        let rawValue: Int
        /// Use graphene-style ripem160 checksum.
        static let grapheneChecksum = Base58CheckOptions(rawValue: 1 << 0)
    }

    /// Creates a new data buffer from a Base58Check-encoded string.
    /// - Parameter options: Options to use when encoding string.
    /// - Note: Returns `nil` if decoding or the check fails.
    init?(base58CheckEncoded str: String, options: Base58CheckOptions = []) {
        let len: size_t = str.lengthOfBytes(using: .utf8)
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { data.deallocate() }
        let res = str.withCString { str -> Int in
            if options.contains(.grapheneChecksum) {
                return base58gph_decode_check(str, data, len)
            } else {
                return base58_decode_check(str, data, len)
            }
        }
        guard res > 0 else {
            return nil
        }
        self = Data(bytes: data, count: res)
    }

    /// Creates a new data buffer from a Base58-encoded string.
    /// - Note: Returns `nil` if decoding fails.
    init?(base58Encoded str: String) {
        let len: size_t = str.lengthOfBytes(using: .utf8)
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { data.deallocate() }
        let res = str.withCString { str -> Int in
            base58_decode(str, data, len)
        }
        guard res > 0 else {
            return nil
        }
        self = Data(bytes: data, count: res)
    }

    /// Returns a Base58Check-encoded string.
    /// - Parameter options: Options to use when encoding string.
    /// - Note: Returns `nil` if data buffer is empty or larger than 4kb.
    func base58CheckEncodedString(options: Base58CheckOptions = []) -> String? {
        let strsize = self.count * 2
        let str = UnsafeMutablePointer<Int8>.allocate(capacity: strsize)
        defer { str.deallocate() }
        let res = self.withUnsafeBytes { ptr -> Int in
            guard !ptr.isEmpty, ptr.count <= 4000 else {
                return 0
            }
            if options.contains(.grapheneChecksum) {
                return base58gph_encode_check(ptr.bufPtr, ptr.count, str, strsize)
            } else {
                return base58_encode_check(ptr.bufPtr, ptr.count, str, strsize)
            }
        }
        guard res > 0 else {
            return nil
        }
        return String(cString: str)
    }

    /// Encode data into base58 format.
    /// - Returns: Base58-encoded string or `nil` if encoding fails.
    /// - Note: Returns `nil` if data buffer is empty or larger than 4kb.
    func base58EncodedString() -> String? {
        let strsize = self.count * 2
        let str = UnsafeMutablePointer<Int8>.allocate(capacity: strsize)
        defer { str.deallocate() }
        let res = self.withUnsafeBytes { ptr -> Int in
            guard !ptr.isEmpty, ptr.count <= 4000 else {
                return 0
            }
            return base58_encode(ptr.bufPtr, ptr.count, str, strsize)
        }
        guard res > 0 else {
            return nil
        }
        return String(cString: str)
    }
}
