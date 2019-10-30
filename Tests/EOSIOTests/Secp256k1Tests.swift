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
        XCTAssertNotEqual(result.0, result2.0)
        let result3 = try Secp256k1.shared.sign(message: message, secretKey: secretKey, ndata: "beef")
        XCTAssertEqual(result2.0, result3.0)
        let recoveredKey2 = try Secp256k1.shared.recover(message: message, signature: result2.0, recoveryId: result2.1)
        XCTAssertEqual(recoveredKey2, recoveredKey2)
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: message, signature: result.0, recoveryId: 2))
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: message, signature: "fafa", recoveryId: 0))
        XCTAssertThrowsError(try Secp256k1.shared.recover(message: "beef", signature: result.0, recoveryId: result.1))
        XCTAssertTrue(Secp256k1.shared.verify(signature: result.0, message: message, publicKey: publicKey))
    }

    func testCustomContext() throws {
        let ctx = Secp256k1(flags: [.sign])
        let message: Data = "b04a0f0301000000184a0f0301000000104b0f0301000000684a0f0301000000"
        _ = try ctx.sign(message: message, secretKey: secretKey)
    }
}
