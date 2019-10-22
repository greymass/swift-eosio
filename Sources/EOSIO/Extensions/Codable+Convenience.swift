import Foundation

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key) throws -> T {
        return try self.decode(T.self, forKey: key)
    }
}
