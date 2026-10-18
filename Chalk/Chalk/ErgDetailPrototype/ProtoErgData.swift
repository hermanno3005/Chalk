import SwiftUI

// PROTOTYPE — in-memory sample data for the erg detail screen (#98). Nothing here is
// derived from entries: each zone line's points are written out by hand, as the
// derivation (ADR-0006) would hand them over — mean intensity per duration, with mean
// heart rate and entry count. The question is how they read, not whether they compute.

enum ProtoUnit {
    case speed, watts, split, level
}

/// One point of a zone line: one duration, the mean intensity held at it in this zone over
/// the last ten visits, the mean average heart rate of those entries, and how many there were.
struct ProtoPoint: Identifiable, Hashable {
    let seconds: Int
    let value: Double
    let hr: Int
    let count: Int
    var id: Int { seconds }
}

/// Every zone's line on one scope, per incline (a non-speed erg has one key, 0).
struct ProtoScope {
    var lines: [Double: [Int: [ProtoPoint]]]
    /// Where the screen opens: the zone, duration and incline of your most recent entry.
    var last: (zone: Int, seconds: Int, incline: Double)
    var entryCount: Int

    static let empty = ProtoScope(lines: [:], last: (4, 360, 1), entryCount: 0)

    var inclines: [Double] { lines.keys.sorted() }

    func line(zone: Int, incline: Double) -> [ProtoPoint] {
        (lines[incline]?[zone] ?? []).sorted { $0.seconds < $1.seconds }
    }

    func durations(incline: Double) -> [Int] {
        Set((lines[incline] ?? [:]).values.flatMap { $0.map(\.seconds) }).sorted()
    }
}

enum ProtoDataset: String, CaseIterable {
    case typical = "typical"
    case firstVisit = "first visit"
    case nothing = "nothing logged"
    case noZones = "zones not set"
}

enum ProtoAxis: String, CaseIterable {
    case fixedLog = "x: 0:30–20:00 log"
    case fixedLinear = "x: 0:30–20:00 linear"
    case framed = "x: framed"
}

struct ProtoErg: Identifiable {
    let id: String
    let name: String
    let unit: ProtoUnit
    /// The machine in scope, or nil for a transferable erg.
    let machine: String?
    /// Another machine with no entries, for the *nothing logged* dataset.
    let freshMachine: String?
    let typical: ProtoScope
    let firstVisit: ProtoScope

    func scope(_ dataset: ProtoDataset) -> ProtoScope {
        switch dataset {
        case .typical, .noZones: typical
        case .firstVisit: firstVisit
        case .nothing: .empty
        }
    }

    func machineLabel(_ dataset: ProtoDataset) -> String? {
        dataset == .nothing ? freshMachine : machine
    }

    /// §5.4's hint, carried over: the sibling's zone-line point at the zone and duration of
    /// its most recent entry — the same place the log sheet's first row is seeded from.
    var hint: String? {
        guard let machine, freshMachine != nil else { return nil }
        let last = typical.last
        guard let point = typical.line(zone: last.zone, incline: last.incline)
            .first(where: { $0.seconds == last.seconds })
        else { return nil }
        let incline = unit == .speed ? " · \(ProtoFormat.incline(last.incline))" : ""
        return "No entries here — \(ProtoFormat.duration(last.seconds)) in Z\(last.zone) at \(ProtoFormat.full(point.value, unit))\(incline) on \(machine)"
    }
}

private func p(_ seconds: Int, _ value: Double, _ hr: Int, _ count: Int) -> ProtoPoint {
    ProtoPoint(seconds: seconds, value: value, hr: hr, count: count)
}

private func split(_ minutes: Int, _ seconds: Double) -> Double { Double(minutes * 60) + seconds }

extension ProtoErg {
    static let treadmill = ProtoErg(
        id: "treadmill",
        name: "Treadmill",
        unit: .speed,
        machine: "Technogym Run · Urban Gym",
        freshMachine: "Life Fitness · McFit",
        typical: ProtoScope(
            lines: [
                1: [
                    5: [p(60, 18.5, 171, 4), p(180, 17.0, 173, 6), p(360, 16.0, 172, 3)],
                    4: [p(180, 15.8, 164, 2), p(360, 15.0, 164, 12), p(600, 14.6, 162, 5)],
                    3: [p(360, 13.8, 152, 2), p(600, 13.2, 150, 3), p(1200, 12.6, 151, 4)],
                    // Out of order on purpose: drawn as it comes out (ADR-0006).
                    2: [p(600, 10.8, 139, 2), p(1200, 11.0, 137, 6)],
                ],
                0: [
                    5: [p(180, 17.4, 172, 3)],
                    4: [p(360, 15.4, 163, 4)],
                ],
            ],
            last: (4, 360, 1),
            entryCount: 47
        ),
        firstVisit: ProtoScope(
            lines: [1: [5: [p(180, 16.5, 172, 4)]]],
            last: (5, 180, 1),
            entryCount: 4
        )
    )

    static let rower = ProtoErg(
        id: "rower",
        name: "Rower",
        unit: .split,
        machine: nil,
        freshMachine: nil,
        typical: ProtoScope(
            lines: [
                0: [
                    5: [p(60, split(1, 38), 168, 5), p(240, split(1, 45.5), 172, 8)],
                    4: [p(240, split(1, 49), 163, 6), p(480, split(1, 52), 162, 9)],
                    3: [p(480, split(1, 57), 151, 3), p(1200, split(2, 0), 150, 5)],
                    2: [p(1200, split(2, 8), 136, 4)],
                ],
            ],
            last: (4, 480, 0),
            entryCount: 40
        ),
        firstVisit: ProtoScope(
            lines: [0: [5: [p(240, split(1, 47), 171, 4)], 4: [p(240, split(1, 50.5), 166, 1)]]],
            last: (5, 240, 0),
            entryCount: 5
        )
    )

