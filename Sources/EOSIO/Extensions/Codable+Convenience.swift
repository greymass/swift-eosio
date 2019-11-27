import Foundation

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key) throws -> T {
        return try self.decode(T.self, forKey: key)
    }
}

internal struct StringCodingKey: CodingKey, ExpressibleByStringLiteral {
    var stringValue: String
    var intValue: Int? { return nil }
    init(_ name: String) {
        self.stringValue = name
    }

    init(stringLiteral value: String) {
        self.stringValue = value
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue _: Int) {
        return nil
    }
}
