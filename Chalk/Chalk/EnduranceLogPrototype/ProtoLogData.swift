import Foundation
import Observation

// PROTOTYPE — sample data and the entry draft for #97. In memory only; nothing is stored.
//
// Built on three answers from the dev: they log **after the block**, typing it from the
// watch's lap list rather than in each rest; **nothing follows a pattern** from one
// interval to the next, so a seed rarely survives whole; and the watch shows **average
// and peak on one screen**. Each erg below therefore carries the block just run, as the
// lap list shows it, rests and warm-up included: transcribing it is the job being judged.

/// The four units (#94). A kind of number, never a brand.
enum ProtoUnit {
    case speed, watts, split, level
}

/// The fields of one endurance entry, in the order the written form reads them:
/// `6:00 at 15.0 km/h · 1 % · 168/174 bpm`. Incline exists on speed ergs only.
enum ProtoField: String, CaseIterable, Hashable {
    case duration, intensity, incline, average, peak
}

/// One entry being typed: every field optional, because blank is a real state while typing.
typealias ProtoValues = [ProtoField: Double]

/// One lap as the watch's lap list shows it. `entry` is what you would log for it — nil
/// for a rest or the warm-up walk, which the watch does not tell apart from work.
struct ProtoLap: Identifiable {
    let id = UUID()
    let number: Int
    let time: String
    let average: Int
    let peak: Int
    /// What you set, from memory: the watch does not know the treadmill's speed.
    let set: String
    let entry: ProtoValues?
}

/// One point of the erg's zone line (ADR-0006), stubbed: the mean intensity of a
/// duration's in-zone entries over the last ten visits.
struct ProtoLinePoint {
    let zone: Int
    let duration: Double
    let incline: Double?
    let intensity: Double
    let entries: Int
}

struct ProtoLogErg: Identifiable {
    let id: String
    let name: String
    let unit: ProtoUnit
    /// `Technogym Excite · FitX Mitte` for a gym-bound erg; nil is transferable, and a
    /// transferable sheet carries no machine row at all (§6.4).
    let machine: String?
    /// Your most recent entry before this block — the seed.
    let last: ProtoValues
    let laps: [ProtoLap]
    let line: [ProtoLinePoint]

    var fields: [ProtoField] {
        unit == .speed ? ProtoField.allCases : ProtoField.allCases.filter { $0 != .incline }
    }

    static let all: [ProtoLogErg] = [treadmill, rower, bike, stairmaster]

    static let treadmill = ProtoLogErg(
        id: "Treadmill",
        name: "Treadmill",
        unit: .speed,
        machine: "Technogym Excite · FitX Mitte",
        last: [.duration: 360, .intensity: 14.5, .incline: 1, .average: 160, .peak: 167],
        laps: [
            ProtoLap(number: 1, time: "10:00", average: 128, peak: 141, set: "warm-up, 10.0 km/h", entry: nil),
            ProtoLap(number: 2, time: "6:02", average: 156, peak: 164, set: "15.0 km/h · 1 %",
                     entry: [.duration: 362, .intensity: 15.0, .incline: 1, .average: 156, .peak: 164]),
            ProtoLap(number: 3, time: "2:00", average: 138, peak: 158, set: "walk", entry: nil),
            ProtoLap(number: 4, time: "6:00", average: 163, peak: 170, set: "15.0 km/h · 1 %",
                     entry: [.duration: 360, .intensity: 15.0, .incline: 1, .average: 163, .peak: 170]),
            ProtoLap(number: 5, time: "2:01", average: 141, peak: 163, set: "walk", entry: nil),
            ProtoLap(number: 6, time: "3:00", average: 167, peak: 174, set: "16.0 km/h · 1 %",
                     entry: [.duration: 180, .intensity: 16.0, .incline: 1, .average: 167, .peak: 174]),
            ProtoLap(number: 7, time: "1:30", average: 145, peak: 168, set: "walk", entry: nil),
            ProtoLap(number: 8, time: "1:00", average: 172, peak: 179, set: "18.0 km/h · 2 %",
                     entry: [.duration: 60, .intensity: 18.0, .incline: 2, .average: 172, .peak: 179]),
        ],
        line: [
            ProtoLinePoint(zone: 4, duration: 360, incline: 1, intensity: 14.6, entries: 7),
            ProtoLinePoint(zone: 3, duration: 360, incline: 1, intensity: 13.8, entries: 4),
            ProtoLinePoint(zone: 4, duration: 180, incline: 1, intensity: 15.4, entries: 3),
            ProtoLinePoint(zone: 5, duration: 180, incline: 1, intensity: 16.2, entries: 2),
        ]
    )

