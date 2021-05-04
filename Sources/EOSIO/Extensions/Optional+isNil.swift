import Foundation

protocol Nullable {
    var isNil: Bool { get }
}

extension Optional: Nullable {
    var isNil: Bool {
        switch self {
        case let .some(value as Nullable): return value.isNil
        case .some: return false
        case .none: return true
        }
    }
}
