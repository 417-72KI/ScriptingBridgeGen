import Foundation

enum SBGeneratorError: LocalizedError {
    case notDirectory(URL)
    case sdefFailed(String)
    case sdpFailed(sdefFile: URL, cause: String)
}

extension SBGeneratorError {
    var errorDescription: String? {
        switch self {
        case let .notDirectory(url):
            "`\(url.absoluteURL.path())` is not a directory."
        case let .sdefFailed(cause):
            "Failed to create sdef. Cause: `\(cause)`"
        case let .sdpFailed(sdefFile, cause):
            "Failed to process `\(sdefFile.path())`. Cause: `\(cause)`"
        }
    }
}
