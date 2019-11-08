@testable import EOSIO
import XCTest

struct RewardStat: ABICodable {
    let count: UInt32
    let amount: UInt64
}

struct BlogStats: ABICodable {
    let totalPosts: UInt32
    let endorsementsReceived: RewardStat
    let endorsementsSent: RewardStat
    let incomingLinkbacks: RewardStat
    let outgoingLinkbacks: RewardStat
}

struct BlogRow: ABICodable {
    let author: Name
    let flags: UInt8
    let pinned: [Name]
    let stats: BlogStats
}

let env = ProcessInfo.processInfo.environment
let mockSession = MockSession(
    resourcePath.appendingPathComponent("API", isDirectory: true),
    mode: env["MOCK_RECORD"] != nil ? .record : .replay
)
let nodeAddress = URL(string: "https://eos.greymass.com")! // only used when recording
let client = Client(address: nodeAddress, session: mockSession)

final class APITests: XCTestCase {
    func testGetTableRows() {
        struct CurrencyStats: ABICodable {
            let supply: Asset
            let maxSupply: Asset
            let issuer: Name
        }
        let req = API.V1.Chain.GetTableRows<CurrencyStats>(
            code: "eosio.token",
            table: "stat",
            scope: Asset.Symbol("4,EOS").symbolCode
        )
        let res = try? client.sendSync(req).get()
        XCTAssertGreaterThan(res?.rows.first?.supply ?? "0.0000 EOS", "1000000000.0000 EOS")
        XCTAssertEqual(res?.rows.first?.maxSupply, "10000000000.0000 EOS")
        XCTAssertEqual(res?.rows.first?.issuer, "eosio")
    }

    func testGetInfo() {
        let req = API.V1.Chain.GetInfo()
        let res = try? client.sendSync(req).get()
        XCTAssertNotNil(res?.chainId, "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906")
    }

    func testGetRawAbi() {
        let req = API.V1.Chain.GetRawAbi("eosio.token")
        let res = try? client.sendSync(req).get()
        let actions = res?.decodedAbi?.actions.map { $0.name }
        XCTAssertEqual(actions, ["close", "create", "issue", "open", "retire", "transfer"])
    }
    
    func testGetKeyAccounts() {
        let req = API.V1.History.GetKeyAccounts("EOS5sxJmaM1xuiuvTGH2GyUW1ZTpC2NZJjX7EtEDqJSPdF6Wos55V")
        let res = try? client.sendSync(req).get()
        XCTAssertEqual(res?.accountNames, ["catpianodogs"])
    }
    
}
