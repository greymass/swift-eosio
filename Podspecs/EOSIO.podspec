Pod::Spec.new do |s|
  s.name = "EOSIO"
  s.version = "0.3.0"
  s.summary = "Library for swiftly working with EOSIO blockchains on MacOS, Linux and iOS"
  s.homepage = "https://github.com/greymass/swift-eosio"
  s.license = { :type => "BSD-3-CLAUSE", :file => "LICENSE" }
  s.author = { "Johan Nordberg" => "code@johan-nordberg.com" }
  s.source = { :git => "https://github.com/greymass/swift-eosio.git", :tag => "0.3.0" }
  s.ios.deployment_target = "12.0"
  s.module_name = "EOSIO"
  s.swift_version = "5.2"
  s.dependency "EOSIO-CCrypto", "0.2.0"
  s.dependency "secp256k1-gm", "0.0.3"
  s.dependency "QueryStringCoder", "0.1.0"
  s.source_files = "Sources/EOSIO/**/*"
end
