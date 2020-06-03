Pod::Spec.new do |s|
  s.name = "EOSIO-CCrypto"
  s.version = "0.2.0"
  s.summary = "Helper library for EOSIO"
  s.homepage = "https://github.com/greymass/swift-eosio"
  s.license = { :type => "BSD-3-CLAUSE", :file => "LICENSE" }
  s.author = { "Johan Nordberg" => "code@johan-nordberg.com" }
  s.source = { :git => "https://github.com/greymass/swift-eosio.git", :tag => "0.2.0" }
  s.ios.deployment_target = "12.0"
  s.module_name = "CCrypto"
  s.swift_version = "5.2"
  s.source_files = "Sources/CCrypto/**/*"
end