    static let rower = ProtoLogErg(
        id: "Rower",
        name: "Rower",
        unit: .split,
        machine: nil,
        last: [.duration: 240, .intensity: 112, .average: 158, .peak: 166],
        laps: [
            ProtoLap(number: 1, time: "4:00", average: 162, peak: 170, set: "1:50 /500 m",
                     entry: [.duration: 240, .intensity: 110, .average: 162, .peak: 170]),
            ProtoLap(number: 2, time: "1:00", average: 141, peak: 168, set: "rest", entry: nil),
            ProtoLap(number: 3, time: "4:00", average: 167, peak: 174, set: "1:48 /500 m",
                     entry: [.duration: 240, .intensity: 108, .average: 167, .peak: 174]),
            ProtoLap(number: 4, time: "1:00", average: 146, peak: 172, set: "rest", entry: nil),
            ProtoLap(number: 5, time: "4:00", average: 171, peak: 177, set: "1:47.5 /500 m",
                     entry: [.duration: 240, .intensity: 107.5, .average: 171, .peak: 177]),
        ],
        line: [
            ProtoLinePoint(zone: 4, duration: 240, incline: nil, intensity: 111, entries: 5),
            ProtoLinePoint(zone: 5, duration: 240, incline: nil, intensity: 108.4, entries: 2),
        ]
    )

    static let bike = ProtoLogErg(
        id: "BikeErg",
        name: "BikeErg",
        unit: .watts,
        machine: nil,
        last: [.duration: 600, .intensity: 200, .average: 150, .peak: 158],
        laps: [
            ProtoLap(number: 1, time: "10:00", average: 152, peak: 160, set: "210 W",
                     entry: [.duration: 600, .intensity: 210, .average: 152, .peak: 160]),
            ProtoLap(number: 2, time: "3:00", average: 139, peak: 158, set: "easy", entry: nil),
            ProtoLap(number: 3, time: "5:00", average: 164, peak: 171, set: "250 W",
                     entry: [.duration: 300, .intensity: 250, .average: 164, .peak: 171]),
            ProtoLap(number: 4, time: "2:00", average: 170, peak: 178, set: "300 W",
                     entry: [.duration: 120, .intensity: 300, .average: 170, .peak: 178]),
        ],
        line: [
            ProtoLinePoint(zone: 3, duration: 600, incline: nil, intensity: 195, entries: 6),
            ProtoLinePoint(zone: 4, duration: 300, incline: nil, intensity: 240, entries: 3),
        ]
    )

    static let stairmaster = ProtoLogErg(
        id: "Stairmaster",
        name: "Stairmaster",
        unit: .level,
        machine: "StairMaster 8G · FitX Mitte",
        last: [.duration: 480, .intensity: 10, .average: 148, .peak: 155],
        laps: [
            ProtoLap(number: 1, time: "8:00", average: 147, peak: 154, set: "Level 10",
                     entry: [.duration: 480, .intensity: 10, .average: 147, .peak: 154]),
            ProtoLap(number: 2, time: "4:00", average: 160, peak: 168, set: "Level 13",
                     entry: [.duration: 240, .intensity: 13, .average: 160, .peak: 168]),
        ],
        line: [
            ProtoLinePoint(zone: 3, duration: 480, incline: nil, intensity: 10, entries: 4),
        ]
    )
}

/// Your heart-rate zones, as typed on Settings (ADR-0005): four lower bounds, Z2–Z5.
enum ProtoZones {
    static let lowerBounds = [130, 145, 158, 170]

    static func zone(_ bpm: Double) -> Int {
        (lowerBounds.lastIndex { Double($0) <= bpm } ?? -1) + 2
    }

    static func range(_ zone: Int) -> String {
        switch zone {
        case 1: return "below \(lowerBounds[0])"
        case 5: return "\(lowerBounds[3])+ bpm"
        default: return "\(lowerBounds[zone - 2])–\(lowerBounds[zone - 1] - 1) bpm"
        }
    }
}

