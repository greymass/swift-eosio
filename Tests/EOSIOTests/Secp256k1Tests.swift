@testable import EOSIO
import XCTest

let secretKey: Data = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
let publicKey: Data = "0387d82042d93447008dfe2af762068a1e53ff394a5bf8f68a045fa642b99ea5d1"

class Secp256k1Test: XCTestCase {
    func testRandomizes() throws {
        try Secp256k1.shared.randomize(using: "beefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeefbeef")
        XCTAssertThrowsError(try Secp256k1.shared.randomize(using: ""))
    }

    func testVerifiesSecret() {
        XCTAssertTrue(Secp256k1.shared.verify(secretKey: secretKey))
        XCTAssertFalse(Secp256k1.shared.verify(secretKey: Data()))
        XCTAssertFalse(Secp256k1.shared.verify(secretKey: Data(hexEncoded: "beef")))
        XCTAssertFalse(Secp256k1.shared.verify(secretKey: Data(count: 32)))
    }

    func testPublicFromPrivate() {
        let result = try? Secp256k1.shared.createPublic(fromSecret: secretKey)
        XCTAssertEqual(result, publicKey)
    }

    func testSignAndRecover() throws {
        let message: Data = "b04a0f0301000000184a0f0301000000104b0f0301000000684a0f0301000000"
        let result = try Secp256k1.shared.sign(message: message, secretKey: secretKey)
        let recoveredKey = try Secp256k1.shared.recover(message: message, signature: result.0, recoveryId: result.1)
        XCTAssertEqual(recoveredKey, publicKey)
        let result2 = try Secp256k1.shared.sign(message: message, secretKey: secretKey, ndata: "beef")
        let recoveredKey2 = try Secp256k1.shared.recover(message: message, signature: result2.0, recoveryId: result2.1)
        XCTAssertEqual(recoveredKey, recoveredKey2)
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: message, signature: result.0, recoveryId: 2))
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: message, signature: "fafa", recoveryId: 0))
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: "beef", signature: result.0, recoveryId: result.1))
        XCTAssertTrue(Secp256k1.shared.verify(signature: result.0, message: message, publicKey: publicKey))
        XCTAssertTrue(Secp256k1.shared.verify(signature: result2.0, message: message, publicKey: publicKey))
    }

    func testCustomContext() throws {
        let ctx = Secp256k1(flags: [.sign])
        let message: Data = "b04a0f0301000000184a0f0301000000104b0f0301000000684a0f0301000000"
        _ = try ctx.sign(message: message, secretKey: secretKey)
    }

    func testSharedSecret() throws {
        let k1 = "beef000000000000000000000000000000000000000000000000000000000000" as Data
        let k2 = "face000000000000000000000000000000000000000000000000000000000000" as Data
        let k1Pub = try Secp256k1.shared.createPublic(fromSecret: k1)
        let k2Pub = try Secp256k1.shared.createPublic(fromSecret: k2)
        let s1 = try Secp256k1.shared.sharedSecret(publicKey: k1Pub, secretKey: k2)
        let s2 = try Secp256k1.shared.sharedSecret(publicKey: k2Pub, secretKey: k1)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1, "def2d32f6b849198d71118ef53dbc3b679fe2b2c174ee4242a33e1a3f34c46fcbaa698fb599ca0e36f555dde2ac913a10563de2c33572155487cd8b34523de9e")
    }
}
