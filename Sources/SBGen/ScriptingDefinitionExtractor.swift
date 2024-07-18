import Foundation
import Util

enum ScriptingDefinitionExtractor {
    static func run(applicationURL: URL, outputDir: URL) throws -> URL {
        do {
            let sdef = try ShellExecutor.execute(
                path: "/usr/bin/sdef",
                arguments: [applicationURL.path()]
            )
            let sdefFileName = applicationURL.deletingPathExtension().lastPathComponent
                .appending(".sdef")
            let outputFileURL = outputDir.appending(path: sdefFileName)
            try sdef?.write(to: outputFileURL)
            return outputFileURL
        } catch let error as ShellExecutor.Error {
            throw SBGeneratorError.sdefFailed(error.output)
        }
    }
}
