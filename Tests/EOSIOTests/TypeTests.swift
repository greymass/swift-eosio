@testable import EOSIO
import XCTest

/// Asserts that given value encodes both to expected json and binary abi and back.
func AssertABICodable<T: ABICodable & Equatable>(_ value: T,
                                                 _ expectedJson: String,
                                                 _ expectedAbi: Data,
                                                 file: StaticString = #file,
                                                 line: UInt = #line)
{
    let jsonEncoder = JSONEncoder()
    jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    jsonEncoder.dataEncodingStrategy = .custom { data, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(data.hexEncodedString())
    }
    let jsonDecoder = JSONDecoder()
    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    jsonDecoder.dataDecodingStrategy = .custom { decoder -> Data in
        let container = try decoder.singleValueContainer()
        return Data(hexEncoded: try container.decode(String.self))
    }
    let actualAbi: Data
    let actualJson: String
    let valueFromAbi: T
    let valueFromJson: T
    let valueFromExpectedAbi: T
    do {
        actualAbi = try ABIEncoder.encode(value)
        let actualJsonData = try jsonEncoder.encode(value)
        actualJson = String(bytes: actualJsonData, encoding: .utf8)!
        valueFromAbi = try ABIDecoder.decode(T.self, data: actualAbi)
        valueFromJson = try jsonDecoder.decode(T.self, from: actualJsonData)
        valueFromExpectedAbi = try ABIDecoder.decode(T.self, data: expectedAbi)
    } catch {
        XCTFail("Coding error: \(error)", file: file, line: line)
        return
    }
    XCTAssertEqual(actualAbi.hexEncodedString(), expectedAbi.hexEncodedString(), file: file, line: line)
    XCTAssertEqual(actualJson.normalizedJSON, expectedJson.normalizedJSON, file: file, line: line)
    XCTAssertEqual(valueFromAbi, value, file: file, line: line)
    XCTAssertEqual(valueFromJson, value, file: file, line: line)
    XCTAssertEqual(valueFromExpectedAbi, value, file: file, line: line)
}

final class TypeTests: XCTestCase {
    func testName() {
        XCTAssertEqual(Name(0).stringValue, "")
        XCTAssertEqual("............." as Name, "")
        XCTAssertEqual(Name("foobar").stringValue, "foobar")
        XCTAssertEqual(Name("............1").rawValue, 1)
        XCTAssertEqual(Name("foo" as String), "foo")
        XCTAssertEqual(("foo" as Name).description, "foo")
        XCTAssertEqual(Name("❄︎flake"), ".flake")
        XCTAssert(Name(0).isValidAccountName == false)
        XCTAssert(Name(1).isValidAccountName == false)
        XCTAssert(Name("foobar").isValidAccountName == true)
        XCTAssert(Name("block.two").isValidAccountName == true)
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
    }

    func testAssetSymbol() {
        let symbol = try? Asset.Symbol(4, "EOS")
        XCTAssertEqual(symbol?.precision, 4)
        XCTAssertEqual(symbol?.name, "EOS")
        XCTAssertEqual(symbol?.stringValue, "4,EOS")
        XCTAssertEqual(symbol, "4,EOS")
        XCTAssertEqual(symbol, Asset.Symbol(symbol?.description ?? ""))
        XCTAssertThrowsError(try Asset.Symbol(rawSymbol: 0))
        XCTAssertThrowsError(try Asset.Symbol(0, ""))
        XCTAssertThrowsError(try Asset.Symbol(4, "M0NEYz"))
        XCTAssertThrowsError(try Asset.Symbol(4, "☙FLRNZ☙"))
        XCTAssertThrowsError(try Asset.Symbol(34, "PLANCK"))
        XCTAssertThrowsError(try Asset.Symbol(stringValue: "-1,NEGS"))
        XCTAssertThrowsError(try Asset.Symbol(stringValue: "boops"))
        XCTAssertNil(Asset.Symbol("invalid string" as String))
        AssertABICodable([Asset.Symbol("4,BAR")], "[\"4,BAR\"]", "010442415200000000")
    }

    func testTransaction() {
        let ref = loadTestDataPair("transaction")

        let header = TransactionHeader(
            expiration: "2019-05-25T01:49:05",
            refBlockNum: 23205,
            refBlockPrefix: 2_823_474_609
        )

        let action = Action(
            account: "decentiumorg",
            name: "post",
            authorization: [
                PermissionLevel("almstdigital", "active"),
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

        let transaction = Transaction(header, actions: [action])

        AssertABICodable(transaction, ref.json, ref.bin)
        XCTAssertEqual(transaction.id, "0ef9aa310e6e7efb7b10192dc80e5b09826c4369be6b1ba54990b8a66302500e")

        // Test dynamic member lookup
        var signed = SignedTransaction(transaction)
        signed.expiration = 1_234_567_890
        XCTAssertEqual(signed.transaction.header.expiration, 1_234_567_890)
        XCTAssertEqual(signed.expiration, signed.transaction.header.expiration)
    }

    func testChecksum256() {
        XCTAssertEqual(
            Checksum256.hash("hello".data(using: .utf8)!),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    func testBlockId() {
        let id: BlockId = "0181700002e623f2bf291b86a10a5cec4caab4954d4231f31f050f4f86f26116"
        XCTAssertEqual(id.blockPrefix, 2_249_927_103)
        XCTAssertEqual(id.blockNum, 25_260_032)
    }

    func testTimePoint() {
        let timeSec = TimePointSec(10)
        XCTAssertEqual(timeSec, "1970-01-01T00:00:10")
        XCTAssertGreaterThan(timeSec, 0)
        var time = TimePoint(timeSec)
        XCTAssertEqual(time.rawValue, 10_000_000)
        time.addTimeInterval(0.123)
        XCTAssertEqual(time, "1970-01-01T00:00:10.123")
    }

    func testAuthority() {
        let key = "EOS8YttBP1djravhBMt1u4yWrafG6fyHNPyRKXWRMbrqrHBHtEYHt" as PublicKey
        var auth = Authority(key)
        XCTAssertTrue(auth.hasPermission(for: key))
        auth.threshold += 1
        XCTAssertFalse(auth.hasPermission(for: key))
        XCTAssertTrue(auth.hasPermission(for: key, includePartial: true))
        XCTAssertFalse(auth.hasPermission(for: "EOS7uXbReU79nJNTSrTUVje8u5BDzxsQW9kNCvgiW3pctT1GcboKj"))
        auth = Authority(key, delay: 60)
        XCTAssertTrue(auth.hasPermission(for: key))
    }

    func testPublicKey() {
        let key = PublicKey("PUB_K1_833UzE2PyXhvQMenoD2MESD8hVroRTHjBR58G94Hr6Uo3EQP1L")
        // test legacy prefixes
        let key1 = PublicKey("EOS833UzE2PyXhvQMenoD2MESD8hVroRTHjBR58G94Hr6Uo7aSPb2")
        let key2 = PublicKey("FIO833UzE2PyXhvQMenoD2MESD8hVroRTHjBR58G94Hr6Uo7aSPb2")
        let key3 = PublicKey("DUMBPREFIX833UzE2PyXhvQMenoD2MESD8hVroRTHjBR58G94Hr6Uo7aSPb2")
        XCTAssertEqual(key, key1)
        XCTAssertEqual(key, key2)
        XCTAssertEqual(key, key3)
        XCTAssertEqual(key2.legacyFormattedString("XXX"), "XXX833UzE2PyXhvQMenoD2MESD8hVroRTHjBR58G94Hr6Uo7aSPb2")
    }

    func testSymbolCode() {
        let code = try! Asset.Symbol.Code(stringValue: "PI")
        XCTAssertEqual(code.rawValue, 18768)
        XCTAssertEqual(code.stringValue, "PI")
        AssertABICodable(
            [code],
            """
            ["PI"]
            """,
            "015049000000000000"
        )
    }

    func testExtendedAsset() {
        AssertABICodable(
            ExtendedAsset(quantity: "1.234 X", contract: "double"),
            """
            {
              "contract" : "double",
              "quantity" : "1.234 X"
            }
            """,
            "d204000000000000035800000000000000000000a878344d"
        )
    }
}
