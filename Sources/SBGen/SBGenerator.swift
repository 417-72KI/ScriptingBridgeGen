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
        
        let outputFiles = try await withThrowingTaskGroup(of: URL.self) { group in
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
        print(outputFiles)
        print(outputDirectory ?? FileManager.default.currentDirectoryPath)
    }
}
