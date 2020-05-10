// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "EOSIO",
    products: [
        .library(name: "EOSIO", targets: ["EOSIO"]),
    ],
    dependencies: [
        .package(url: "https://github.com/greymass/secp256k1.git", .branch("master")),
        .package(url: "https://github.com/jnordberg/swift-query-string-coder.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "EOSIO",
            dependencies: ["secp256k1", "CCrypto", "QueryStringCoder"]
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
