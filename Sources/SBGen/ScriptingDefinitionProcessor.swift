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
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        let outputFileURL = workingDirectory.appending(path: basename.appending(".h"))
        return outputFileURL
    }
}
