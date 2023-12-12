import Foundation

public final class SBHCCore {
    public init() {}
}

public extension SBHCCore {
    @discardableResult
    func execute(_ filePath: String) async throws -> URL {
        URL(filePath: filePath)
    }
}
