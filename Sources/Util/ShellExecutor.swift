import Foundation

public enum ShellExecutor {}

public extension ShellExecutor {
    @discardableResult
    static func execute(
        path: String,
        arguments: [String]? = nil,
        workingDirectory: URL? = nil
    ) throws -> Data? {
        let process = Process()
        process.currentDirectoryURL = workingDirectory
        process.executableURL = URL(filePath: path)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = try stderr.fileHandleForReading.readToEnd()
                .flatMap { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            throw Error(output: output ?? "(unexpected output in stderr)")
        }
        return try stdout.fileHandleForReading.readToEnd()
    }
}

// MARK: - Error
public extension ShellExecutor {
    struct Error: Swift.Error {
        public let output: String
    }
}
