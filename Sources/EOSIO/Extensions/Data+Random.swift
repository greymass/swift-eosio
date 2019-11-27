/// Random byte generation extension for the Data type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public extension Data {
    static func random<T: RandomNumberGenerator>(_ count: Int, using generator: inout T) -> Data {
        var data = Data(capacity: count)
        for _ in 0..<count {
            data.append(generator.next())
        }
        return data
    }

    static func random(_ count: Int) -> Data {
        var rng = SystemRandomNumberGenerator()
        return Self.random(count, using: &rng)
    }
}