/// What a verdict line says, if anything. A pill on the switcher, so each layout can be
/// judged with and without one.
enum ProtoVerdictMode: String, CaseIterable {
    case none = "no verdict"
    case zone = "zone"
    case line = "vs the line"
}

/// Every session's tallies, so the variants can be compared on the same block: how many
/// taps and how many sheet opens it took to log it.
@Observable
final class ProtoTally {
    struct Saved: Identifiable {
        let id = UUID()
        let values: ProtoValues
    }

    var taps = 0
    var opens = 0
    var saved: [Saved] = []

    func tap() { taps += 1 }

    func reset() {
        taps = 0
        opens = 0
        saved = []
    }
}

// MARK: - Writing a number

enum ProtoText {
    static var decimal: String { Locale.current.decimalSeparator ?? "." }

    /// `m:ss`, `h:mm:ss` from an hour, with a split's tenth when it has one.
    static func clock(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded(.down))
        let tenth = Int(((seconds - Double(whole)) * 10).rounded())
        let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
        var text = h > 0 ? "\(h):\(pad(m)):\(pad(s))" : "\(m):\(pad(s))"
        if tenth > 0 { text += "\(decimal)\(tenth)" }
        return text
    }

    static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    /// The number alone, as the field shows it.
    static func number(_ value: Double, _ field: ProtoField, _ unit: ProtoUnit) -> String {
        switch field {
        case .duration: return clock(value)
        case .average, .peak: return String(Int(value))
        case .incline: return value.formatted(.number.precision(.fractionLength(0...1)))
        case .intensity:
            switch unit {
            case .speed: return value.formatted(.number.precision(.fractionLength(1)))
            case .watts, .level: return String(Int(value))
            case .split: return clock(value)
            }
        }
    }

    static func unit(_ field: ProtoField, _ unit: ProtoUnit) -> String {
        switch field {
        case .duration: return ""
        case .incline: return "%"
        case .average, .peak: return "bpm"
        case .intensity:
            switch unit {
            case .speed: return "km/h"
            case .watts: return "W"
            case .split: return "/500 m"
            case .level: return "level"
            }
        }
    }

    static func name(_ field: ProtoField, _ unit: ProtoUnit) -> String {
        switch field {
        case .duration: return "Duration"
        case .incline: return "Incline"
        case .average: return "Average heart rate"
        case .peak: return "Peak heart rate"
        case .intensity:
            switch unit {
            case .speed: return "Speed"
            case .watts: return "Power"
            case .split: return "Split"
            case .level: return "Level"
            }
        }
    }

    /// The lap list's column titles.
    static func column(_ field: ProtoField, _ unit: ProtoUnit) -> String {
        switch field {
        case .duration: return "Time"
        case .incline: return "%"
        case .average: return "Avg"
        case .peak: return "Peak"
        case .intensity: return unit == .level ? "Level" : self.unit(field, unit)
        }
    }

    /// A speed's pace, worked out for display and never stored (#94).
    static func pace(_ kmh: Double) -> String {
        "\(clock((3600 / kmh).rounded())) /km"
    }

    /// The written form (#94): `6:00 at 15.0 km/h (4:00 /km) · 1 % · 168/174 bpm`.
    /// Incline is omitted at 0 %.
    static func written(_ values: ProtoValues, _ unit: ProtoUnit) -> String {
        func n(_ f: ProtoField) -> String { values[f].map { number($0, f, unit) } ?? "–" }
        var intensity: String
        switch unit {
        case .speed:
            intensity = "\(n(.intensity)) km/h"
            if let kmh = values[.intensity], kmh > 0 { intensity += " (\(pace(kmh)))" }
        case .watts: intensity = "\(n(.intensity)) W"
        case .split: intensity = "\(n(.intensity)) /500 m"
        case .level: intensity = "Level \(n(.intensity))"
        }
        var text = "\(n(.duration)) at \(intensity)"
        if unit == .speed, let incline = values[.incline], incline > 0 { text += " · \(n(.incline)) %" }
        return text + " · \(n(.average))/\(n(.peak)) bpm"
    }
}

// MARK: - Checking and judging

enum ProtoCheck {
    /// Peak below average is **impossible**, not implausible, so it blocks Save (#94).
    /// The 40–230 bounds are assumed to block too — they are the zone bounds.
    static func problem(_ values: ProtoValues) -> String? {
        if let average = values[.average], let peak = values[.peak], peak < average {
            return "Peak can't be below the average"
        }
        for field in [ProtoField.average, .peak] {
            if let bpm = values[field], !(40...230).contains(bpm) { return "Heart rate is 40–230 bpm" }
        }
        return nil
    }

