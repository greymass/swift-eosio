@testable import EOSIO
import XCTest

let privateKeyData: Data = "D25968EBFCE6E617BDB839B5A66CFC1FDD051D79A91094F7BACEDED449F84333"
let privateKeyWif = "5KQvfsPJ9YvGuVbLRLXVWPNubed6FWvV8yax6cNSJEzB4co3zFu"

let publicKeyStr = "PUB_K1_6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeACcSRFs"
let publicKeyData: Data = "02CAEE1A02910B18DFD5D9DB0E8A4BC90F8DD34CEDBBFB00C6C841A2ABB2FA28CC"
let publicKeyLegacy = "EOS6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeABhJRin"

let message = "I like turtles"

let signatureStr = "SIG_K1_K6PhJrD6wvjzVQRwTUd82fk3Z4jznnUszjeBH7xGCAsfByCunzSN2KQ2A9ALetFwLTqnK4xvES6Bstt6NNSvGgjgM1Tcxn"
let signatureData: Data = """
1F551F8B7CB5BE8BCB261CD6BBC8338784CF87C90E76FCFA0095A630F2B6C6B72
02F095449850A8D6C62814557D74142C9DBCC72BF7B5046A67AF9333D901E7840
"""

final class CryptoTests: XCTestCase {
    func testSignsAndVerifies() {
        let pubkey = PublicKey(publicKeyStr)
        XCTAssertEqual(pubkey?.keyType, "K1")
        XCTAssertEqual(pubkey?.keyData, publicKeyData)
        XCTAssertEqual(pubkey, PublicKey(publicKeyLegacy))
        XCTAssertEqual(pubkey?.legacyStringValue, publicKeyLegacy)
        XCTAssertEqual(pubkey, "PUB_K1_6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeACcSRFs")

        let privkey = PrivateKey(privateKeyWif)
        XCTAssertEqual(privkey?.keyType, "K1")
        XCTAssertEqual(privkey?.keyData, privateKeyData)
        XCTAssertEqual(privkey?.stringValue, privateKeyWif)
        XCTAssertEqual(try? privkey?.getPublic(), pubkey)

        let sig = Signature(signatureStr)
        XCTAssertEqual(sig?.signatureType, "K1")
        XCTAssertEqual(sig?.signatureData, signatureData)
        XCTAssertEqual(sig, "SIG_K1_K6PhJrD6wvjzVQRwTUd82fk3Z4jznnUszjeBH7xGCAsfByCunzSN2KQ2A9ALetFwLTqnK4xvES6Bstt6NNSvGgjgM1Tcxn")
        XCTAssertEqual(try? sig?.recoverPublicKey(from: message.utf8Data), pubkey)

        let sig2 = try? privkey?.sign(message.utf8Data)
        XCTAssertEqual(sig2?.signatureType, "K1")
        XCTAssertTrue(sig2?.verify(message.utf8Data, using: "EOS6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeABhJRin") ?? false)
    }

    func testEncodeDecode() {
        XCTAssertNoThrow(try PublicKey(stringValue: publicKeyStr))
        XCTAssertNoThrow(try PublicKey(stringValue: publicKeyLegacy))
        XCTAssertThrowsError(try PublicKey(stringValue: "garbage"))
        XCTAssertThrowsError(try PublicKey(stringValue: "EOSgarbage"))
        XCTAssertThrowsError(try PublicKey(stringValue: "WAT_K1_6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeACcSRFs"))
        XCTAssertThrowsError(try PublicKey(stringValue: "PUB_XY_6RrvujLQN1x5Tacbep1KAk8zzKpSThAQXBCKYFfGUYeACcSRFs"))
        XCTAssertThrowsError(try PublicKey(stringValue: "PUB_NANI_3ALoL8VvcHTAHvG95"))
        XCTAssertThrowsError(try PublicKey(fromK1Data: Data(repeating: 0, count: 10)))

        let unknownSig = Signature("SIG_XY_5EL7pLoLEPEMJ3Qr4")
        XCTAssertEqual(unknownSig.signatureType, "XY")
        XCTAssertEqual(unknownSig.signatureData, "e02547629a714b7e")
        XCTAssertEqual(unknownSig.stringValue, "SIG_XY_5EL7pLoLEPEMJ3Qr4")

        let unknownPub = PublicKey("PUB_XY_5EL7pLoLEPEMJ3Qr4")
        XCTAssertEqual(unknownPub.keyType, "XY")
        XCTAssertEqual(unknownPub.keyData, "e02547629a714b7e")
        XCTAssertEqual(unknownPub.stringValue, "PUB_XY_5EL7pLoLEPEMJ3Qr4")
        XCTAssertNil(unknownPub.legacyStringValue)

        let unknownPriv = PrivateKey("PVT_XY_5EL7pLoLEPEMJ3Qr4")
        XCTAssertEqual(unknownPriv.keyType, "XY")
        XCTAssertEqual(unknownPriv.keyData, "e02547629a714b7e")
        XCTAssertEqual(unknownPriv.stringValue, "PVT_XY_5EL7pLoLEPEMJ3Qr4")

        XCTAssertEqual("\(unknownPriv)", "PrivateKeyXY")

        XCTAssertNil(PublicKey("garbage" as String))
        XCTAssertNil(PrivateKey("garbage" as String))
        XCTAssertNil(Signature("garbage" as String))

        XCTAssertEqual(
            "PVT_K1_zVFeDTSxD6KDCjQomkzZMdB5AiaR3EnCZLrxmsx5tDzH937km" as PrivateKey,
            "5JomqKfYXQn5aDb1T1Df5c6kPfzdnYuKW1d868pdBxjs9quS1xE"
        )
    }

    func testSharedSecret() {
        let k1 = PrivateKey("5KGNiwTYdDWVBc9RCC28hsi7tqHGUsikn9Gs8Yii93fXbkYzxGi")
        let k2 = PrivateKey("5Kik3tbLSn24ScHFsj6GwLkgd1H4Wecxkzt1VX7PBBRDQUCdGFa")
        let s1 = try! k1.sharedSecret(for: try! k2.getPublic())
        let s2 = try! k2.sharedSecret(for: try! k1.getPublic())
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1, "def2d32f6b849198d71118ef53dbc3b679fe2b2c174ee4242a33e1a3f34c46fcbaa698fb599ca0e36f555dde2ac913a10563de2c33572155487cd8b34523de9e")
    }
}
