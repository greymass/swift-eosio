/// SHA2 hash extension for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import CCrypto
import Foundation

public extension Data {
    /// 32-byte SHA-256 digest of data.
    var sha256Digest: Data {
        var rv = Data(repeating: 0, count: Int(SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { msg in
            guard msg.baseAddress != nil else {
                return
            }
            rv.withUnsafeMutableBytes { hash -> Void in
                sha256_Raw(msg.bufPtr, msg.count, hash.bufPtr)
            }
        }
        return rv
    }

    /// 64-byte SHA-512 digest of data.
    var sha512Digest: Data {
        var rv = Data(repeating: 0, count: Int(SHA512_DIGEST_LENGTH))
        self.withUnsafeBytes { msg in
            guard msg.baseAddress != nil else {
                return
            }
            rv.withUnsafeMutableBytes { hash -> Void in
                sha512_Raw(msg.bufPtr, msg.count, hash.bufPtr)
            }
        }
        return rv
    }
}
