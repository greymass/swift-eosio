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
var mockSession = MockSession(
    resourcePath.appendingPathComponent("API", isDirectory: true),
    mode: env["MOCK_RECORD"] != nil ? .record : .replay
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

        let expiration = info.headBlockTime.addingTimeInterval(60)
        let header = TransactionHeader(expiration: TimePointSec(expiration),
                                       refBlockId: info.lastIrreversibleBlockId)

        let transaction = Transaction(header, actions: [action])
        let signature = try! key.sign(transaction, using: info.chainId)

        let signedTransaction = SignedTransaction(transaction, signatures: [signature])

        let req = API.V1.Chain.PushTransaction(signedTransaction)
        let res = try! client.sendSync(req).get()

        XCTAssertEqual(res.transactionId, transaction.id)
        XCTAssertEqual(res.processed.blockNum, 60_423_261)
    }

    func testGetAccount() {
        let req = API.V1.Chain.GetAccount("eosio")
        let res = try! client.sendSync(req).get()
        XCTAssertEqual(res.accountName, "eosio")
        XCTAssertEqual(res.cpuLimit.used, -1)
        XCTAssertEqual(res.voterInfo?.proxy, 0)
        XCTAssertEqual(res.voterInfo?.producers.count, 0)
    }

    func testGetAccountsByAuthorizersUsingKey() {
        let pubkey = PublicKey("EOS8X5SC2m6Q1iBpvP91mLBNpEu9LYuynC44os35n5RKaAVt9n7Ji")
        let req = API.V1.Chain.GetAccountsByAuthorizers(keys: [pubkey])
        let res = try! client.sendSync(req).get()
        XCTAssertEqual(res.accounts.first?.accountName, "jestasmobile")
        XCTAssertEqual(res.accounts.first?.permissionName, "active")
        XCTAssertEqual(res.accounts.first?.authorizer, .publicKey(pubkey))
        XCTAssertEqual(res.accounts.first?.threshold, 1)
        XCTAssertEqual(res.accounts.first?.weight, 1)
    }

    func testGetAccountsByAuthorizersUsingAccount() {
        let req = API.V1.Chain.GetAccountsByAuthorizers(accounts: ["eosio"])
        let res = try! client.sendSync(req).get()
        XCTAssertEqual(res.accounts.first?.accountName, "eosio.assert")
        XCTAssertEqual(res.accounts.first?.permissionName, "active")
        XCTAssertEqual(res.accounts.first?.authorizer, .permissionLevel("eosio@active"))
        XCTAssertEqual(res.accounts.first?.threshold, 1)
        XCTAssertEqual(res.accounts.first?.weight, 1)
    }

    func testErrorMessage() {
        let key = PrivateKey("5J2DVkkD59X146qkrBTjGykUA634pFkdU7gSA7Y3bcDbthCt9md")

        let transfer = Transfer(
            from: "eosio",
            to: "teamgreymass",
            quantity: "10000000.0000 EOS",
            memo: "Thanks!"
        )

        let action = try! Action(
            account: "eosio.token",
            name: "transfer",
            authorization: [PermissionLevel("iamthewalrus", "active")],
            value: transfer
        )

        let info = try! client.sendSync(API.V1.Chain.GetInfo()).get()

        let expiration = info.headBlockTime.addingTimeInterval(60)
        let header = TransactionHeader(expiration: TimePointSec(expiration),
                                       refBlockId: info.lastIrreversibleBlockId)

        let transaction = Transaction(header, actions: [action])
        let signature = try! key.sign(transaction, using: info.chainId)

        let signedTransaction = SignedTransaction(transaction, signatures: [signature])

        let req = API.V1.Chain.PushTransaction(signedTransaction)
        let res = client.sendSync(req)
        switch res {
        case .success:
            XCTFail()
        case let .failure(error):
            XCTAssertEqual(error.localizedDescription, "Missing required authority: missing authority of eosio")
        }
    }

    func testFcIntApi() {
        let client = Client(
            address: URL(string: "https://wax.greymass.com")!,
            session: mockSession
        )
        let req = API.V1.Chain.GetAccount("teamgreymass")
        let res = try! client.sendSync(req).get()
        XCTAssertEqual(res.netWeight, 432_714_455_333)
        XCTAssert(res.netWeight > 0xFFFFFF)
    }

    func testHyperionGetCreatedAccounts() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        var req = API.V2.Hyperion.GetCreatedAccounts("eosio")
        req.limit = 1

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.accounts.count, 1)
        XCTAssertEqual(res.accounts.first?.name, "fees.newdex")
        XCTAssertEqual(res.accounts.first?.timestamp, "2020-04-22T17:03:33.500")
    }

    func testHyperionGetKeyAccounts() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        let req = API.V2.Hyperion.GetKeyAccounts("EOS5ajfDQ3KBv25BBbBBVtBCmXngaz3XWdtAxjQdkU4NHADjKbJTX")
        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.accountNames.count, 1)
        XCTAssertEqual(res.accountNames.first?.stringValue, "protonwallet")
    }

    func testHyperionGetTokens() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        var req = API.V2.Hyperion.GetTokens(Name("protonwallet"))
        req.limit = 1

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.tokens.count, 1)
        XCTAssertEqual(res.tokens.first?.symbol, "XPR")
        XCTAssertEqual(res.tokens.first?.precision, 4)
        XCTAssertEqual(res.tokens.first?.amount, 0.113)
        XCTAssertEqual(res.tokens.first?.contract, Name("eosio.token"))
    }

    func testHyperionGetTransferActions() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        struct TransferActionData: ABIDecodable {
            let from: Name
            let to: Name
            let amount: Double
            let symbol: String
            let memo: String
            let quantity: Asset
        }

        var req = API.V2.Hyperion.GetActions<TransferActionData>(Name("protonwallet"))
        req.filter = "eosio.token:transfer"
        req.transferSymbol = "XPR"
        req.limit = 1

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.actions.count, 1)
        XCTAssertEqual(res.actions.first?.timestamp, TimePoint(rawValue: 1_587_575_238_000_000))
        XCTAssertEqual(res.actions.first?.blockNum, BlockNum(868))
        XCTAssertEqual(res.actions.first?.trxId, TransactionId(stringLiteral: "9a36577425f7a91ccde75c68a541922877ca2ce206f7c8094247efaf953044a6"))
        XCTAssertEqual(res.actions.first?.act.account, Name("eosio.token"))
        XCTAssertEqual(res.actions.first?.act.name, Name("transfer"))
        XCTAssertEqual(res.actions.first?.act.authorization.first, PermissionLevel(Name("adrop.proton"), Name("active")))
        XCTAssertEqual(res.actions.first?.act.data.amount, 0.113)
        XCTAssertEqual(res.actions.first?.act.data.symbol, "XPR")
        XCTAssertEqual(res.actions.first?.act.data.quantity, Asset(stringLiteral: "0.1130 XPR"))
        XCTAssertEqual(res.actions.first?.act.data.memo, "1587575237728391")
        XCTAssertEqual(res.actions.first?.act.data.to, Name("protonwallet"))
        XCTAssertEqual(res.actions.first?.act.data.from, Name("adrop.proton"))
        XCTAssertEqual(res.actions.first?.notified.first, Name("eosio.token"))
        XCTAssertEqual(res.actions.first?.cpuUsageUs, 301)
        XCTAssertEqual(res.actions.first?.netUsageWords, 18)
        XCTAssertEqual(res.actions.first?.globalSequence, 112_766)
        XCTAssertEqual(res.actions.first?.producer, Name("protonabp"))
        XCTAssertEqual(res.actions.first?.actionOrdinal, 1)
        XCTAssertEqual(res.actions.first?.creatorActionOrdinal, 0)
    }

    func testHyperionGetUpdateAuthActions() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        struct UpdateAuthAuthority: Decodable {
            let threshold: UInt8
            let accounts: [PermissionLevelWeight]
        }

        struct UpdateAuthActionData: ABIDecodable {
            let permission: Name
            let parent: Name
            let auth: UpdateAuthAuthority
        }

        var req = API.V2.Hyperion.GetActions<UpdateAuthActionData>(Name("protonwallet"))
        req.filter = "eosio:updateauth"
        req.limit = 1

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.actions.count, 1)
        XCTAssertEqual(res.actions.first?.timestamp, TimePoint(rawValue: 1_587_575_409_000_000))
        XCTAssertEqual(res.actions.first?.blockNum, BlockNum(1210))
        XCTAssertEqual(res.actions.first?.trxId, TransactionId(stringLiteral: "a99bc1809fe3a43e838344620498b61d15de87ac93addf71408dea4a6be9b95d"))
        XCTAssertEqual(res.actions.first?.act.account, Name("eosio"))
        XCTAssertEqual(res.actions.first?.act.name, Name("updateauth"))
        XCTAssertEqual(res.actions.first?.act.authorization.first, PermissionLevel(Name("protonwallet"), Name("owner")))
        XCTAssertEqual(res.actions.first?.notified.first, Name("eosio"))
        XCTAssertEqual(res.actions.first?.cpuUsageUs, 191)
        XCTAssertEqual(res.actions.first?.netUsageWords, 18)
        XCTAssertEqual(res.actions.first?.globalSequence, 157_588)
        XCTAssertEqual(res.actions.first?.producer, Name("protonabp"))
        XCTAssertEqual(res.actions.first?.actionOrdinal, 1)
        XCTAssertEqual(res.actions.first?.creatorActionOrdinal, 0)
        XCTAssertEqual(res.actions.first?.accountRamDeltas?.first?.account, Name("protonwallet"))
        XCTAssertEqual(res.actions.first?.accountRamDeltas?.first?.delta, -18)
        XCTAssertEqual(res.actions.first?.act.data.permission, Name("owner"))
        XCTAssertEqual(res.actions.first?.act.data.parent, Name(""))
        XCTAssertEqual(res.actions.first?.act.data.auth.threshold, 1)
        XCTAssertEqual(res.actions.first?.act.data.auth.accounts.count, 1)
        XCTAssertEqual(res.actions.first?.act.data.auth.accounts.first?.permission, PermissionLevel(Name("admin.proton"), Name("partners")))
    }

    func testHyperionGetCreator() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        let req = API.V2.Hyperion.GetCreator(Name("protonwallet"))

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.account, Name("protonwallet"))
        XCTAssertEqual(res.creator, Name("wlcm.proton"))
        XCTAssertEqual(res.timestamp, TimePoint(rawValue: 1_587_574_815_000_000))
        XCTAssertEqual(res.blockNum, BlockNum(22))
        XCTAssertEqual(res.trxId, TransactionId(stringLiteral: "533e3ff46a99369e83cae68b2d09dc899b2d68bb0b8fa0affb40e02ee135fb29"))
    }

    func testHyperionGetLinks() throws {
        let hyperClient = Client(
            address: URL(string: "https://proton.cryptolions.io")!,
            session: mockSession
        )

        let req = API.V2.Hyperion.GetLinks(Name("teamgreymass"), code: Name("cfund.proton"),
                                           action: Name("claimreward"), permission: Name("claim"))

        let res = try hyperClient.sendSync(req).get()
        XCTAssertEqual(res.links.count, 1)
        XCTAssertEqual(res.links.first?.blockNum, BlockNum(350_559))
        XCTAssertEqual(res.links.first?.timestamp, TimePoint(rawValue: 1_587_750_083_500_000))
        XCTAssertEqual(res.links.first?.account, Name("teamgreymass"))
        XCTAssertEqual(res.links.first?.permission, Name("claim"))
        XCTAssertEqual(res.links.first?.code, Name("cfund.proton"))
        XCTAssertEqual(res.links.first?.action, Name("claimreward"))
    }
}
