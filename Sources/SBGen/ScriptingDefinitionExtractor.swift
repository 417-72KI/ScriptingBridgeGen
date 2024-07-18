import Foundation

enum ScriptingDefinitionExtractor {
    static func run(applicationURL: URL, outputDir: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/sdef")
        process.arguments = [applicationURL.path()]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = try stderr.fileHandleForReading.readToEnd()
                .flatMap { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            throw SBGeneratorError.sdefFailed(message ?? "")
        }
        let sdef = try stdout.fileHandleForReading.readToEnd()
        let sdefFileName = applicationURL.deletingPathExtension().lastPathComponent
            .appending(".sdef")
        let outputFileURL = outputDir.appending(path: sdefFileName)
        try sdef?.write(to: outputFileURL)
        return outputFileURL
    }
}
