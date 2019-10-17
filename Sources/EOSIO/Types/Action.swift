//
//  Action.swift
//  EOSIO
//
//  Created by Johan Nordberg on 2019-10-15.
//

import Foundation

/// Type representing an EOSIO Action.
public struct Action: ABICodable, Equatable, Hashable {
    /// The account (a.k.a. contract) to run action on.
    let account: Name
    /// The name of the action.
    let name: Name
    /// The signer(s) of the action.
    let authorization: [PermissionLevel]
    /// The ABI-encoded action data.
    let data: Data
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

// TODO: move to own file
public struct PermissionLevel: ABICodable, Equatable, Hashable {
    let actor: Name
    let permission: Name
}
