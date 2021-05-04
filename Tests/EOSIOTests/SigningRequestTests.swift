@testable import EOSIO
import XCTest

class SigningRequestTests: XCTestCase {
    func testCreateResolve() {
        let action = try! Action(
            account: "eosio.token",
            name: "transfer",
            authorization: [SigningRequest.placeholderPermission],
            value: Transfer(
                from: SigningRequest.actorPlaceholder,
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
                "req": "esr:gmNgZGBY1mTC_MoglIGBIVzX5uxZRqAQGDBBaROYAARoxML5Aa5-7kBKOCQjMS-7WCEtv0ihJCNVIS2zOINZNqOkpKDYSl8_tSIxtyAnVS85P9e-pMK2urqkoraWAQA",
                "foo": "bar",
                "cid": "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906"
            }
            """.normalizedJSON
        )
    }

    func testResolve() {
        let obj = [
            "foo": SigningRequest.actorPlaceholder,
            "bar": SigningRequest.permissionPlaceholder,
            "baz": Name("somename"),
        ]
        let resolved = SigningRequest.resolvePlaceholders(obj, using: "theactor@theperm")
        XCTAssertEqual(resolved, [
            "foo": "theactor",
            "bar": "theperm",
            "baz": "somename",
        ])
        XCTAssertEqual(SigningRequest.actorPlaceholder, 1)
        XCTAssertEqual(SigningRequest.permissionPlaceholder, 2)
        XCTAssertEqual(SigningRequest.placeholderPermission, PermissionLevel(1, 2))
    }

    func testEncodeDecode() {
        let data: Data = "826360646058d664c2fcca20948181215cd7e6ec5946a01018c068131803023462e1fc00573f7720251c929198975dac90965fa4509291aa9096599cc1ccc00000"
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
        XCTAssertEqual(try! req1.encode(compress: true), data)
        var badData = data
        badData[0] = 0x1
        XCTAssertThrowsError(try SigningRequest(badData))
        badData = data
        badData[data.count - 2] = 0x80
        XCTAssertThrowsError(try SigningRequest(badData))
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
                                 callback: "https://ch.anchor.link/1234-4567-8900")

        XCTAssertEqual(req.isIdentity, true)
        XCTAssertEqual(req.identity, nil)

        let resolved = try! req.resolve(using: "foo@id")
        XCTAssertEqual(resolved.transaction.header, TransactionHeader.zero)
        let action = resolved.transaction.actions[0]
        XCTAssertEqual(action.account, 0)
        XCTAssertEqual(action.name, "identity")
        XCTAssertEqual(try? ABIDecoder().decode(PermissionLevel?.self, from: action.data), "foo@id")

        XCTAssertEqual(try! req.encodeUri(), "esr://AgABAwACJWh0dHBzOi8vY2guYW5jaG9yLmxpbmsvMTIzNC00NTY3LTg5MDAA")
    }

    func testMetadata() throws {
        let invitationKey = PrivateKey("5K64TPiF79H6RgRZnQxEW8zxXEC2PrurQDEKJdLAkDaegJXMAz6")
        var request = SigningRequest(chainId: ChainId(.jungle), callback: "caldav://greymass.com")
        request.setInfo("title", string: "X-Mas Rave")
        request.setInfo("location", string: "Greymass HQ")
        request.setInfo("date", string: "2019-12-24T21:00:00")
        request.setSignature(try invitationKey.sign(request.digest), signer: "teamgreymass")
        let uri = try request.encodeUri()
        XCTAssertEqual(uri, "esr://gmNgZmZgEk1OzElJLLPS108vSq3MTSwu1kvOz2VmLcksyUnlitD1TSxWCEosS-XIyU9OLMnMz-N2h6pT8AhkSUksSRU2MjC01DU00jUyCTEytDIwAKKGjRPjYtV6TzHIiwQGZR9eekvKxSfnYUd7lHLX9hrnS2FvygOyvz_8-NZNWVhfeGXW_ZfaK33nbV3k8jisnnmV8sYAj8bnWWe0LlU-vgYA")
        let decoded = try SigningRequest(uri)
        XCTAssertEqual(decoded.info, [
            "date": "2019-12-24T21:00:00",
            "title": "X-Mas Rave",
            "location": "Greymass HQ",
        ])
    }

    func testComplexMetadata() throws {
        var request = SigningRequest(chainId: ChainId(.jungle), callback: "https://greymass.com/partypay")
        request.setInfo("amount", value: Asset("1.0 MOL"))
        request.setInfo("snowman", string: "☃")
        let uri = try request.encodeUri()
        let decoded = try SigningRequest(uri)
        XCTAssertEqual(decoded.getInfo("amount", as: Asset.self)?.units, 10)
        XCTAssertEqual(decoded.getInfo("snowman", as: String.self), "☃")
    }

    func testScopedIdRequest() throws {
        let scope = Name(rawValue: UInt64.max)
        let request = SigningRequest(chainId: ChainId(.eos), scope: scope, callback: "https://example.com")
        let uri = try request.encodeUri()
        XCTAssertEqual(uri, "esr://g2NgZP4PBQxMwhklJQXFVvr6qRWJuQU5qXrJ-bkMAA")
        XCTAssertEqual(request, try SigningRequest(uri))
        XCTAssertEqual(request.identityScope, scope)
        XCTAssertEqual(request.version, 3)
        let header = TransactionHeader(expiration: "2020-07-10T08:40:20", refBlockNum: 0, refBlockPrefix: 0)
        let resolved = try request.resolve(using: "foo@active", tapos: header)
        XCTAssertEqual(resolved.transaction.expiration, "2020-07-10T08:40:20")
        XCTAssertEqual(resolved.transaction.actions.count, 1)
        XCTAssertEqual(
            resolved.transaction.actions[0].data,
            "ffffffffffffffff01000000000000285d00000000a8ed3232"
        )
        XCTAssertEqual(try resolved.transaction.digest(using: request.chainId), "70d1fd5bda1998135ed44cbf26bd1cc2ed976219b2b6913ac13f41d4dd013307")
    }

    func testResolveMsig() throws {
        let request = try SigningRequest("esr:gmNgZGJAAYwMDMURTK8MQoFsh9yqbFPGCVeviF7s9C0Gya54a2SkIKBW_MPj7ibrC7pP4o-XhaSiK2Bgss4oKSkottLXT07SS8xLzsgv0svJzMvWN0yyMDIxMzLUNUxLS9Y1STM31000TrbQNTJKNExKTrI0NTRLZuIuSi0pLcqLL0gsyTCGGVReXq6XlJOfXayXma-fW5yZrp-UWZJRmpsEZOYZ6qcXpCZl5JRWlWcXVrCArGKRuzIhAQA")
        let abi = try ABI(json: loadTestResource("eosio.msig.abi.json"))
        let header = TransactionHeader.zero
        XCTAssertNoThrow(try request.resolve(using: "foo@bar", abis: ["eosio.msig": abi], tapos: header))
    }
}
