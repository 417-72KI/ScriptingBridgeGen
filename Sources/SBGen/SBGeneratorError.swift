import Foundation

enum SBGeneratorError: LocalizedError {
    case notDirectory(URL)
}

extension SBGeneratorError {
    var errorDescription: String? {
        switch self {
        case let .notDirectory(url):
            "`\(url.absoluteURL.path())` is not a directory."
        }
    }
}
