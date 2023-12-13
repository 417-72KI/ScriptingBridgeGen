import Foundation

public final class SBHCCore {
    public init() {}
}

public extension SBHCCore {
    @discardableResult
    func execute(_ filePath: String) async throws -> URL {
        let processor = try SBHeaderProcessor(headerFileUrl: URL(filePath: filePath))
        try processor.emitSwift()
        let swiftFileURL = URL(filePath: filePath)
            .deletingPathExtension()
            .appendingPathExtension("swift")
        try processor.output.write(to: swiftFileURL, atomically: false, encoding: .utf8)
        return swiftFileURL
    }
}
