import Foundation
import SBHCCore
import SBSCCore
import ArgumentParser

@main
struct SBGenerator: AsyncParsableCommand {
    @Argument(help: "An application to create `ScriptingBridge` files")
    var applicationPath: String

    @Option(name: .shortAndLong, help: "A directory to save output files.")
    var outputDirectory: String?

    @Flag(name: [.long, .customShort("S")], help: "Not output `.sdef` file.")
    var discardSdefFile = false

    @Flag(name: [.long, .customShort("O")], help: "Not output `.h` file.")
    var discardObjcHeaderFile = false
}

extension SBGenerator {
    func run() async throws {
        guard FileManager.default.fileExists(atPath: applicationPath) else {
            print("`\(applicationPath)` not exist.")
            return
        }
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let sdefFile = try ScriptingDefinitionExtractor.run(
            applicationURL: URL(filePath: applicationPath),
            outputDir: tmpDir
        )
        print("\(sdefFile) created.")
        let objcHeaderFile = try ScriptingDefinitionProcessor.run(sdefFileURL: sdefFile)
        print("\(objcHeaderFile) created.")
        
        var outputFiles = try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask {
                try await SBHCCore().execute(objcHeaderFile.path())
            }
            group.addTask {
                try await SBSCCore().execute(sdefFile.path())
            }
            var files: [URL] = []
            for try await outputFile in group {
                files.append(outputFile)
            }
            return files
        }
        if !discardSdefFile {
            outputFiles.append(sdefFile)
        }
        if !discardObjcHeaderFile {
            outputFiles.append(objcHeaderFile)
        }
        let fm = FileManager.default
        let outputDirectory = URL(filePath: outputDirectory ?? fm.currentDirectoryPath)
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: outputDirectory.path(), isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw SBGeneratorError.notDirectory(outputDirectory)
            }
        } else {
            try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        try outputFiles.forEach {
            let fileName = $0.lastPathComponent
            let outputFile = outputDirectory.appending(path: fileName)
            if fm.fileExists(atPath: outputFile.path()) {
                try fm.removeItem(at: outputFile)
            }
            try fm.moveItem(at: $0, to: outputFile)
        }
    }
}
