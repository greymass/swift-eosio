@testable import EOSIO
import XCTest

struct Transfer: ABICodable, Equatable {
    let from: Name
    let to: Name
    let quantity: Asset
    let memo: String

    static let abi = ABI(
        structs: [
            ["transfer": [
                ["from", "name"],
                ["to", "name"],
                ["quantity", "asset"],
                ["memo", "string"],
            ]],
        ],
        actions: ["transfer"]
    )
}

final class ABICodableTests: XCTestCase {
    func testUntypedAbi() throws {
        let jsonEncoder = JSONEncoder()
        let transferData: [String: Any] = [
            "from": "foo",
            "to": "bar",
            "quantity": "0 DUCKS",
            "memo": "thanks for the fish",
        ]

        let jsonData = try jsonEncoder.encode(transferData, asType: "transfer", using: Transfer.abi)

        let jsonDecoder = JSONDecoder()
        let decodedAny = try jsonDecoder.decode("transfer", from: jsonData, using: Transfer.abi)
        let decodedObj = decodedAny as! [String: Any]

        XCTAssertEqual(decodedObj["from"] as? Name, "foo")
        XCTAssertEqual(decodedObj["to"] as? Name, "bar")
        XCTAssertEqual(decodedObj["quantity"] as? Asset, "0 DUCKS")
        XCTAssertEqual(decodedObj["memo"] as? String, "thanks for the fish")

        let decodedTyped = try jsonDecoder.decode(Transfer.self, from: jsonData)

        XCTAssertEqual(decodedObj["from"] as? Name, decodedTyped.from)
        XCTAssertEqual(decodedObj["to"] as? Name, decodedTyped.to)
        XCTAssertEqual(decodedObj["quantity"] as? Asset, decodedTyped.quantity)
        XCTAssertEqual(decodedObj["memo"] as? String, decodedTyped.memo)

        let abiEncoder = ABIEncoder()
        let binaryFromUntyped = try abiEncoder.encode(transferData, asType: "transfer", using: Transfer.abi)
        let binaryFromTyped = (try abiEncoder.encode(decodedTyped)) as Data

        XCTAssertEqual(binaryFromUntyped.hexEncodedString(), binaryFromTyped.hexEncodedString())
    }

