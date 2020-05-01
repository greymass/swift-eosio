/// Swift wrapper for libsecp256k1.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import CCrypto
import Foundation
import secp256k1

/// Class representing a libsecp256k1 context.
internal class Secp256k1 {
    struct Flags: OptionSet {
        let rawValue: Int32
        static let none = Flags(rawValue: SECP256K1_CONTEXT_NONE)
        static let sign = Flags(rawValue: SECP256K1_CONTEXT_SIGN)
        static let verify = Flags(rawValue: SECP256K1_CONTEXT_VERIFY)
    }

    enum Error: Swift.Error {
        /// The secret key is invalid or the nonce generation failed.
        case signingFailed
        /// Unable to parse compact signature.
        case invalidSignature
        /// Unable to recover public key from signature.
        case recoveryFailed
        /// Invalid private key.
        case invalidSecretKey
        /// Thrown if unable to parse public key data.
        case invalidPublicKey
        /// Thrown if randomization seed isn't 32-bytes.
        case invalidRandomSeed
        /// Thrown if randomization unexpectedly fails.
        case randomizationFailed
        /// Thrown if message isn't 32-bytes.
        case invalidMessage
    }

    /// The shared secp256k1 context.
    ///
    /// Shared context is thread-safe and should be used in most cases since creating a new
    /// context is 100 times more expensive than a signing or verifying operation.
    static let shared: Secp256k1 = {
        let ctx = Secp256k1(flags: [.sign, .verify])
        try? ctx.randomize(using: Data.random(32))
        return ctx
    }()

    private let ctx: OpaquePointer

    /// Create a new context.
    /// - Parameter flags: Flags used to initialize the context.
    init(flags: Flags = .none) {
        self.ctx = secp256k1_context_create(UInt32(flags.rawValue))
    }

    deinit {
        secp256k1_context_destroy(self.ctx)
    }

    /// Updates the context randomization to protect against side-channel leakage.
    /// - Parameter seed: 32-byte random seed.
    /// - Throws: If seed is invalid or randomization fails.
    ///
    /// While secp256k1 code is written to be constant-time no matter what secret
    /// values are, it's possible that a future compiler may output code which isn't,
    /// and also that the CPU may not emit the same radio frequencies or draw the
    /// same amount power for all values.
    ///
    /// This function provides a seed which is combined into the blinding value: that
    /// blinding value is added before each multiplication (and removed afterwards) so
    /// that it does not affect function results, but shields against attacks which
    /// rely on any input-dependent behaviour.
    ///
    /// This function has currently an effect only on contexts initialized for signing
    /// because randomization is currently used only for signing. However, this is not
    /// guaranteed and may change in the future. It is safe to call this function on
    /// contexts not initialized for signing.
    ///
    /// - Attention: Not thread-safe.
    func randomize(using seed: Data) throws {
        try seed.withUnsafeBytes {
            guard $0.count == 32 else {
                throw Error.invalidRandomSeed
            }
            guard secp256k1_context_randomize(self.ctx, $0.bufPtr) == 1 else {
                throw Error.randomizationFailed
            }
        }
    }

    /// Verify a private key.
    /// - Parameter secretKey: 32-byte secret key to verify.
    /// - Returns: true if valid; false otherwise.
    func verify(secretKey key: Data) -> Bool {
        return key.withUnsafeBytes {
            guard $0.count == 32 else {
                return false
            }
            return secp256k1_ec_seckey_verify(self.ctx, $0.bufPtr) == 1
        }
    }

    /// Serialize a public key.
    /// - Parameter publicKey: Opaque data structure that holds a parsed and valid public key.
    /// - Parameter compressed: Whether to compress the key when serializing.
    /// - Returns: 33-byte or 65-byte public key.
    private func serialize(publicKey pubkey: UnsafePointer<secp256k1_pubkey>, compressed: Bool = true) -> Data {
        var size: Int = compressed ? 33 : 65
        let flags = compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED
        var rv = Data(count: size)
        rv.withUnsafeMutableBytes {
            secp256k1_ec_pubkey_serialize(self.ctx, $0.bufPtr, &size, pubkey, UInt32(flags))
            return
        }
        return rv
    }

    /// Serialize an ECDSA signature in compact format (64 bytes + recovery id).
    /// - Parameter recoverableSignature: Opaque data structured that holds a parsed ECDSA signature, supporting pubkey recovery.
    /// - Returns: 64-byte signature and recovery id.
    private func serialize(recoverableSignature sig: UnsafePointer<secp256k1_ecdsa_recoverable_signature>) -> (Data, Int32) {
        var signature = Data(count: 64)
        var recid: Int32 = -1
        signature.withUnsafeMutableBytes {
            secp256k1_ecdsa_recoverable_signature_serialize_compact(self.ctx, $0.bufPtr, &recid, sig)
            return
        }
        return (signature, recid)
    }

    /// Compute the public key for a secret key.
    /// - Parameter fromSecret: 32-byte secret key.
    /// - Returns: 33-byte compressed public key.
    func createPublic(fromSecret key: Data) throws -> Data {
        let pubkey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer { pubkey.deallocate() }
        try key.withUnsafeBytes {
            guard $0.count == 32 else {
                throw Error.invalidSecretKey
            }
            guard secp256k1_ec_pubkey_create(self.ctx, pubkey, $0.bufPtr) == 1 else {
                throw Error.invalidSecretKey
            }
        }
        return self.serialize(publicKey: pubkey)
    }

