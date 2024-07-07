import Foundation

public final class SBHCCore {
    public init() {}
}

public extension SBHCCore {
    func execute(_ filePath: String) async throws {
        print(URL(filePath: filePath))
    }
}
