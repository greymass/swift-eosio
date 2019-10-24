import Foundation

internal extension UnsafeRawBufferPointer {
    /// Returns a C compatible buffer pointer.
    /// - Attention:Unsafe to use unless count > 0
    var bufPtr: UnsafePointer<UInt8> {
        self.baseAddress!.assumingMemoryBound(to: UInt8.self)
    }
}

internal extension UnsafeMutableRawBufferPointer {
    /// Returns a C compatible mutable buffer pointer.
    /// - Attention:Unsafe to use unless count > 0
    var bufPtr: UnsafeMutablePointer<UInt8> {
        self.baseAddress!.assumingMemoryBound(to: UInt8.self)
    }
}
