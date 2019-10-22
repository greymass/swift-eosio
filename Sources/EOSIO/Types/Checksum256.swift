
import Foundation
import OpenCrypto // TODO: use CryptoKit on supported platforms

/// The EOSIO checksum256 type, a.k.a SHA256.
public typealias Checksum256 = SHA256Digest

extension Checksum256 {
    internal init(_ data: Data) {
        self.init(Array(data))
    }

    internal init(_ bytes: [UInt8]) {
        precondition(bytes.count == 32, "invalid checksum")
        self = unsafeBitCast(bytes, to: Checksum256.self)
    }

    public func verify<D: DataProtocol>(_ data: D) -> Bool {
        return SHA256.hash(data: data) == self
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
        return Data(self).hexEncodedString()
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
        try container.encode(Data(self))
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(contentsOf: Data(self))
    }
}
