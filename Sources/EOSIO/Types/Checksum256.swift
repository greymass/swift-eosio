
import Foundation
import secp256k1

/// The EOSIO checksum256 type, a.k.a SHA256.
public struct Checksum256: Equatable, Hashable {
    let bytes: Data

    /// Create a new `Checksum256` from given data.
    /// - Parameter data: Data to be hashed.
    public static func hash(_ data: Data) -> Checksum256 {
        var hash = secp256k1_sha256()
        secp256k1_sha256_initialize(&hash)
        data.withUnsafeBytes {
            guard let p = $0.baseAddress else { return }
            secp256k1_sha256_write(&hash, p.assumingMemoryBound(to: UInt8.self), $0.count)
        }
        var bytes = Data(repeating: 0, count: 32)
        bytes.withUnsafeMutableBytes {
            guard let p = $0.baseAddress else { return }
            secp256k1_sha256_finalize(&hash, p.assumingMemoryBound(to: UInt8.self))
        }
        return Checksum256(bytes)
    }
}

extension Checksum256 {
    internal init(_ bytes: Data) {
        precondition(bytes.count == 32, "invalid checksum")
        self.bytes = bytes
    }
}

extension Checksum256: LosslessStringConvertible {
    public init?(_ description: String) {
        let data = Data(hexEncoded: description)
        guard data.count == 32 else {
            return nil
        }
        self.init(data)
    }

    public var description: String {
        return self.bytes.hexEncodedString()
    }
}

extension Checksum256: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(Data(hexEncoded: value))
    }
}

extension Checksum256: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        if data.count != 32 {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Encountered invalid checksum (expected 32 bytes got \(data.count))"
            )
        }
        self.init(try container.decode(Data.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.init(try decoder.decode(Data.self, byteCount: 32))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.bytes)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(contentsOf: self.bytes)
    }
}
