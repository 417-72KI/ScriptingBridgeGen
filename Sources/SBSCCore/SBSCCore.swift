import Foundation

public final class SBSCCore {
    public init() {}
}

public extension SBSCCore {
    @discardableResult
    func execute(_ filePath: String) async throws -> URL {
        let fileUrl = URL(filePath: filePath)
        let processor = SBScriptingProcessor(sdefFileUrl: fileUrl)
        try processor.process()
        let swiftFileURL = fileUrl
            .deletingLastPathComponent()
            .appending(path: processor.outputFileName)
        try processor.output.write(to: swiftFileURL, atomically: false, encoding: .utf8)
        return swiftFileURL
    }
}
