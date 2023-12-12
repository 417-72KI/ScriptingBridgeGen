import Foundation

extension Int {
    var hexChars: String {
        var remaining: Int = self
        var chars: [Character] = []
        while remaining > 0 {
            defer { remaining >>= 8 }
            let digit = remaining & 0xFF
            chars.insert(Character(UnicodeScalar(digit)!), at: 0)
        }
        return String(chars)
    }
}