    /// Sign a message.
    /// - Parameter message: 32-byte message to sign.
    /// - Parameter secretKey: 32-byte secret key to sign message with.
    /// - Parameter ndata: 32-bytes of rfc6979 "Additional data", optional.
    /// - Returns: 64-byte signature and recovery id.
    func sign(message: Data, secretKey key: Data, ndata: Data? = nil) throws -> (Data, Int32) {
        let sig = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
        defer { sig.deallocate() }
        try message.withUnsafeBytes {
            guard $0.count == 32 else {
                throw Error.invalidMessage
            }
            let msgPtr = $0.bufPtr
            try key.withUnsafeBytes {
                guard $0.count == 32 else {
                    throw Error.invalidSecretKey
                }
                let keyPtr = $0.bufPtr
                let res: Int32
                if let ndata = ndata {
                    res = ndata.withUnsafeBytes {
                        secp256k1_ecdsa_sign_recoverable(self.ctx, sig, msgPtr, keyPtr, nil, $0.baseAddress)
                    }
                } else {
                    res = secp256k1_ecdsa_sign_recoverable(self.ctx, sig, msgPtr, keyPtr, nil, nil)
                }
                guard res == 1 else {
                    throw Error.signingFailed
                }
            }
        }
        return self.serialize(recoverableSignature: sig)
    }

    /// Recover a public key from a message.
    /// - Parameter message: 32-byte message that was signed.
    /// - Parameter signature: 64-byte signature.
    /// - Parameter recoveryId: The recovery id (0, 1, 2 or 3)
    /// - Returns: 33-byte compressed public key.
    func recover(message: Data, signature: Data, recoveryId recid: Int32) throws -> Data {
        let sig = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
        defer { sig.deallocate() }
        try signature.withUnsafeBytes {
            guard $0.count == 64 else {
                throw Error.invalidSignature
            }
            guard secp256k1_ecdsa_recoverable_signature_parse_compact(self.ctx, sig, $0.bufPtr, recid) == 1 else {
                throw Error.invalidSignature
            }
        }
        let pubkey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer { pubkey.deallocate() }
        try message.withUnsafeBytes {
            guard $0.count == 32 else {
                throw Error.invalidMessage
            }
            guard secp256k1_ecdsa_recover(self.ctx, pubkey, sig, $0.bufPtr) == 1 else {
                throw Error.recoveryFailed
            }
        }
        return self.serialize(publicKey: pubkey)
    }

    /// Verify signature using given message and public key.
    /// - Parameter signature: 64-byte signature.
    /// - Parameter message: 32-byte message to verify.
    /// - Parameter publicKey: 33- or 65-byte public key to verify against.
    /// - Returns: `true` verification is successful, `false` otherwise.
    func verify(signature: Data, message: Data, publicKey: Data) -> Bool {
        let sig = UnsafeMutablePointer<secp256k1_ecdsa_signature>.allocate(capacity: 1)
        defer { sig.deallocate() }
        guard signature.withUnsafeBytes({
            guard $0.count == 64 else {
                return false
            }
            return secp256k1_ecdsa_signature_parse_compact(self.ctx, sig, $0.bufPtr) == 1
        }) else {
            return false
        }
        let pubkey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer { pubkey.deallocate() }
        guard publicKey.withUnsafeBytes({
            guard !$0.isEmpty else {
                return false
            }
            return secp256k1_ec_pubkey_parse(self.ctx, pubkey, $0.bufPtr, $0.count) == 1
        }) else {
            return false
        }
        return message.withUnsafeBytes { msg32 -> Bool in
            guard msg32.count == 32 else {
                return false
            }
            return secp256k1_ecdsa_verify(self.ctx, sig, msg32.bufPtr, pubkey) == 1
        }
    }

    /// Compute an EC Diffie-Hellman (ECDH) secret using SHA512.
    /// - Parameter publicKey: 33- or 65-byte public key.
    /// - Parameter secretKey: 32-byte secret key.
    /// - Returns: 64-byte shared secret.
    func sharedSecret(publicKey: Data, secretKey: Data) throws -> Data {
        let pubkey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
        defer { pubkey.deallocate() }
        try publicKey.withUnsafeBytes {
            guard !$0.isEmpty else {
                throw Error.invalidPublicKey
            }
            guard secp256k1_ec_pubkey_parse(ctx, pubkey, $0.bufPtr, $0.count) == 1 else {
                throw Error.invalidPublicKey
            }
        }
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        try secretKey.withUnsafeBytes {
            guard !$0.isEmpty else {
                throw Error.invalidSecretKey
            }
            guard secp256k1_ecdh(self.ctx, output, pubkey, $0.bufPtr, sha512_hash, nil) == 1 else {
                throw Error.invalidSecretKey
            }
        }
        return Data(bytesNoCopy: output, count: 64, deallocator: .free)
    }
}

/// EOSIO-style EDCH hash function
/// https://github.com/EOSIO/eosjs-ecc/blob/97c87d9a3ea338636ceb351116b5cc858710bd39/src/key_private.js#L81
private func sha512_hash(output: UnsafeMutablePointer<UInt8>?, x: UnsafePointer<UInt8>?, y _: UnsafePointer<UInt8>?, data _: UnsafeMutableRawPointer?) -> Int32 {
    sha512_Raw(x, 32, output)
    return 1
}
