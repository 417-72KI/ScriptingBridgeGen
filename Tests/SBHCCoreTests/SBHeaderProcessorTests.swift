import XCTest
@testable import SBHCCore

final class SBHeaderProcessorTests: XCTestCase {
    private var processor: SBHeaderProcessor!

    func testEmitSwift() throws {
        let headerFileURL = try XCTUnwrap(Bundle.module.url(forResource: "Xcode", withExtension: "h", subdirectory: "Resources"))
        let swiftFileURL = try XCTUnwrap(Bundle.module.url(forResource: "Xcode", withExtension: "swift", subdirectory: "Resources"))
        processor = try .init(headerFileUrl: headerFileURL)
        try processor.emitSwift()

        let expected = String(decoding: try Data(contentsOf: swiftFileURL), as: UTF8.self)
        XCTAssertEqual(processor.output, expected)
    }
}