    static func canSave(_ values: ProtoValues, _ erg: ProtoLogErg) -> Bool {
        guard problem(values) == nil else { return false }
        return erg.fields.allSatisfy { field in
            guard let value = values[field] else { return false }
            return field == .incline ? value >= 0 : value > 0
        }
    }

    /// The verdict line, read off the average. Never a prediction — there is none to make
    /// (#95) — only which zone the average lands in, or the line's point it sits beside.
    static func verdict(_ values: ProtoValues, _ erg: ProtoLogErg, _ mode: ProtoVerdictMode) -> String? {
        guard mode != .none, let average = values[.average], (40...230).contains(average) else { return nil }
        let zone = ProtoZones.zone(average)
        switch mode {
        case .none: return nil
        case .zone: return "Z\(zone) · \(ProtoZones.range(zone))"
        case .line:
            guard let duration = values[.duration] else { return "Z\(zone)" }
            let incline = erg.unit == .speed ? values[.incline] : nil
            let point = erg.line.first { $0.zone == zone && $0.duration == duration && $0.incline == incline }
            let at = ProtoText.clock(duration)
            guard let point else { return "Z\(zone) · your first \(at) in Z\(zone) here" }
            let intensity = ProtoText.number(point.intensity, .intensity, erg.unit)
            let unit = erg.unit == .level ? "" : " \(ProtoText.unit(.intensity, erg.unit))"
            let level = erg.unit == .level ? "Level " : ""
            return "Z\(zone) · your \(at) in Z\(zone) is \(level)\(intensity)\(unit) · \(point.entries) entries"
        }
    }
}

// MARK: - The editor every variant types into

/// One entry's fields and the field in focus. **Typing replaces the seed**: the first key
/// on a field blanks it, and leaving a field with nothing typed puts the seed back — a
/// stray tap is not an edit (§6.3's rule, carried over).
struct ProtoEditor {
    let unit: ProtoUnit
    let fields: [ProtoField]
    private(set) var values: ProtoValues
    private(set) var focus: ProtoField
    /// Non-nil while the keypad is typing over `focus`.
    private var typed: String?
    private var before: Double?

    init(erg: ProtoLogErg, seed: ProtoValues, focus: ProtoField? = nil) {
        unit = erg.unit
        fields = erg.fields
        values = seed.filter { erg.fields.contains($0.key) }
        self.focus = focus.flatMap { erg.fields.contains($0) ? $0 : nil } ?? .duration
    }

    var isTyping: Bool { typed != nil }
    var isLast: Bool { focus == fields.last }

    func text(_ field: ProtoField) -> String {
        if field == focus, let typed { return Self.display(typed, field, unit) }
        return values[field].map { ProtoText.number($0, field, unit) } ?? ""
    }

    var decimalIsDead: Bool { !Self.takesDecimal(focus, unit) }

    mutating func focus(on field: ProtoField) {
        settle()
        focus = field
    }

    /// Moves to the next field. False at the last one.
    @discardableResult
    mutating func next() -> Bool {
        guard let index = fields.firstIndex(of: focus), index + 1 < fields.count else {
            settle()
            return false
        }
        focus(on: fields[index + 1])
        return true
    }

    /// Closes the keypad over the focused field. Nothing typed puts the seed back.
    mutating func settle() {
        if let typed, typed.isEmpty { values[focus] = before }
        typed = nil
        before = nil
    }

    /// Variant A's tap on the giant number: the keypad opens blank, and closes back to
    /// whatever was there if nothing was typed (§6.2).
    mutating func toggleKeypad() {
        if typed != nil { settle() } else { beginTyping() }
    }

    private mutating func beginTyping() {
        guard typed == nil else { return }
        before = values[focus]
        typed = ""
        values[focus] = nil
    }

