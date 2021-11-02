// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swift-eosio",
    products: [
        .library(name: "EOSIO", targets: ["EOSIO"]),
    ],
    dependencies: [
        .package(name: "secp256k1gm", url: "https://github.com/greymass/secp256k1.git", .branch("master")),
        .package(name: "QueryStringCoder", url: "https://github.com/jnordberg/swift-query-string-coder.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "EOSIO",
            dependencies: ["secp256k1gm", "CCrypto", "QueryStringCoder"]
        ),
        .target(
            name: "CCrypto"
        ),
        .testTarget(
            name: "EOSIOTests",
            dependencies: ["EOSIO"]
        ),
    ]
)
