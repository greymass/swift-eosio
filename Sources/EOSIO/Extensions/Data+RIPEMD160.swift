/// RIPEMD160 hash extension for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import CCrypto
import Foundation

public extension Data {
    var ripemd160Digest: Data {
        var rv = Data(repeating: 0, count: Int(RIPEMD160_DIGEST_LENGTH))
        self.withUnsafeBytes { msg in
            guard msg.baseAddress != nil else {
                return
            }
            rv.withUnsafeMutableBytes { hash -> Void in
                ripemd160(msg.bufPtr, UInt32(msg.count), hash.bufPtr)
            }
        }
        return rv
    }
}
