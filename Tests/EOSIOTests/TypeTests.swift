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
}
