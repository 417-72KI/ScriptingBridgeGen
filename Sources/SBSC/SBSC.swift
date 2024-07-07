import Foundation
import SBSCCore
import ArgumentParser

@main
struct SBSC: AsyncParsableCommand {
    @Argument(help: "An XML file created by `sdef` command.")
    var filePath: String
}

extension SBSC {
    func run() async throws {
        let core = SBSCCore()
        try await core.execute(filePath)
    }
}
