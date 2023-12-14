import Foundation

public func enumCase(_ enumCase: String, prefix: String = "") throws -> String {
    let strippedCase = enumCase.trimmingPrefix(prefix)
    let allCapsRe = #/^([A-Z]+)($)/#
    let singleCapRe = #/^([A-Z])([^A-Z]+.*)/#
    let multipleCapsRe = #/^([A-Z]+)([A-Z]([^0-9]+.*))/#
    let capsToDigitRe = #/^([A-Z]+)([0-9]+.*)/#
    return if let match = strippedCase.firstMatch(of: allCapsRe) {
        match.output.1.lowercased() + match.output.2
    } else if let match = strippedCase.firstMatch(of: singleCapRe) {
        match.output.1.lowercased() + match.output.2
    } else if let match = strippedCase.firstMatch(of: capsToDigitRe) {
        match.output.1.lowercased() + match.output.2
    } else if let match = strippedCase.firstMatch(of: multipleCapsRe) {
        match.output.1.lowercased() + match.output.2
    } else {
        String(strippedCase)
    }
}