    /// One key. True when the field is complete and the caller may move on by itself —
    /// only where that is unambiguous: a heart rate's last digit, a speed's tenth.
    @discardableResult
    mutating func type(_ key: TwoStageNumber.Key) -> Bool {
        beginTyping()
        var text = typed ?? ""
        let fraction = text.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first
        switch key {
        case .digit(let digit):
            guard text.count < Self.maxLength(focus, unit) else { return false }
            if let fraction {
                guard fraction.isEmpty else { return false }
                if focus == .incline, digit != 0, digit != 5 { return false }
            }
            text = text == "0" ? String(digit) : text + String(digit)
        case .decimal:
            guard Self.takesDecimal(focus, unit), !text.contains(".") else { return false }
            text = text.isEmpty ? "0." : text + "."
        case .delete:
            guard !text.isEmpty else { return false }
            text.removeLast()
        }
        typed = text
        values[focus] = Self.parse(text, focus, unit)
        return Self.isComplete(text, focus, unit)
    }

    /// One stepper tap, snapped to the field's grid as weight snaps to 2.5 kg (§6.2).
    mutating func step(_ direction: Int) {
        settle()
        let (grid, low, high) = Self.stepping(focus, unit)
        let value = values[focus] ?? low
        let steps = value / grid
        let nearest = steps.rounded()
        let onGrid = abs(steps - nearest) < 1e-6
        let target = onGrid
            ? nearest + Double(direction < 0 ? -1 : 1)
            : (direction < 0 ? steps.rounded(.down) : steps.rounded(.up))
        values[focus] = min(high, max(low, (target * grid * 10).rounded() / 10))
    }

    /// Stepper sizes per field — this ticket's call (#94). Assumed, for reacting to:
    /// 15 s, 0.1 km/h (the belt's own button), 5 W, 1 s of split, 1 level, 0.5 %, 1 bpm.
    static func stepping(_ field: ProtoField, _ unit: ProtoUnit) -> (grid: Double, low: Double, high: Double) {
        switch field {
        case .duration: return (15, 15, 36000)
        case .incline: return (0.5, 0, 40)
        case .average, .peak: return (1, 40, 230)
        case .intensity:
            switch unit {
            case .speed: return (0.1, 0.1, 40)
            case .watts: return (5, 5, 3000)
            case .split: return (1, 1, 600)
            case .level: return (1, 1, 99)
            }
        }
    }

    private static func isClock(_ field: ProtoField, _ unit: ProtoUnit) -> Bool {
        field == .duration || (field == .intensity && unit == .split)
    }

    private static func takesDecimal(_ field: ProtoField, _ unit: ProtoUnit) -> Bool {
        switch field {
        case .incline: return true
        case .intensity: return unit == .speed || unit == .split
        default: return false
        }
    }

    private static func maxLength(_ field: ProtoField, _ unit: ProtoUnit) -> Int {
        switch field {
        case .duration: return 4
        case .average, .peak: return 3
        case .incline: return 4
        case .intensity:
            switch unit {
            case .speed, .watts: return 4
            case .split: return 5
            case .level: return 2
            }
        }
    }

    /// Times fill from the right, like a microwave: `6`, `60`, `600` → 6:00.
    private static func parse(_ text: String, _ field: ProtoField, _ unit: ProtoUnit) -> Double? {
        guard !text.isEmpty else { return nil }
        guard isClock(field, unit) else { return Double(text) }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let digits = String(parts[0])
        let tenth = parts.count > 1 ? Double(parts[1]).map { $0 / 10 } ?? 0 : 0
        let seconds = Double(digits.suffix(2)) ?? 0
        let minutes = digits.count > 2 ? Double(digits.dropLast(2)) ?? 0 : 0
        return minutes * 60 + seconds + tenth
    }

    private static func display(_ text: String, _ field: ProtoField, _ unit: ProtoUnit) -> String {
        guard !text.isEmpty else { return "" }
        guard isClock(field, unit) else { return text.replacingOccurrences(of: ".", with: ProtoText.decimal) }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let digits = String(parts[0])
        let seconds = digits.count >= 2 ? String(digits.suffix(2)) : "0" + digits
        let minutes = digits.count > 2 ? String(digits.dropLast(2)) : "0"
        let tenth = parts.count > 1 ? ProtoText.decimal + parts[1] : ""
        return "\(minutes):\(seconds)\(tenth)"
    }

    private static func isComplete(_ text: String, _ field: ProtoField, _ unit: ProtoUnit) -> Bool {
        switch field {
        case .average, .peak:
            guard let first = text.first?.wholeNumberValue else { return false }
            return text.count == 3 || (text.count == 2 && first >= 4)
        case .intensity where unit == .speed:
            return text.contains(".") && !text.hasSuffix(".")
        default:
            return false
        }
    }
}