    static let bike = ProtoErg(
        id: "bike",
        name: "BikeErg",
        unit: .watts,
        machine: nil,
        freshMachine: nil,
        typical: ProtoScope(
            lines: [
                0: [
                    5: [p(300, 280, 171, 4)],
                    4: [p(60, 340, 160, 6), p(300, 255, 163, 8), p(600, 240, 164, 5)],
                    3: [p(600, 215, 152, 3), p(1200, 200, 150, 4)],
                    2: [p(1200, 170, 135, 6)],
                ],
            ],
            last: (4, 300, 0),
            entryCount: 36
        ),
        firstVisit: ProtoScope(
            lines: [0: [5: [p(300, 270, 172, 3)]]],
            last: (5, 300, 0),
            entryCount: 3
        )
    )

    static let stairs = ProtoErg(
        id: "stairs",
        name: "Stairmaster",
        unit: .level,
        machine: "StairMaster 8G · Urban Gym",
        freshMachine: "StairMaster 4G · McFit",
        typical: ProtoScope(
            lines: [
                0: [
                    4: [p(300, 12, 162, 4), p(600, 11, 164, 6)],
                    3: [p(600, 9, 150, 3), p(900, 9, 152, 5)],
                    2: [p(900, 7, 138, 4)],
                ],
            ],
            last: (4, 600, 0),
            entryCount: 22
        ),
        firstVisit: ProtoScope(
            lines: [0: [5: [p(600, 12, 171, 2)]]],
            last: (5, 600, 0),
            entryCount: 2
        )
    )

    static let all: [ProtoErg] = [.treadmill, .rower, .bike, .stairs]
}

// MARK: - Zones

enum ProtoZones {
    /// Lower bounds of Z2–Z5, as typed on Settings (ADR-0005).
    static let bounds = [128, 145, 158, 170]

    static func range(_ zone: Int) -> String {
        switch zone {
        case 1: "below \(bounds[0]) bpm"
        case 5: "\(bounds[3])+ bpm"
        default: "\(bounds[zone - 2])–\(bounds[zone - 1] - 1) bpm"
        }
    }

    /// No orange: that is the goal colour and nothing else's (SPEC §12.5).
    static func color(_ zone: Int) -> Color {
        switch zone {
        case 1: .gray
        case 2: .blue
        case 3: .green
        case 4: .purple
        default: .red
        }
    }
}

// MARK: - Formatting

enum ProtoFormat {
    static func duration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func value(_ v: Double, _ unit: ProtoUnit) -> String {
        switch unit {
        case .speed: String(format: "%.1f", v)
        case .watts: String(format: "%.0f", v)
        case .split:
            String(format: "%d:%04.1f", Int(v) / 60, v.truncatingRemainder(dividingBy: 60))
        case .level: String(format: "%.0f", v)
        }
    }

    static func unitLabel(_ unit: ProtoUnit) -> String {
        switch unit {
        case .speed: "km/h"
        case .watts: "W"
        case .split: "/500 m"
        case .level: ""
        }
    }

    static func full(_ v: Double, _ unit: ProtoUnit) -> String {
        unit == .level ? "level \(value(v, unit))" : "\(value(v, unit)) \(unitLabel(unit))"
    }

    /// A speed's pace, the only number ever worked out from an intensity (CONTEXT.md).
    static func secondary(_ v: Double, _ unit: ProtoUnit) -> String? {
        guard unit == .speed else { return nil }
        let pace = 3600 / v
        return String(format: "%d:%02d /km", Int(pace) / 60, Int(pace.rounded()) % 60)
    }

    static func incline(_ i: Double) -> String {
        i == i.rounded() ? String(format: "%.0f %%", i) : String(format: "%.1f %%", i)
    }
}

// MARK: - The ghost, if one is drawn

enum ProtoGhost {
    /// A Chalk-made extension past the longest duration only — the one stretch #102 found
    /// roughly honest. A hyperbola `I = a + b/d` through the line's two longest points,
    /// carried to 1.5× the longest duration. Split is fitted as speed (500/split) and
    /// turned back. Never on a level erg, never from a single point.
    static func points(_ line: [ProtoPoint], unit: ProtoUnit, maxSeconds: Int) -> [(Int, Double)] {
        guard unit != .level, line.count >= 2 else { return [] }
        let (d1, d2) = (Double(line[line.count - 2].seconds), Double(line[line.count - 1].seconds))
        let toLinear: (Double) -> Double = unit == .split ? { 500 / $0 } : { $0 }
        let fromLinear: (Double) -> Double = unit == .split ? { 500 / $0 } : { $0 }
        let (v1, v2) = (toLinear(line[line.count - 2].value), toLinear(line[line.count - 1].value))
        let b = (v1 - v2) / (1 / d1 - 1 / d2)
        let a = v2 - b / d2
        let end = min(d2 * 1.5, Double(maxSeconds))
        guard end > d2 else { return [] }
        return stride(from: d2, through: end, by: (end - d2) / 8).map {
            (Int($0), fromLinear(a + b / $0))
        }
    }
}
