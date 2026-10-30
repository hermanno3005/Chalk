import Foundation

/// `a`, `a and b`, `a, b and c`, or `nil` for nothing to list: how a sentence names
/// several things, `3 exercises and 1 gym`.
func listed(_ parts: [String]) -> String? {
    guard let last = parts.last else { return nil }
    guard parts.count > 1 else { return last }
    return String(localized: "\(parts.dropLast().joined(separator: ", ")) and \(last)")
}
