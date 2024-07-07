import XCTest
@testable import SBSCCore

final class SBScriptingProcessorTests: XCTestCase {
    private var processor: SBScriptingProcessor!

    func testProcess() throws {
        let sdefFileURL = try XCTUnwrap(Bundle.module.url(forResource: "Xcode", withExtension: "sdef", subdirectory: "Resources"))
        let swiftFileURL = try XCTUnwrap(Bundle.module.url(forResource: "XcodeScripting", withExtension: "swift", subdirectory: "Resources"))
        processor = .init(sdefFileUrl: sdefFileURL)
        try processor.process()

        let expected = String(decoding: try Data(contentsOf: swiftFileURL), as: UTF8.self)
        XCTAssertEqual(processor.output, expected)
    }
}
