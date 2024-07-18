import Foundation

enum ScriptingDefinitionProcessor {
    static func run(sdefFileURL: URL) throws -> URL {
        let basename = sdefFileURL.deletingPathExtension()
            .lastPathComponent
        let workingDirectory = sdefFileURL.deletingLastPathComponent()
        let process = Process()
        process.currentDirectoryURL = workingDirectory
        process.executableURL = URL(filePath: "/usr/bin/sdp")
        process.arguments = ["-fh", "--basename", basename, sdefFileURL.path()]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = try stderr.fileHandleForReading.readToEnd()
                .flatMap { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            throw SBGeneratorError.sdpFailed(sdefFile: sdefFileURL,cause: message ?? "")
        }

        let outputFileURL = workingDirectory.appending(path: basename.appending(".h"))
        return outputFileURL
    }
}
