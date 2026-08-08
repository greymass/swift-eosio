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

    func testPublicKeyWA() {
        AssertABICodable(
            ["PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC" as PublicKey],
            """
            ["PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC"]
            """,
            "01020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F73642E696E76616C6964"
        )
    }

    func testSignatureWA() {
        AssertABICodable(
            ["SIG_WA_2AAAuLJS3pLPgkQQPqLsehL6VeRBaAZS7NYM91UYRUrSAEfUvzKN7DCSwhjsDqe74cZNWKUUGAHGG8ddSA7cvUxChbfKxLSrDCpwe6MVUqz4PDdyCt5tXhEJmKekxG1o1ucY3LVj8Vi9rRbzAkKPCzWqC8cPcUtpLHNG8qUKkQrN4Xuwa9W8rsBiUKwZv1ToLyVhLrJe42pvHYBXicp4E8qec5E4m6SX11KuXERFcV48Mhiie2NyaxdtNtNzQ5XZ5hjBkxRujqejpF4SNHvdAGKRBbvhkiPLA25FD3xoCbrN26z72" as Signature],
            """
            ["SIG_WA_2AAAuLJS3pLPgkQQPqLsehL6VeRBaAZS7NYM91UYRUrSAEfUvzKN7DCSwhjsDqe74cZNWKUUGAHGG8ddSA7cvUxChbfKxLSrDCpwe6MVUqz4PDdyCt5tXhEJmKekxG1o1ucY3LVj8Vi9rRbzAkKPCzWqC8cPcUtpLHNG8qUKkQrN4Xuwa9W8rsBiUKwZv1ToLyVhLrJe42pvHYBXicp4E8qec5E4m6SX11KuXERFcV48Mhiie2NyaxdtNtNzQ5XZ5hjBkxRujqejpF4SNHvdAGKRBbvhkiPLA25FD3xoCbrN26z72"]
            """,
            "010220D9132BBDB219E4E2D99AF9C507E3597F86B615814F36672D501034861792BBCF21A46D1A2EB12BACE4A29100B942F987494F3AEFC8EFB2D5AF4D4D8DE3E0871525AA14905AF60CA17A1BB80E0CF9C3B46908A0F14F72567A2F140C3A3BD2EF074C010000006D737B226F726967696E223A2268747470733A2F2F6B656F73642E696E76616C6964222C2274797065223A22776562617574686E2E676574222C226368616C6C656E6765223A226F69567235794848304A4336453962446675347142735A6A527A70416C5131505A50436E5974766850556B3D227D"
        )
    }

    func testPublicKeyR1() {
        AssertABICodable(
            ["PUB_R1_82ua5qburg82c9eWY1qZVNUAAD6VPHsTMoPMGDrk7s4BQgxEoc" as PublicKey],
            """
            ["PUB_R1_82ua5qburg82c9eWY1qZVNUAAD6VPHsTMoPMGDrk7s4BQgxEoc"]
            """,
            "0101039E338BB411813F6B10A9D5DAC9CF1AFEEDC698FF5726F81B521F6C328459B936"
        )
    }

    func testSignatureR1() {
        AssertABICodable(
            ["SIG_R1_K5VEcCFUxF2jptQJUjVhV99PNiBXur6kdz6xuHtqvjqoTnzGqcCkEpD6cuA4q9DPdEHysdXjfksLB5xfkERxBuWxb9QJ8y" as Signature],
            """
            ["SIG_R1_K5VEcCFUxF2jptQJUjVhV99PNiBXur6kdz6xuHtqvjqoTnzGqcCkEpD6cuA4q9DPdEHysdXjfksLB5xfkERxBuWxb9QJ8y"]
            """,
            "01011F4E35AD2C5959634DAB0EFF0303B2CFA4B81B1FF3943E6B8B06BD9BDAA720748865B8D9C2566E1E9695BF179D5FAD5FC81E78982841F7654BD6F69ECF2B7A20BA"
        )
    }

    /// All three key formats in one stream, with distinct weights so a misread offset
    /// cannot coincidentally produce the expected value.
    func testAuthorityWithAllKeyTypes() {
        AssertABICodable(
            Authority(
                threshold: 3,
                keys: [
                    KeyWeight("PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB", weight: 1),
                    KeyWeight("PUB_R1_82ua5qburg82c9eWY1qZVNUAAD6VPHsTMoPMGDrk7s4BQgxEoc", weight: 2),
                    KeyWeight("PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC", weight: 3),
                ]
            ),
            """
            {"threshold": 3,
             "keys": [{"key": "PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB", "weight": 1},
                      {"key": "PUB_R1_82ua5qburg82c9eWY1qZVNUAAD6VPHsTMoPMGDrk7s4BQgxEoc", "weight": 2},
                      {"key": "PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC", "weight": 3}],
             "accounts": [],
             "waits": []}
            """,
            "0300000003000223E0AE8AACB41B06DC74AF1A56B2EB69133F07F7F75BD1D5E53316BFF195EDF4010001039E338BB411813F6B10A9D5DAC9CF1AFEEDC698FF5726F81B521F6C328459B9360200020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F73642E696E76616C696403000000"
        )
    }

    /// A WA key is variable-length, so a decoder that assumes a fixed width leaves the
    /// stream mid-key and silently misreads every field after it. Before the fix the
    /// second key's weight decodes as 3329 and the accounts array length as 107.
    func testAuthorityWithWAKey() {
        AssertABICodable(
            Authority(
                threshold: 2,
                keys: [
                    KeyWeight("PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB"),
                    KeyWeight("PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC"),
                ]
            ),
            """
            {"threshold": 2,
             "keys": [{"key": "PUB_K1_5AHoNnWetuDhKWSDx3WUf8W7Dg5xjHCMc4yHmmSiaJCFvvAgnB", "weight": 1},
                      {"key": "PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC", "weight": 1}],
             "accounts": [],
             "waits": []}
            """,
            "0200000002000223E0AE8AACB41B06DC74AF1A56B2EB69133F07F7F75BD1D5E53316BFF195EDF40100020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F73642E696E76616C696401000000"
        )
    }

    /// Wallets decode and re-encode action data untyped against a fetched ABI. The
    /// populated binary extension matches Vaulta's live `updateauth` action and must
    /// round-trip without adding an optional-presence byte to the signing payload.
    func testUntypedUpdateAuthWithWAKeyAndBinaryExtension() throws {
        let abi = ABI(
            structs: [
                ["key_weight": [["key", "public_key"], ["weight", "uint16"]]],
                ["permission_level": [["actor", "name"], ["permission", "name"]]],
                ["permission_level_weight": [["permission", "permission_level"], ["weight", "uint16"]]],
                ["wait_weight": [["wait_sec", "uint32"], ["weight", "uint16"]]],
                ["authority": [
                    ["threshold", "uint32"],
                    ["keys", "key_weight[]"],
                    ["accounts", "permission_level_weight[]"],
                    ["waits", "wait_weight[]"],
                ]],
                ["updateauth": [
                    ["account", "name"],
                    ["permission", "name"],
                    ["parent", "name"],
                    ["auth", "authority"],
                    ["authorized_by", "name$"],
                ]],
            ],
            actions: ["updateauth"]
        )

        let data = Data(hexEncoded: "000000A00393B17A00000000A8ED323200000000A8ED3232" +
            "0200000002000223E0AE8AACB41B06DC74AF1A56B2EB69133F07F7F75BD1D5E53316BFF195EDF40100" +
            "020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F73642E696E76616C696401000000" +
            "00000000A8ED3232")

        let decoded = try ABIDecoder().decode("updateauth", from: data, using: abi) as! [String: Any]
        let auth = decoded["auth"] as! [String: Any]
        let keys = auth["keys"] as! [Any]

        XCTAssertEqual(keys.count, 2)
        let waKey = (keys[1] as! [String: Any])
        XCTAssertEqual(
            (waKey["key"] as? PublicKey)?.stringValue,
            "PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC"
        )
        // The fields after the WA key are where a truncated read shows up first.
        XCTAssertEqual(waKey["weight"] as? UInt16, 1)
        XCTAssertEqual((auth["accounts"] as! [Any]).count, 0)
        XCTAssertEqual((auth["waits"] as! [Any]).count, 0)
        XCTAssertEqual(decoded["authorized_by"] as? Name, "active")

        let reencoded = try ABIEncoder().encode(decoded, asType: "updateauth", using: abi)
        XCTAssertEqual(reencoded, data)
    }

    /// An rpid longer than 127 bytes needs a multi-byte varuint length prefix, which
    /// must be preserved verbatim for the payload to stay canonical.
    func testPublicKeyWAWithMultiByteLengthPrefix() {
        let rpid = String(repeating: "a", count: 196) + ".com"
        let hex = "020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F01C801"
            + rpid.utf8.map { String(format: "%02X", $0) }.joined()
        let key = try! ABIDecoder.decode(PublicKey.self, data: Data(hexEncoded: hex))

        XCTAssertEqual(key.keyType, "WA")
        XCTAssertEqual(key.stringValue, "PUB_WA_BU1GFsHVzzcnmjQMQedLkff4ns8cgFfHPr6AdSHNYmxwQ1CNjhAv1pGi5fPVEX5qzQeWhABYhLbhqkVAG2hg98VpuvHoZ97NDSrAUaSZWmRo8shVqJEr1GCj5mjtA5tSDYNzS2J9FobpkVVnBwQWKU6qsNEYjdLo7CwfybXsqvBafpG3odZRZz3wMhtZYt5pgPTVrrhHcHQ2vfG5D5QQz3jJJRVHakQBx5YuZ3t3tuWE72WMWjK6PLHP3DQ2HqiJ19MYb62wyN1wSLe2hiX7mQzwTCUGxMks9jbdhmC5RqeVkDKqsM3UWSZ6UKYJytZbGJhAAeK")
        XCTAssertEqual((try! ABIEncoder.encode(key) as Data).hexEncodedString(), hex.lowercased())
    }

    /// The invariant the fixed-width read broke: a key is the same value however it
    /// arrives. Wallets mix both paths, matching a JSON-sourced key against one decoded
    /// from action data.
    func testWAKeyIsEqualAcrossCodingPaths() {
        let fromString: PublicKey = "PUB_WA_WdCPfafVNxVMiW5ybdNs83oWjenQXvSt1F49fg9mv7qrCiRwHj5b38U3ponCFWxQTkDsMC"
        let hex = "020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F73642E696E76616C6964"
        let fromAbi = try! ABIDecoder.decode(PublicKey.self, data: Data(hexEncoded: hex))
        XCTAssertEqual(fromString, fromAbi)
        XCTAssertEqual(fromString.hashValue, fromAbi.hashValue)
        XCTAssertEqual(fromString.keyData, fromAbi.keyData)
    }

    func testTruncatedWAValuesThrow() {
        // Key claiming a 13-byte rpid but carrying only 5 bytes of it.
        XCTAssertThrowsError(try ABIDecoder.decode(
            PublicKey.self,
            data: Data(hexEncoded: "020220B9DAB512E892392A44A9F41F9433C9FBD80DB864E9DF5889C2407DB3ACBB9F010D6B656F7364")
        ))
        // Key cut off inside the fixed-width portion.
        XCTAssertThrowsError(try ABIDecoder.decode(
            PublicKey.self,
            data: Data(hexEncoded: "020220B9DAB512E892392A44A9F41F9433C9FBD")
        ))
        // Signature with the first blob present and the second missing entirely.
        XCTAssertThrowsError(try ABIDecoder.decode(
            Signature.self,
            data: Data(hexEncoded: "02" + String(repeating: "AA", count: 65) + "0401020304")
        ))
    }

    func testUnknownKeyAndSignatureTypesThrow() {
        // An unrecognised variant has an unknown width, so the stream is unrecoverable.
        XCTAssertThrowsError(
            try ABIDecoder.decode(PublicKey.self, data: Data(hexEncoded: "03" + String(repeating: "AA", count: 33)))
        )
        XCTAssertThrowsError(
            try ABIDecoder.decode(Signature.self, data: Data(hexEncoded: "03" + String(repeating: "AA", count: 65)))
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
        let bts = BlockTimestamp(Date(timeIntervalSince1970: 1_234_567_890.123))
        AssertABICodable(
            [bts],
            """
            ["2009-02-13T23:31:30.000"]
            """,
            "01a47e5122"
        )
    }

    func testComplexABI() {
        let abi = try! ABI(json: loadTestResource("atomicassets.abi.json"))
        let colJson = """
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
        let colObject = try! JSONDecoder().decode("createcol", from: colJson.utf8Data, using: abi)
        let colRecoded = try! JSONEncoder().encode(colObject, asType: "createcol", using: abi)
        XCTAssertEqual(colJson.normalizedJSON, colRecoded.utf8String.normalizedJSON)

        let colData = try! ABIEncoder().encode(colObject, asType: "createcol", using: abi)
        XCTAssertEqual(colData.hexEncodedString(), "000000005c73285d000000000090b1ca0102000000005c73285d0000000050baae3902000000005c73285d0000000050baae391bde8342cac0f33f01036f6e65083d0ad73e")
        let colObject2 = try! ABIDecoder().decode("createcol", from: colData, using: abi)
        let colRecoded2 = try! JSONEncoder().encode(colObject2, asType: "createcol", using: abi)
        XCTAssertEqual(colJson.normalizedJSON, colRecoded2.utf8String.normalizedJSON)

        let templateJson = """
        {
            "authorized_creator": "foobar",
            "collection_name": "test",
            "schema_name": "test",
            "transferable": true,
            "burnable": true,
            "max_supply": 0,
            "immutable_data": [
                {"key": "one", "value": ["float32", "0.42"]},
                {"key": "name", "value": ["string", "Test"]}
            ]
        }
        """

        let templateObject = try! JSONDecoder().decode("createtempl", from: templateJson.utf8Data, using: abi)
        let templateRecoded = try! JSONEncoder().encode(templateObject, asType: "createtempl", using: abi)
        XCTAssertEqual(templateJson.normalizedJSON, templateRecoded.utf8String.normalizedJSON)

        let templateData = try! ABIEncoder().encode(templateObject, asType: "createtempl", using: abi)
        XCTAssertEqual(templateData.hexEncodedString(), "000000005c73285d000000000090b1ca000000000090b1ca01010000000002036f6e65083d0ad73e046e616d650a0454657374")
        let templateObject2 = try! ABIDecoder().decode("createtempl", from: templateData, using: abi)
        let templateRecoded2 = try! JSONEncoder().encode(templateObject2, asType: "createtempl", using: abi)
        XCTAssertEqual(templateJson.normalizedJSON, templateRecoded2.utf8String.normalizedJSON)

    }

    func testComplexVariant() {
        let abi = try! ABI(json: loadTestResource("variant.abi.json"))
        let actionJSON = """
        {
            "authorized_account": "foobarfoobar",
            "group": {
                "logical_operator": 0,
                "filters": [
                    [
                        "COLLECTION_HOLDINGS",
                        {
                            "collection_name": "alpacaworlds",
                            "comparison_operator": 3,
                            "amount": 1
                        }
                    ]
                ]
            }
        }
        """
        let actionData = try! JSONSerialization.jsonObject(with: actionJSON.utf8Data, options: [])
        let encoded = try! ABIEncoder().encode(actionData, asType: "addproofown", using: abi)
        XCTAssertEqual(encoded, "70cda1745d73285d0001028053bc941b646a340301000000")
        let decoded = try! ABIDecoder().decode("addproofown", from: encoded, using: abi)
        let json = try! JSONEncoder().encode(decoded, asType: "addproofown", using: abi)
        XCTAssertEqual(json.utf8String.normalizedJSON, actionJSON.normalizedJSON)
    }
}