    func testAbiCoding() {
        let tokenAbi = loadTestDataPair("eosio.token.abi")
        AssertABICodable(
            ABI(
                structs: [
                    ABI.Struct("account", [
                        ABI.Field("balance", "asset"),
                    ]),
                    ABI.Struct("close", [
                        ABI.Field("owner", "name"),
                        ABI.Field("symbol", "symbol"),
                    ]),
                    ABI.Struct("create", [
                        ABI.Field("issuer", "name"),
                        ABI.Field("maximum_supply", "asset"),
                    ]),
                    ABI.Struct("currency_stats", [
                        ABI.Field("supply", "asset"),
                        ABI.Field("max_supply", "asset"),
                        ABI.Field("issuer", "name"),
                    ]),
                    ABI.Struct("issue", [
                        ABI.Field("to", "name"),
                        ABI.Field("quantity", "asset"),
                        ABI.Field("memo", "string"),
                    ]),
                    ABI.Struct("open", [
                        ABI.Field("owner", "name"),
                        ABI.Field("symbol", "symbol"),
                        ABI.Field("ram_payer", "name"),
                    ]),
                    ABI.Struct("retire", [
                        ABI.Field("quantity", "asset"),
                        ABI.Field("memo", "string"),
                    ]),
                    ABI.Struct("transfer", [
                        ABI.Field("from", "name"),
                        ABI.Field("to", "name"),
                        ABI.Field("quantity", "asset"),
                        ABI.Field("memo", "string"),
                    ]),
                ],
                actions: [
                    ABI.Action("close", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Close Token Balance\nsummary: 'Close {{nowrap owner}}’s zero quantity balance'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/token.png#207ff68b0406eaa56618b08bda81d6a0954543f36adc328ab3065f31a5c5d654\n---\n\n{{owner}} agrees to close their zero quantity balance for the {{symbol_to_symbol_code symbol}} token.\n\nRAM will be refunded to the RAM payer of the {{symbol_to_symbol_code symbol}} token balance for {{owner}}."),
                    ABI.Action("create", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Create New Token\nsummary: 'Create a new token'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/token.png#207ff68b0406eaa56618b08bda81d6a0954543f36adc328ab3065f31a5c5d654\n---\n\n{{$action.account}} agrees to create a new token with symbol {{asset_to_symbol_code maximum_supply}} to be managed by {{issuer}}.\n\nThis action will not result any any tokens being issued into circulation.\n\n{{issuer}} will be allowed to issue tokens into circulation, up to a maximum supply of {{maximum_supply}}.\n\nRAM will deducted from {{$action.account}}’s resources to create the necessary records."),
                    ABI.Action("issue", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Issue Tokens into Circulation\nsummary: 'Issue {{nowrap quantity}} into circulation and transfer into {{nowrap to}}’s account'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/token.png#207ff68b0406eaa56618b08bda81d6a0954543f36adc328ab3065f31a5c5d654\n---\n\nThe token manager agrees to issue {{quantity}} into circulation, and transfer it into {{to}}’s account.\n\n{{#if memo}}There is a memo attached to the transfer stating:\n{{memo}}\n{{/if}}\n\nIf {{to}} does not have a balance for {{asset_to_symbol_code quantity}}, or the token manager does not have a balance for {{asset_to_symbol_code quantity}}, the token manager will be designated as the RAM payer of the {{asset_to_symbol_code quantity}} token balance for {{to}}. As a result, RAM will be deducted from the token manager’s resources to create the necessary records.\n\nThis action does not allow the total quantity to exceed the max allowed supply of the token."),
                    ABI.Action("open", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Open Token Balance\nsummary: 'Open a zero quantity balance for {{nowrap owner}}'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/token.png#207ff68b0406eaa56618b08bda81d6a0954543f36adc328ab3065f31a5c5d654\n---\n\n{{ram_payer}} agrees to establish a zero quantity balance for {{owner}} for the {{symbol_to_symbol_code symbol}} token.\n\nIf {{owner}} does not have a balance for {{symbol_to_symbol_code symbol}}, {{ram_payer}} will be designated as the RAM payer of the {{symbol_to_symbol_code symbol}} token balance for {{owner}}. As a result, RAM will be deducted from {{ram_payer}}’s resources to create the necessary records."),
                    ABI.Action("retire", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Remove Tokens from Circulation\nsummary: 'Remove {{nowrap quantity}} from circulation'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/token.png#207ff68b0406eaa56618b08bda81d6a0954543f36adc328ab3065f31a5c5d654\n---\n\nThe token manager agrees to remove {{quantity}} from circulation, taken from their own account.\n\n{{#if memo}} There is a memo attached to the action stating:\n{{memo}}\n{{/if}}"),
                    ABI.Action("transfer", ricardian: "---\nspec_version: \"0.2.0\"\ntitle: Transfer Tokens\nsummary: 'Send {{nowrap quantity}} from {{nowrap from}} to {{nowrap to}}'\nicon: https://raw.githubusercontent.com/cryptokylin/eosio.contracts/v1.7.0/contracts/icons/transfer.png#5dfad0df72772ee1ccc155e670c1d124f5c5122f1d5027565df38b418042d1dd\n---\n\n{{from}} agrees to send {{quantity}} to {{to}}.\n\n{{#if memo}}There is a memo attached to the transfer stating:\n{{memo}}\n{{/if}}\n\nIf {{from}} is not already the RAM payer of their {{asset_to_symbol_code quantity}} token balance, {{from}} will be designated as such. As a result, RAM will be deducted from {{from}}’s resources to refund the original RAM payer.\n\nIf {{to}} does not have a balance for {{asset_to_symbol_code quantity}}, {{from}} will be designated as the RAM payer of the {{asset_to_symbol_code quantity}} token balance for {{to}}. As a result, RAM will be deducted from {{from}}’s resources to create the necessary records."),
                ],
                tables: [
                    ABI.Table("accounts", "account", "i64"),
                    ABI.Table("stat", "currency_stats", "i64"),
                ]
            ),
            tokenAbi.json,
            tokenAbi.bin
        )
    }

    func testTransfer() throws {
        AssertABICodable(
            Transfer(from: "foo", to: "bar", quantity: "1.0000 BAZ", memo: "qux"),
            """
            {
                "quantity": "1.0000 BAZ",
                "memo": "qux",
                "to": "bar",
                "from": "foo"
            }
            """,
            "000000000000285D000000000000AE3910270000000000000442415A0000000003717578"
        )
    }

    func testAbiSpec() {
        let abiAbi = loadTestDataPair("abi.abi")
        AssertABICodable(
            ABI.abi,
            abiAbi.json,
            abiAbi.bin
        )
    }

    func testPublicKey() {
        AssertABICodable(
            [PublicKey("PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB")],
            """
            ["PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB"]
            """,
            "01000223E0AE8AACB41B06DC74AF1A56B2EB69133F07F7F75BD1D5E53316BFF195EDF4"
        )
    }

    func testSignature() {
        AssertABICodable(
            [Signature("SIG_K1_KfPLgpw35iX8nfDzhbcmSBCr7nEGNEYXgmmempQspDJYBCKuAEs5rm3s4ZuLJY428Ca8ZhvR2Dkwu118y3NAoMDxhicRj9")],
            """
            ["SIG_K1_KfPLgpw35iX8nfDzhbcmSBCr7nEGNEYXgmmempQspDJYBCKuAEs5rm3s4ZuLJY428Ca8ZhvR2Dkwu118y3NAoMDxhicRj9"]
            """,
            "0100205150A67288C3B393FDBA9061B05019C54B12BDAC295FC83BEBAD7CD63C7BB67D5CB8CC220564DA006240A58419F64D06A5C6E1FC62889816A6C3DFDD231ED389"
        )
    }

    func testPermissionLevel() {
        AssertABICodable(
            SigningRequest.placeholderPermission,
            """
            {"actor": "............1", "permission": "............2"}
            """,
            "01000000000000000200000000000000"
        )
        AssertABICodable(
            [PermissionLevel(SigningRequest.actorPlaceholder, SigningRequest.actorPlaceholder)],
            """
            [{"actor": "............1", "permission": "............1"}]
            """,
            "0101000000000000000100000000000000"
        )
    }

    func testComplexAbi() {
        let decentiumAbi = loadTestDataPair("decentiumorg.abi")

        let abi1 = try! ABI(binary: decentiumAbi.bin)
        let abi2 = try! ABI(json: decentiumAbi.json.utf8Data)

        XCTAssertEqual(abi1, abi2)

        let post = loadTestDataPair("decentium-post")

        let decoded1 = try! ABIDecoder().decode("action_post", from: post.bin, using: abi1)
        let decoded2 = try! JSONDecoder().decode("action_post", from: post.json.data(using: .utf8)!, using: abi2)

        let json1 = try! JSONEncoder().encode(decoded1, asType: "action_post", using: abi1)
        let json2 = try! JSONEncoder().encode(decoded2, asType: "action_post", using: abi2)

        XCTAssertEqual(json1.utf8String.normalizedJSON, post.json.normalizedJSON)
        XCTAssertEqual(json2.utf8String.normalizedJSON, post.json.normalizedJSON)

        let bin1 = try! ABIEncoder().encode(decoded1, asType: "action_post", using: abi1)
        let bin2 = try! ABIEncoder().encode(decoded2, asType: "action_post", using: abi2)

        XCTAssertEqual(bin1, post.bin)
        XCTAssertEqual(bin2, post.bin)

        let action = Action(account: "decentiumorg", name: "post", data: bin1)
        let jsonData = try! action.jsonData(using: abi1)
        XCTAssertEqual(jsonData.utf8String.normalizedJSON, post.json.normalizedJSON)
    }

    func testTimePoint() {
        let tp = TimePoint(Date(timeIntervalSince1970: 1_234_567_890.123))
        AssertABICodable(
            [tp],
            """
            ["2009-02-13T23:31:30.123"]
            """,
            "01f8b88a3cd5620400"
        )
        let tps = TimePointSec(Date(timeIntervalSince1970: 1_234_567_890.123))
        AssertABICodable(
            [tps],
            """
            ["2009-02-13T23:31:30"]
            """,
            "01d2029649"
        )
    }

    func testComplexABI() {
        let abi = try! ABI(json: loadTestResource("atomicassets.abi.json"))
        let json = """
        {
            "author": "foobar",
            "collection_name": "test",
            "allow_notify": true,
            "authorized_accounts": ["foobar", "barfoo"],
            "notify_accounts": ["foobar", "barfoo"],
            "market_fee": "1.23456789",
            "data": [
                {"key": "one", "value": ["float32", "0.42"]}
            ]
        }
        """
        let object = try! JSONDecoder().decode("createcol", from: json.utf8Data, using: abi)
        let recoded = try! JSONEncoder().encode(object, asType: "createcol", using: abi)
        XCTAssertEqual(json.normalizedJSON, recoded.utf8String.normalizedJSON)

        let data = try! ABIEncoder().encode(object, asType: "createcol", using: abi)
        XCTAssertEqual(data.hexEncodedString(), "000000005c73285d000000000090b1ca0102000000005c73285d0000000050baae3902000000005c73285d0000000050baae391bde8342cac0f33f01036f6e65083d0ad73e")
        let object2 = try! ABIDecoder().decode("createcol", from: data, using: abi)
        let recoded2 = try! JSONEncoder().encode(object2, asType: "createcol", using: abi)
        XCTAssertEqual(json.normalizedJSON, recoded2.utf8String.normalizedJSON)
    }
}
