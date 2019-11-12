/// SHA256 hash extension for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import crypto
import Foundation

public extension Data {
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
}
