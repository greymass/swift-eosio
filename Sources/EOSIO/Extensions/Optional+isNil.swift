import Foundation

protocol Nullable {
    var isNil: Bool { get }
}

extension Optional: Nullable {
    var isNil: Bool {
        switch self {
        case .some(let value as Nullable): return value.isNil
        case .some(_): return false
        case .none: return true
        }
    }
}
