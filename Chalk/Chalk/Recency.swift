import Foundation

/// **The one order Chalk puts anything in**: most recently used first, never-used after
/// them, ties by name.
///
/// The library's tiles (SPEC §7.1), the gyms in the current-gym picker (§7.4) and the
/// machines in the machine menu (§5.3) are all this rule over a different thing — and all
/// of them are **derived, never stored**: no `sortIndex`, nothing to maintain.
enum Recency {

    /// `items` in that order. `lastUsed` is read **once per item, before the sort**: the
    /// comparator runs O(n log n) times and every call would fault a relationship back in.
    static func order<Item>(
        _ items: [Item],
        lastUsed: (Item) -> Date?,
        name: (Item) -> String
    ) -> [Item] {
        items
            .map { (item: $0, lastUsed: lastUsed($0)) }
            .sorted { left, right in
                switch (left.lastUsed, right.lastUsed) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    return leftDate > rightDate
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return name(left.item).localizedStandardCompare(name(right.item)) == .orderedAscending
                }
            }
            .map(\.item)
    }
}
