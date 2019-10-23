// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "EOSIO",
    products: [
        .library(name: "EOSIO", targets: ["EOSIO"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0"),
        .package(url: "https://github.com/greymass/secp256k1.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "EOSIO",
            dependencies: ["secp256k1"]
        ),
        .testTarget(
            name: "EOSIOTests",
            dependencies: ["EOSIO"]
        ),
    ]
)
