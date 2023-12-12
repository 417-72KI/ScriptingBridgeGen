import Foundation

enum ScriptingDefinitionExtractor {
    static func run(applicationURL: URL, outputDir: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/sdef")
        process.arguments = [applicationURL.path()]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        let sdef = try stdout.fileHandleForReading.readToEnd()
        let sdefFileName = applicationURL.deletingPathExtension().lastPathComponent
            .appending(".sdef")
        let outputFileURL = outputDir.appending(path: sdefFileName)
        try sdef?.write(to: outputFileURL)
        return outputFileURL
    }
}
