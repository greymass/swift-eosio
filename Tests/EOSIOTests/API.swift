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
    mode: .record // env["MOCK_RECORD"] != nil ? .record : .replay
)
let nodeAddress = URL(string: "https://jungle.greymass.com")! // only used when recording
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
        XCTAssertEqual(res?.rows.first?.maxSupply, "100000000000.0000 EOS")
        XCTAssertEqual(res?.rows.first?.issuer, "eosio")
    }

    func testGetInfo() {
        let req = API.V1.Chain.GetInfo()
        let res = try? client.sendSync(req).get()
        XCTAssertEqual(res?.chainId, "e70aaab8997e1dfce58fbfac80cbbb8fecec7b99cf982a9444273cbc64c41473")
    }

    func testGetRawAbi() {
        let req = API.V1.Chain.GetRawAbi("eosio.token")
        let res = try? client.sendSync(req).get()
        let actions = res?.decodedAbi?.actions.map { $0.name }
        XCTAssertEqual(actions, ["close", "create", "issue", "open", "retire", "transfer"])
    }

    func testGetKeyAccounts() {
        let req = API.V1.History.GetKeyAccounts("EOS8aL4dzqLudQQbcNZYVeyuHfjE7K76BMNGRRT8hwyURPPapDt4h")
        let res = try? client.sendSync(req).get()
        XCTAssertEqual(res?.accountNames, ["iamthewalrus"])
    }

    func testPushTransaction() {
        let key = PrivateKey("5J2DVkkD59X146qkrBTjGykUA634pFkdU7gSA7Y3bcDbthCt9md")

        let transfer = Transfer(
            from: "iamthewalrus",
            to: "teamgreymass",
            quantity: "0.4200 EOS",
            memo: "So long, and thanks for all the fish"
        )

        let action = try! Action(
            account: "eosio.token",
            name: "transfer",
            authorization: [PermissionLevel("iamthewalrus", "active")],
            value: transfer
        )

        let info = try! client.sendSync(API.V1.Chain.GetInfo()).get()

        let expiration = TimePointSec(info.headBlockTime.date.addingTimeInterval(60))
        let header = TransactionHeader(expiration: expiration,
                                       refBlockId: info.lastIrreversibleBlockId)

        let transaction = Transaction(header, actions: [action])
        let digest = try! transaction.digest(using: "e70aaab8997e1dfce58fbfac80cbbb8fecec7b99cf982a9444273cbc64c41473")
        let signature = try! key.sign(digest)

        let signedTransaction = SignedTransaction(transaction, signatures: [signature])

        let req = API.V1.Chain.PushTransaction(signedTransaction)
        let res = try! client.sendSync(req).get()

        XCTAssertEqual(res.transactionId, transaction.id)
    }
}
