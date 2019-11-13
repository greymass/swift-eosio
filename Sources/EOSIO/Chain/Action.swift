/// EOSIO action type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing an EOSIO Action.
public struct Action: ABICodable, Equatable, Hashable {
    /// The account (a.k.a. contract) to run action on.
    public var account: Name
    /// The name of the action.
    public var name: Name
    /// The permissions authorizing the action.
    public var authorization: [PermissionLevel]
    /// The ABI-encoded action data.
    public var data: Data

    public init(account: Name, name: Name, authorization: [PermissionLevel] = [], data: Data = Data()) {
        self.account = account
        self.name = name
        self.authorization = authorization
        self.data = data
    }

    public init<T: ABIEncodable>(account: Name, name: Name, authorization: [PermissionLevel] = [], value: T) throws {
        self.account = account
        self.name = name
        self.authorization = authorization
        self.data = try ABIEncoder().encode(value)
    }
}

extension Action {
    /// Decode action to compatible type.
    func data<T: ABIDecodable>(as type: T.Type) throws -> T {
        return try ABIDecoder.decode(type, data: self.data)
    }

    /// Decode action data using ABI defenition.
    func data(as type: String, using abi: ABI) throws -> [String: Any] {
        let decoder = ABIDecoder()
        let result = try decoder.decode(type, from: self.data, using: abi)
        guard let rv = result as? [String: Any] else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Root ABI type not a struct"
            ))
        }
        return rv
    }
}
