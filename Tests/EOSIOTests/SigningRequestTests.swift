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
            blockNum: 12345
        )
        XCTAssertEqual(cb?.url, "https://example.com?tx=cf3bc0107cceec48278665269b85d97643d399e9fc3e283f63d6ef074c52b804")
        let payload = String(bytes: try! cb!.getPayload(extra: ["foo": "bar"]), encoding: .utf8)!
        XCTAssertEqual(
            payload.normalizedJSON,
            """
            {
                "sig": "SIG_K1_KdHDFseJF6paedvSbfHFZzhbtBDVAM8LxeDJsrG33sENRbUQMFHX8CvtT9wRLo4fE4QGYtbp1rF6BqNQ6Pv5XgSocXwM67",
                "sp": "active",
                "sa": "bar",
                "bn": "12345",
                "tx": "cf3bc0107cceec48278665269b85d97643d399e9fc3e283f63d6ef074c52b804",
                "ex": "1970-01-01T00:00:00",
                "rbn": "0",
                "rid": "0",
                "req": "esr:gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwSybUVJSUGylr59akZhbkJOql5yfa19SYVtdXVJRW8sAAA",
                "foo": "bar"
            }
            """.normalizedJSON
        )
    }

    func testEncodeDecode() {
        let compressed = "esr://gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwczAAAA"
        let uncompressed = "esr://AgABAACmgjQD6jBVAAAAVy08zc0BAQAAAAAAAAABAAAAAAAAADQBAAAAAAAAAAAAAAAAAChdAQAAAAAAAAAAUEVORwAAABNUaGFua3MgZm9yIHRoZSBmaXNoAwAA"
        let req1 = try! SigningRequest(compressed)
        let req2 = try! SigningRequest(uncompressed)
        XCTAssertEqual(req1, req2)
        XCTAssertEqual(try! req1.encodeUri(compress: false), uncompressed)
        XCTAssertEqual(try! req2.encodeUri(compress: true), compressed)
        XCTAssertThrowsError(try SigningRequest("esr:gWeeeeeeeeee"))
        XCTAssertThrowsError(try SigningRequest("esr://AQBAAAAAAAAABAAAAAAAAA"))
        XCTAssertThrowsError(try SigningRequest(""))
    }

    func testCreateSigned() {
        let key = PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6")
        let reqString = "esr://gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwczAAAA"
        var req = try! SigningRequest(reqString)
        XCTAssertNil(req.signer)
        XCTAssertNil(req.signature)
        req.setSignature(try! key.sign(req.digest), signer: "foobar")
        XCTAssertEqual(try! req.encodeUri(), "esr://gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwQxREVOsEcsgX-9-jqsy1EhNQM_GM_FkQMIziUU1VU4PsmOn_3r5hUMumeN3PXvdSuWMm1o9u6-FmCwtPvR0haqt12fNKtlWzTuiNwA")
    }

    func testVerifySigned() {
        let key = try! PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6").getPublic()
        let reqString = "esr://gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGMBoExgDAjRi4fwAVz93ICUckpGYl12skJZfpFCSkaqQllmcwQxREVOsEcsgX-9-jqsy1EhNQM_GM_FkQMIziUU1VU4PsmOn_3r5hUMumeN3PXvdSuWMm1o9u6-FmCwtPvR0haqt12fNKtlWzTuiNwA"
        let req = try! SigningRequest(reqString)
        XCTAssertEqual(req.signature, "SIG_K1_KBub1qmdiPpWA2XKKEZEG3EfKJBf38GETHzbd4t3CBdWLgdvFRLCqbcUsBbbYga6jmxfdSFfodMdhMYraKLhEzjSCsiuMs")
        XCTAssert(req.signature!.verify(req.digest, using: key))
        XCTAssertEqual(try! req.signature!.recoverPublicKey(from: req.digest), key)
    }

    func testIdentity() {
        let req = SigningRequest(chainId: ChainId(.eos),
                                 identityKey: "EOS5ZNmwoFDBPVnL2CYgZRpHqFfaK2M9bCFJJ1SapR9X4KPMabYBK",
                                 callback: "https://ch.anchor.link/1234-4567-8900")

        XCTAssertEqual(req.isIdentity, true)
        XCTAssertEqual(req.identity, nil)
        XCTAssertEqual(req.identityKey, "PUB_K1_5ZNmwoFDBPVnL2CYgZRpHqFfaK2M9bCFJJ1SapR9X4KPRdJ9eK")

        let resolved = try! req.resolve(using: "foo@id")
        XCTAssertEqual(resolved.transaction.header, TransactionHeader.zero)
        let action = resolved.transaction.actions[0]
        XCTAssertEqual(action.account, 0)
        XCTAssertEqual(action.name, "identity")

        XCTAssertEqual(try! req.encodeUri(), "esr://gmNgZGZkgABGBqYI7x9Sxl36f-rbJt9s2lUzbYe3pdtE7WnPfxy7_pAph3k5k2pGSUlBsZW-fnKGXmJeckZ-kV5OZl62vqGRsYmuiamZua6FpYEBAwA")
    }

    func testMetadata() throws {
        let invitationKey = PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6")
        var request = SigningRequest(chainId: ChainId(.jungle), callback: "caldav://greymass.com", info: [
            "date": "2019-12-24T21:00:00",
            "title": "X-Mas Rave",
            "location": "Greymass HQ",
        ])
        request.setSignature(try invitationKey.sign(request.digest), signer: "teamgreymass")
        let uri = try request.encodeUri()
        XCTAssertEqual(uri, "esr://gmNgZmZkgAIm0eTEnJTEMit9_fSi1MrcxOJiveT8XGbWksySnFSuCF3fxGKFoMSyVI6c_OTEksz8PG53qDoFj0CWlMSSVGEjA0NLXUMjXSOTECNDKwMDIGrYODEuVq33FIO8ft7PzXd__rP6cYbzhjH7Yie2hryM-ZOtmZ4LBRYuO3nhpbYG_4_5MRZvSn7IhkhGcbE2xToeLLb994XFeVGtSUY7KwA")
        let decoded = try SigningRequest(uri)
        XCTAssertEqual(decoded.info, [
            "date": "2019-12-24T21:00:00",
            "title": "X-Mas Rave",
            "location": "Greymass HQ",
        ])
    }
}
