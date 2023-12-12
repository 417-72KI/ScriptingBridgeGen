import Foundation

public final class SBSCCore {
    public init() {}
}

public extension SBSCCore {
    @discardableResult
    func execute(_ filePath: String) async throws -> URL {
        URL(filePath: filePath)
    }
}
