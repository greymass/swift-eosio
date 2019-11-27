@testable import EOSIO
import XCTest

class SigningRequestTests: XCTestCase {
    func testCreateResolve() {
        let action = try! Action(
            account: "eosio.token",
            name: "transfer",
            authorization: [SigningRequest.placeholderPermission],
            value: Transfer(
                from: SigningRequest.placeholder,
                to: "foo",
                quantity: "1 PENG",
                memo: "Thanks for the fish"
            )
        )
        let req = SigningRequest(chainId: ChainId(.eos), actions: [action], callback: "https://example.com?tx={{tx}}")
        XCTAssertEqual(req.actions, [action])
        XCTAssertEqual(req.transaction, Transaction(TransactionHeader.zero, actions: [action]))
        XCTAssertEqual(req.requiredAbis, ["eosio.token"])
        let header = TransactionHeader(expiration: 0, refBlockNum: 0, refBlockPrefix: 0)
        let resolved = try! req.resolve(using: "bar@active", abis: ["eosio.token": Transfer.abi], tapos: header)

        XCTAssertEqual(resolved.transaction.actions.first?.authorization.first, "bar@active")
        XCTAssertEqual(try? resolved.transaction.actions.first?.data(as: Transfer.self).from, "bar")
        XCTAssertEqual(resolved.transaction.id, "cf3bc0107cceec48278665269b85d97643d399e9fc3e283f63d6ef074c52b804")

        let cb = resolved.getCallback(
            using: ["SIG_K1_KdHDFseJF6paedvSbfHFZzhbtBDVAM8LxeDJsrG33sENRbUQMFHX8CvtT9wRLo4fE4QGYtbp1rF6BqNQ6Pv5XgSocXwM67"],
            blockId: "057c667944c37a4ddf654a6e9c45d84e899afcf663f27af44f07a378648c0515"
        )
        XCTAssertEqual(cb?.url, "https://example.com?tx=cf3bc0107cceec48278665269b85d97643d399e9fc3e283f63d6ef074c52b804")
        XCTAssertEqual(
            cb?.payload.normalizedJSON,
            """
            {
                "sig": "SIG_K1_KdHDFseJF6paedvSbfHFZzhbtBDVAM8LxeDJsrG33sENRbUQMFHX8CvtT9wRLo4fE4QGYtbp1rF6BqNQ6Pv5XgSocXwM67",
                "sp": "active",
                "sa": "bar",
                "bn": 92038777,
                "tx": "cf3bc0107cceec48278665269b85d97643d399e9fc3e283f63d6ef074c52b804",
                "bi": "057c667944c37a4ddf654a6e9c45d84e899afcf663f27af44f07a378648c0515"
            }
            """.normalizedJSON
        )
    }

    func testEncodeDecode() {
        let compressed = "eosio:gWNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwcgAAA"
        let uncompressed = "eosio:AQABAACmgjQD6jBVAAAAVy08zc0BAQAAAAAAAAABAAAAAAAAADQBAAAAAAAAAAAAAAAAAChdAQAAAAAAAAAAUEVORwAAABNUaGFua3MgZm9yIHRoZSBmaXNoAQA"
        let req1 = try! SigningRequest(compressed)
        let req2 = try! SigningRequest(uncompressed)
        XCTAssertEqual(req1, req2)
        XCTAssertEqual(try! req1.encodeUri(compress: false), uncompressed)
        XCTAssertEqual(try! req2.encodeUri(compress: true), compressed)
        XCTAssertThrowsError(try SigningRequest("eosio:gWeeeeeeeeee"))
        XCTAssertThrowsError(try SigningRequest("eosio:AQBAAAAAAAAABAAAAAAAAA"))
        XCTAssertThrowsError(try SigningRequest(""))
    }

    func testCreateSigned() {
        let key = PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6")
        let reqString = "eosio:gWNgZGBY1mTC_MoglIGBIVzX5uxZoAgIaMSCyBVvjYx0kAUYGNZZvmCGsJhd_YNBNHdGak5OvkJJRmpRKiMDAA"
        var req = try! SigningRequest(reqString)
        XCTAssertNil(req.signer)
        XCTAssertNil(req.signature)
        req.setSignature(try! key.sign(req.digest), signer: "foobar")
        XCTAssertEqual(try! req.encodeUri(), "eosio:gWNgZGBY1mTC_MoglIGBIVzX5uxZoAgIaMSCyBVvjYx0kAUYGNZZvmCGsJhd_YNBNHdGak5OvkJJRmpRKkR3TDFQtYKjRZLW-rkn5z86tuzPxn7zSXZ7lkyOdFE_-tTE8_bqS4ab6vnUd_LqHG3ZVHCmNnW9qt6zEx9amy_k_FC6nqX1Uf7TdgA")
    }

    func testVerifySigned() {
        let key = try! PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6").getPublic()
        let reqString = "eosio:gWNgZGBY1mTC_MoglIGBIVzX5uxZoAgIaMSCyBVvjYx0kAUYGNZZvmCGsJhd_YNBNHdGak5OvkJJRmpRKkR3TDFQtYKjRZLW-rkn5z86tuzPxn7zSXZ7lkyOdFE_-tTE8_bqS4ab6vnUd_LqHG3ZVHCmNnW9qt6zEx9amy_k_FC6nqX1Uf7TdgA"
        let req = try! SigningRequest(reqString)
        XCTAssertEqual(req.signature, "SIG_K1_KdHDFseJF6paedvSbfHFZzhbtBDVAM8LxeDJsrG33sENRbUQMFHX8CvtT9wRLo4fE4QGYtbp1rF6BqNQ6Pv5XgSocXwM67")
        XCTAssert(req.signature!.verify(req.digest, using: key))
    }

    func testIdentity() {
        let req = SigningRequest(chainId: ChainId(.eos),
                                 identityKey: "EOS5ZNmwoFDBPVnL2CYgZRpHqFfaK2M9bCFJJ1SapR9X4KPMabYBK",
                                 callback: "link://ch.anchor.link/1234-4567-8900")

        XCTAssertEqual(req.isIdentity, true)
        XCTAssertEqual(req.identity, nil)
        XCTAssertEqual(req.identityKey, "EOS5ZNmwoFDBPVnL2CYgZRpHqFfaK2M9bCFJJ1SapR9X4KPMabYBK")

        let resolved = try! req.resolve(using: "foo@id")
        XCTAssertEqual(resolved.transaction.header, TransactionHeader.zero)
        let action = resolved.transaction.actions[0]
        XCTAssertEqual(action.account, 0)
        XCTAssertEqual(action.name, "identity")
    }
}
