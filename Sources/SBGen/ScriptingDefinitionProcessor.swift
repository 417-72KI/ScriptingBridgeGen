import Foundation
import Util

enum ScriptingDefinitionProcessor {
    static func run(sdefFileURL: URL) throws -> URL {
        let basename = sdefFileURL.deletingPathExtension()
            .lastPathComponent
        let workingDirectory = sdefFileURL.deletingLastPathComponent()
        do {
            try ShellExecutor.execute(
                path: "/usr/bin/sdp",
                arguments: ["-fh", "--basename", basename, sdefFileURL.path()],
                workingDirectory: workingDirectory
            )
        } catch let error as ShellExecutor.Error {
            throw SBGeneratorError.sdpFailed(sdefFile: sdefFileURL,
                                             cause: error.output)
        }

        let outputFileURL = workingDirectory.appending(path: basename.appending(".h"))
        return outputFileURL
    }
}
