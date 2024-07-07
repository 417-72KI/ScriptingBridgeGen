import Foundation

public final class SBSCCore {
    public init() {}
}

public extension SBSCCore {
    func execute(_ filePath: String) async throws {
        print(URL(filePath: filePath))
    }
}
