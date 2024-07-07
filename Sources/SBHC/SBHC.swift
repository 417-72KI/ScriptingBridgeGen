import Foundation
import ArgumentParser
import SBHCCore

@main
struct SBHC: AsyncParsableCommand {
    @Argument(help: "An Objective-C header file emitted by `sdef`.")
    var filePath: String
}

extension SBHC {
    func run() async throws {
        let core = SBHCCore()
        try await core.execute(filePath)
    }
}
