import Foundation
import Observation
import SwiftData

/// An erg's history sheet (SPEC §13.9): **the point's sheet** behind the readout's
/// `12 entries ›`, or **the over-20:00 list** behind the caption under the line. With
/// §5.6's sheet, the only place an erg's entries are edited or deleted.
///
/// - **The point's sheet lists every entry at this duration, zone and incline on this
///   scope, from all time**, newest first — everything that could make the point — with
///   a divider after the tenth visit: `Older — not in the line`. Nothing is flagged: a
///   mean has no one entry setting it. **The rows above the divider are the readout's
///   count**, read off the same `ZoneLine` so the two never disagree.
/// - **The over-20:00 list** is this zone and incline's entries over 20:00, one flat list,
///   newest first, with no divider: they make no point.
///
/// **The sheet mirrors the point rather than holding on to its rows.** An edit that moves
/// an entry to another duration, zone, incline or scope makes its row vanish; removing
/// one inside the window can pull an older visit above the divider; and an emptied point
/// leaves the sheet open and empty. None is a special case — each is the re-read.
@Observable
final class ErgHistoryModel: Identifiable {

    /// Which of the two lists the sheet is.
    enum Listing: Equatable {
        /// The point at this duration, in whole seconds.
        case point(duration: Int)
        /// Everything over 20:00.
        case overTheAxis
    }

    /// One line of history: `date · intensity · avg/peak bpm`, with the duration too on
    /// the over-20:00 list, where the point does not fix it. The words are copied off the
    /// entry when the list is built; the entry is held for the two verbs that act on it.
    struct Row: Identifiable {
        let id: UUID
        /// The day, in the words the tiles and the resume card use.
        let day: String
        /// `22:00` — on the over-20:00 list only; nil on a point's sheet.
        let duration: String?
        /// `15.0 km/h (4:00 /km)`, `260 W`: the pace beside a speed.
        let intensity: String
        /// `164/170 bpm`.
        let heartRate: String

        /// The whole row in the spec's order: `date · duration · intensity · avg/peak bpm`.
        var text: String {
            [day, duration, intensity, heartRate].compactMap { $0 }.joined(separator: " · ")
        }

        /// The entry the row stands for, which edit and delete act on. **Not for reading
        /// through** — the list is rebuilt on every write.
        fileprivate let entry: Entry
    }

    /// Where the point's window ends, between `rows` and `older`.
    static let divider = "Older — not in the line"

    let id = UUID()
    let listing: Listing

    /// The point's rows inside its ten-visit window — **exactly the readout's count** —
    /// or the whole over-20:00 list.
    private(set) var rows: [Row] = []

    /// The point's rows under the divider: entries at this duration from before its
    /// window. Always empty on the over-20:00 list, which has no divider.
    private(set) var older: [Row] = []

    @ObservationIgnored private let erg: Exercise
    /// The scope — the detail screen's machine, nil on a transferable erg.
    @ObservationIgnored private let machine: Machine?
    @ObservationIgnored private let zone: Int
    /// In the log's 0.5 % steps; 0, and never read, on any erg but a speed one.
    @ObservationIgnored private let incline: Double

    @ObservationIgnored private let context: ModelContext
    /// Carried through to the log sheet an edited row opens; nothing here reads them.
    @ObservationIgnored private let gyms: GymsModel
    /// Where the zones and the distance unit are held, read live on every refresh
    /// (ADR-0005).
    @ObservationIgnored private let defaults: UserDefaults
    /// The screens behind the sheet — the detail screen and the library — which every
    /// write here has to put back in step.
    @ObservationIgnored private let onChange: () -> Void

    init(
        erg: Exercise,
        machine: Machine?,
        zone: Int,
        incline: Double,
        listing: Listing,
        context: ModelContext,
        gyms: GymsModel,
        defaults: UserDefaults,
        onChange: @escaping () -> Void = {}
    ) {
        self.erg = erg
        self.machine = machine
        self.zone = zone
        self.incline = incline
        self.listing = listing
        self.context = context
        self.gyms = gyms
        self.defaults = defaults
        self.onChange = onChange
        refresh()
    }

    /// The point the sheet fixes, said once so the rows can leave it out: `6:00 in Z4`,
    /// `Over 20:00 in Z4`, with the incline on a speed erg (`· 1 %`).
    var title: String {
        var title = switch listing {
        case .point(let duration): "\(EnduranceText.clock(duration)) in Z\(zone)"
        case .overTheAxis: "Over \(EnduranceText.clock(ZoneLine.axisEnd)) in Z\(zone)"
        }
        if erg.ergUnit?.hasIncline == true { title += " · \(EnduranceText.incline(incline)) %" }
        return title
    }

    /// **The point has nothing left** — its last entry deleted or edited away. The sheet
    /// stays open and empty (SPEC §13.9); the screen behind it settles on its own.
    var isEmpty: Bool { rows.isEmpty && older.isEmpty }

    // MARK: - Edit and delete

    /// The lap-list grid over **one row, seeded from that entry** — an edit (SPEC §13.7,
    /// §6.6). The machine comes off the row's own entry, not the scope, so correcting a
    /// mislabelled one starts from what it says.
    func editSheet(for row: Row, onSave: @escaping () -> Void = {}) -> LapListModel? {
        LapListModel(
            erg: erg,
            machine: row.entry.machine,
            editing: row.entry,
            context: context,
            gyms: gyms,
            defaults: defaults
        ) { [weak self] in
            self?.refresh()
            self?.onChange()
            onSave()
        }
    }

    /// Swipe left → Delete, exactly §5.6: full-swipe disabled in the view, no alert, no
    /// undo, and no entry a special case.
    func delete(_ row: Row) {
        context.delete(row.entry)
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        refresh()
        onChange()
    }

    /// Re-reads the line the sheet was opened from and rebuilds the list — at init and
    /// after every edit and delete.
    func refresh() {
        guard let unit = erg.ergUnit else {
            rows = []
            older = []
            return
        }
        // The same line the readout reads, so its count and the rows above the divider
        // are one number; the membership rule lives in `ZoneLine` alone.
        let line = ZoneLine(
            entries: MachineScope.entries(of: erg, on: machine),
            zones: HeartRateZones(defaults: defaults),
            unit: unit,
            zone: zone,
            incline: incline
        )
        let distanceUnit = DistanceUnit(defaults: defaults)
        switch listing {
        case .point(let duration):
            let entries = line.entries(at: duration)
            let cutOff = line.cutOff(at: duration) ?? .distantPast
            rows = entries.filter { $0.date >= cutOff }.map { row($0, unit, distanceUnit, duration: false) }
            older = entries.filter { $0.date < cutOff }.map { row($0, unit, distanceUnit, duration: false) }
        case .overTheAxis:
            rows = line.entriesOverTheAxis.map { row($0, unit, distanceUnit, duration: true) }
            older = []
        }
    }

    private func row(_ entry: Entry, _ unit: ErgUnit, _ distanceUnit: DistanceUnit, duration: Bool) -> Row {
        Row(
            id: entry.id,
            day: RelativeDay.text(for: entry.date, asOf: .now),
            duration: duration ? EnduranceText.clock(entry.duration) : nil,
            intensity: EnduranceText.intensity(entry.intensity, unit, distanceUnit),
            heartRate: "\(entry.averageHeartRate)/\(entry.peakHeartRate) bpm",
            entry: entry
        )
    }
}
