@testable import EOSIO
import XCTest

final class TypeTests: XCTestCase {
    func testName() {
        XCTAssertEqual(Name(0).stringValue, ".............")
        XCTAssertEqual(Name("foobar").stringValue, "foobar")
        XCTAssertEqual(Name("............1").rawValue, 1)
        XCTAssertEqual(Name("foo" as String), "foo")
        XCTAssertEqual(("foo" as Name).description, "foo")
        XCTAssertEqual(Name("❄︎flake"), ".flake")
    }

    func testAsset() {
        var asset = Asset(units: 42, symbol: "2,PANIC")
        XCTAssertEqual(asset.symbol, "2,PANIC")
        XCTAssertEqual(asset.value, 0.42)
        XCTAssertEqual(asset.units, 42)
        asset.units -= 84
        XCTAssertEqual(asset.value, -0.42)
        XCTAssertEqual(asset, "-0.42 PANIC")
        XCTAssertEqual(asset.stringValue, "-0.42 PANIC")
        XCTAssertEqual(asset, Asset(asset.description))
        asset.value = 0.00999999
        XCTAssertEqual(asset.value, 0)
        XCTAssertEqual(asset.units, 0)

        XCTAssertEqual("0.40 PANIC" as Asset + "0.02 PANIC", "0.42 PANIC")
        XCTAssertEqual("0.63 PANIC" as Asset - "0.21 PANIC", "0.42 PANIC")
        XCTAssertEqual("3.00 PANIC" as Asset * "0.14 PANIC", "0.42 PANIC")
        XCTAssertEqual("2.22 PANIC" as Asset / "2.00 PANIC", "1.11 PANIC")
        XCTAssertEqual("0.40 PANIC" as Asset + 0.02, "0.42 PANIC")
        XCTAssertEqual("0.63 PANIC" as Asset - 0.21, "0.42 PANIC")
        XCTAssertEqual("3.00 PANIC" as Asset * 0.14, "0.42 PANIC")
        XCTAssertEqual("2.22 PANIC" as Asset / 2, "1.11 PANIC")

        var mutable = Asset(10.0, "4,MUTS")
        mutable += 10
        mutable *= 42
        mutable -= 1
        mutable /= 16
        XCTAssertEqual(mutable, "52.4375 MUTS")
        mutable.value = 10
        mutable += "10.0000 MUTS"
        mutable *= "42.0000 MUTS"
        mutable -= "1.0000 MUTS"
        mutable /= "16.0000 MUTS"
        XCTAssertEqual(mutable, "52.4375 MUTS")

        var hpAsset = Asset(units: 1, symbol: "18,THINGS")
        XCTAssertEqual(hpAsset.value, 1e-18)
        hpAsset.value += 1e-18
        XCTAssertEqual(hpAsset.units, 2)
        XCTAssertEqual(hpAsset.stringValue, "0.000000000000000002 THINGS")

        XCTAssertThrowsError(try Asset(stringValue: "0. POPS"))
        XCTAssertThrowsError(try Asset(stringValue: "123CONS"))
        XCTAssertThrowsError(try Asset(stringValue: "num4 BAD"))
        XCTAssertNil(Asset("invalid string" as String))
        XCTAssertEqual("invalid literal" as Asset, "0 INVALID")
    }

    func testAssetSymbol() {
        let symbol = try? Asset.Symbol(4, "EOS")
        XCTAssertEqual(symbol?.precision, 4)
        XCTAssertEqual(symbol?.name, "EOS")
        XCTAssertEqual(symbol?.stringValue, "4,EOS")
        XCTAssertEqual(symbol, "4,EOS")
        XCTAssertEqual(symbol, Asset.Symbol(symbol?.description ?? ""))
        XCTAssertThrowsError(try Asset.Symbol(rawValue: 0))
        XCTAssertThrowsError(try Asset.Symbol(0, ""))
        XCTAssertThrowsError(try Asset.Symbol(4, "M0NEYz"))
        XCTAssertThrowsError(try Asset.Symbol(4, "☙FLRNZ☙"))
        XCTAssertThrowsError(try Asset.Symbol(34, "PLANCK"))
        XCTAssertThrowsError(try Asset.Symbol(stringValue: "-1,NEGS"))
        XCTAssertThrowsError(try Asset.Symbol(stringValue: "boops"))
        XCTAssertNil(Asset.Symbol("invalid string" as String))
        XCTAssertEqual("invalid literal" as Asset.Symbol, "0,INVALID")
    }

    func testTransaction() {
        let ref = loadTestDataPair("transaction")

        let header = TransactionHeader(
            expiration: "2019-05-25T01:49:05",
            refBlockNum: 23205,
            refBlockPrefix: 2_823_474_609,
            maxNetUsageWords: 0,
            maxCpuUsageMs: 0,
            delaySec: 0
        )

        let action = Action(
            account: "decentiumorg",
            name: "post",
            authorization: [
                PermissionLevel(
                    actor: "almstdigital",
                    permission: "active"
                ),
            ],
            data: """
            104d76cca58c65340b48656c6c6f20576f
            726c640100010040466f722048616e6e61
            205265792c206d61792074686520776f72
            6c6420796f752067726f7720757020696e
            2062652061732062726967687420617320
            796f752e01020100011457656c636f6d65
            20746f20446563656e7469756d00
            """
        )

        let transaction = Transaction(
            header: header,
            contextFreeActions: [],
            actions: [action],
            transactionExtensions: []
        )

        AssertABICodable(transaction, ref.json, ref.bin)
        XCTAssertEqual(transaction.id, "0ef9aa310e6e7efb7b10192dc80e5b09826c4369be6b1ba54990b8a66302500e")
    }

    func testChecksum256() {
        XCTAssertEqual(
            Checksum256.hash("hello".data(using: .utf8)!),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }
}
