EOSIO for Swift
===============

Library for swiftly working with EOSIO blockchains on MacOS, Linux and iOS.

Features:
 - Strongly typed EOSIO ABI encoding and decoding using Swift's `Codable` protocol
 - Untyped EOSIO ABI coding using EOSIO ABI definitions (JSON & binary)
 - Extendable HTTP API Client
 - All EOSIO primitive types implemented in Swift with ergonomic interfaces (Asset, Name, PublicKey etc.)
 - Fast and battle-hardened ECDSA via libsecp256k1
 - Signing requests (ESR/EEP-7)

Installation
------------

In your `Package.swift`'s dependencies:

```swift
.package(url: "https://github.com/greymass/swift-eosio.git", .branch("master")),
```

Usage example
-------------

```swift
import EOSIO
import Foundation

struct MyAction: ABICodable, Equatable {
    let message: String // most native types conform to ABICodable
    let from: Name // all eosio builtins have their own type
    let tip: Asset? // optionals just work
    let extra: [MyAction] // so does complex types
}

let action = MyAction(
    message: "hi mom",
    from: "2goodgenes", // most eosio types can be expressed by literals
    tip: "3.00 BUCKZ",
    extra: [
        MyAction(message: "yup", from: "me", tip: nil, extra: [])
    ]
)

// types have same memory layout as their c++ eosio counterparts
print(action.from.rawValue) // 1380710289163812864
print(action.tip!.symbol) // 2,BUCKZ
print(action.tip!.units) // 300

// types conform to standrad protocols where applicable
print(action.from == "2goodgenes") // true
print(action.tip! * 10) // "30.00 BUCKZ"
print(action.tip! + "0.99 BUCKZ") // "3.99 BUCKZ"
print(Name(String(action.from).replacingOccurrences(of: "good", with: "BÅÅD"))) // 2....genes

// encode action to json
let jsonEncoder = JSONEncoder()
jsonEncoder.outputFormatting = .prettyPrinted
let jsonData = try! jsonEncoder.encode(action)
print(String(bytes: jsonData, encoding: .utf8)!)
/*
 {
   "extra" : [
     {
       "message" : "yup",
       "extra" : [

       ],
       "from" : "me"
     }
   ],
   "message" : "hi mom",
   "tip" : "3.00 BUCKZ",
   "from" : "2goodgenes"
 }
 */

// encode action to binary
let abiEncoder = ABIEncoder()
let binData: Data = try! abiEncoder.encode(action)
print(binData.hexEncodedString())
// 066869206d6f6d00005653b1442913012c01000000000000024255434b5a0000010379757000000000000080920000

// decoding actions
let abiDecoder = ABIDecoder() // same for JSONDecoder
let decodedAction = try! abiDecoder.decode(MyAction.self, from: binData)
print(decodedAction == action) // true

// untypepd coding using ABI definitions
let myAbiJson = """
{
    "version": "eosio::abi/1.1",
    "structs": [
        {
            "name": "my_action",
            "base": "",
            "fields": [
                {"name": "message", "type": "string"},
                {"name": "from", "type": "name"},
                {"name": "tip", "type": "asset?"},
                {"name": "extra", "type": "my_action[]"}
            ]
        }
    ]
}
"""
let jsonDecoder = JSONDecoder()
// ABI defs are also ABICodable
let abi = try! jsonDecoder.decode(ABI.self, from: myAbiJson.data(using: .utf8)!)
print(abi.resolveStruct("my_action")!.map({ $0.name })) // ["message", "from", "tip", "extra"]

// untyped decoding
let anyFromBin = (try! abiDecoder.decode("my_action", from: binData, using: abi))
let anyFromJson = (try! jsonDecoder.decode("my_action", from: jsonData, using: abi))

let objFromBin = anyFromBin as! [String: Any]
let objFromJson = anyFromJson as! [String: Any]

print(objFromJson["from"] as! Name) // 2goodgenes
print(objFromJson["from"] as? Name == objFromBin["from"] as? Name) // true
print(objFromJson["from"] as? Name == action.from) // true
```
