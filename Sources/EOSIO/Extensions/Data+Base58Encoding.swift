/// Base58 encoding and decoding extensions for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import crypto
import Foundation

internal extension Data {
    /// Base58 encoding and decoding options.
    enum Base58CheckType {
        /// Use double-SHA256 checksum (Bitcoin-style).
        case sha256d
        /// Use RIPEMD160 checksum (Graphehe-style).
        case ripemd160
        /// Use RIPEMD160 checksum with extra suffix (EOSIO-style).
        case ripemd160Extra(_ extra: Data)
    }

    /// Calculate checksum for data using given checksum type.
    private static func checksum(for data: Data, using checksumType: Base58CheckType) -> Data {
        let digest: Data
        switch checksumType {
        case .sha256d:
            digest = data.sha256Digest.sha256Digest
        case .ripemd160:
            digest = data.ripemd160Digest
        case let .ripemd160Extra(extra):
            digest = (data + extra).ripemd160Digest
        }
        return digest.prefix(4)
    }

    /// Creates a new data buffer from a Base58Check-encoded string.
    /// - Parameter checksumType: Checksum to use when decoding data, defaults to the standard double-sha256.
    /// - Note: Returns `nil` if decoding or the check fails.
    init?(base58CheckEncoded str: String, _ checksumType: Base58CheckType = .sha256d) {
        guard let decoded = Data(base58Encoded: str) else {
            return nil
        }
        let data = decoded.prefix(decoded.count - 4)
        let checksum = decoded.suffix(4)
        guard Self.checksum(for: data, using: checksumType) == checksum else {
            return nil
        }
        self = data
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
    /// - Note: Returns `nil` if data buffer is empty or null..
    func base58CheckEncodedString(_ checksumType: Base58CheckType = .sha256d) -> String? {
        return (self + Self.checksum(for: self, using: checksumType)).base58EncodedString()
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
