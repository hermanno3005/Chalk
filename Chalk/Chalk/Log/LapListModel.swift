import Foundation
import Observation
import SwiftData

/// The endurance log sheet's state: **a grid shaped like the watch's lap list**, one row
/// per entry, typed after the block (SPEC §13.7).
///
/// **The rows are a way of typing, not a session.** Save writes one `Entry` per row and
/// nothing groups them afterwards — four laps are four entries, as four lifts are.
///
/// - **Seeding**: the first row from the scope's most recent valid interval — the erg's
///   when transferable, the machine's when gym-bound — and each new row from the row
///   above. A first-ever block opens blank. Typing in a cell replaces its seed.
/// - **One keypad, always up, no steppers.** *Next* walks the cells left to right and
///   becomes *New row* at the end of the last row; a heart rate's last digit and a
///   speed's tenth move on by themselves. The formats are `EnduranceInput`'s, shared
///   with the goal sheet.
/// - **The line under the grid** is the focused row's zone, or why that row cannot be
///   saved. No zone per row, and no goal crossing.
///
/// **The sheet never resolves a machine — its caller does**, as strength's (SPEC §6.4):
/// it is handed one, seeds from that machine's entries and writes every row onto it. A
/// gym-bound erg with none cannot save (SPEC §3, invariant 4).
@Observable
final class LapListModel: Identifiable {

    /// One cell of the grid: a row, by position, and a column.
    struct Cell: Hashable {
        let row: Int
        let field: EnduranceField
    }

    /// One row — one entry-to-be.
    struct Row: Identifiable {
        let id = UUID()
        fileprivate(set) var inputs: [EnduranceField: EnduranceInput]

        func value(_ field: EnduranceField) -> Double? { inputs[field]?.value }

        /// The value as judged: a cell mid-typing is not judged yet.
        fileprivate func settledValue(_ field: EnduranceField) -> Double? {
            inputs[field].flatMap { $0.isTyping ? nil : $0.value }
        }
    }

    /// The line under the grid (SPEC §13.7).
    enum Line: Equatable {
        /// The focused row's zone: `Z4 · 158–169 bpm`.
        case zone(String)
        /// Why the focused row cannot be saved, drawn in red.
        case problem(String)

        var text: String {
            switch self {
            case .zone(let text), .problem(let text): text
            }
        }
    }

    static let peakBelowAverage = "Peak can't be below the average"
    static let heartRateOutOfRange = "Heart rates are 40–230 bpm"

    let id = UUID()
    let erg: Exercise
    let unit: ErgUnit
    /// The grid's columns, in the watch's order: `Time | km/h | % | Avg | Peak` on a speed
    /// erg, `Time | <unit> | Avg | Peak` on the others.
    let columns: [EnduranceField]

    private(set) var rows: [Row] = []
    private(set) var focus = Cell(row: 0, field: .duration)

    /// Whether anything has been typed, or a row added or deleted. **An untouched sheet
    /// closes without asking**; a touched one asks, and swipe-down is off.
    private(set) var isTouched = false

    /// The machine every row is written onto, and the one caption above the grid that
    /// says so and corrects it — strength's, shared (SPEC §13.7, §6.4).
    private var caption: MachineCaption

    /// The machine every row is written onto — the caller's answer, never this sheet's.
    /// `nil` on a transferable erg, which carries no machine at all.
    var machine: Machine? { caption.machine }

    /// The caption above the grid — **once, covering every row**: a block is logged on
    /// one machine. `label · gym`, or `No machine` before any exists; `nil` on a
    /// transferable erg, which carries no caption at all.
    var machineCaption: String? { caption.text }

    /// The rows the caption opens: the shared machine menu, with `New machine here` and
    /// `New gym…`. Empty on a transferable erg.
    var machineMenu: MachineMenu { caption.menu }

    @ObservationIgnored private let context: ModelContext
    /// The gyms, shared with the library.
    @ObservationIgnored let gyms: GymsModel
    /// Where the heart-rate zones are held — read live, never cached (ADR-0005).
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let onSave: () -> Void

    /// `nil` for an exercise that is not an erg: a lift has nothing to type here.
    init?(
        erg: Exercise,
        machine: Machine? = nil,
        context: ModelContext,
        gyms: GymsModel,
        defaults: UserDefaults,
        onSave: @escaping () -> Void = {}
    ) {
        guard let unit = erg.ergUnit else { return nil }
        self.erg = erg
        self.unit = unit
        self.columns = EnduranceField.columns(for: unit)
        self.caption = MachineCaption(exercise: erg, machine: machine, context: context, gyms: gyms)
        self.context = context
        self.gyms = gyms
        self.defaults = defaults
        self.onSave = onSave

        rows = [row(seededFrom: Self.seed(erg, on: machine))]
    }

    // MARK: - Seeding

    /// The first row's values: the scope's most recent valid interval — the erg's when
    /// transferable, **this machine's** when gym-bound, never a sibling's (SPEC §13.7).
    private static func seed(_ erg: Exercise, on machine: Machine?) -> [EnduranceField: Double]? {
        LastInterval.latest(in: MachineScope.entries(of: erg, on: machine)).map(values)
    }

    private static func values(_ last: LastInterval) -> [EnduranceField: Double] {
        var values: [EnduranceField: Double] = [
            .duration: Double(last.duration),
            .intensity: last.intensity,
            // 0 % is a value, seeded like any other — never defaulted to 1 %.
            .incline: last.incline,
            .averageHeartRate: Double(last.averageHeartRate),
        ]
        if last.peakHeartRate > 0 { values[.peakHeartRate] = Double(last.peakHeartRate) }
        return values
    }

    private func row(seededFrom values: [EnduranceField: Double]?) -> Row {
        Row(inputs: Dictionary(uniqueKeysWithValues: columns.map {
            ($0, EnduranceInput($0, unit: unit, value: values?[$0]))
        }))
    }

    // MARK: - What the sheet shows

    func text(_ cell: Cell) -> String {
        rows[cell.row].inputs[cell.field]?.text ?? ""
    }

    /// Over the keypad: `Row 2 · Average heart rate`.
    var focusTitle: String {
        "Row \(focus.row + 1) · \(focus.field.name(unit))"
    }

    /// Whether *Next* is *New row*: the focus is on the last cell of the last row.
    var nextIsNewRow: Bool {
        focus.row == rows.count - 1 && focus.field == columns.last
    }

    var decimalIsDead: Bool {
        !(rows[focus.row].inputs[focus.field]?.takesDecimal ?? false)
    }

    /// Whether a cell is outlined in red: **both heart rates of a row whose peak is below
    /// its average**, or a heart rate outside 40–230 — so a disabled Save points at the row
    /// to fix.
    func isFlagged(_ cell: Cell) -> Bool {
        guard cell.field == .averageHeartRate || cell.field == .peakHeartRate else { return false }
        let row = rows[cell.row]
        if let bpm = row.settledValue(cell.field), !Self.heartRates.contains(bpm) { return true }
        return Self.peakIsBelowAverage(row)
    }

    /// The line under the grid, for the focused row: why it cannot be saved, or else the
    /// zone its average falls in. **Blank without zones** — logging never nags.
    var line: Line? {
        let row = rows[focus.row]
        if let problem = Self.problem(in: row) { return .problem(problem) }
        guard let zones = HeartRateZones(defaults: defaults),
              let average = row.settledValue(.averageHeartRate)
        else { return nil }
        return .zone(zones.zoneLine(of: Int(average)))
    }

    /// `Save 5`, or plain `Save` for one row.
    var saveTitle: String {
        rows.count == 1 ? "Save" : "Save \(rows.count)"
    }

    /// Every row complete and valid — and, on a gym-bound erg, a machine to write onto.
    var canSave: Bool {
        rows.allSatisfy(isValid) && caption.resolves
    }

    /// A red minus on every row **but the last remaining one** — Cancel is how you log
    /// nothing.
    var canDeleteRows: Bool { rows.count > 1 }

    /// Cancel's question once the sheet is touched: *Discard 5 entries?*
    var discardConfirmation: String {
        rows.count == 1 ? "Discard this entry?" : "Discard \(rows.count) entries?"
    }

    // MARK: - Validation

    private static let heartRates = Double(HeartRateZones.range.lowerBound)...Double(HeartRateZones.range.upperBound)

    private static func peakIsBelowAverage(_ row: Row) -> Bool {
        guard let average = row.settledValue(.averageHeartRate),
              let peak = row.settledValue(.peakHeartRate)
        else { return false }
        return peak < average
    }

    private static func problem(in row: Row) -> String? {
        let heartRates = [row.settledValue(.averageHeartRate), row.settledValue(.peakHeartRate)]
        if heartRates.contains(where: { $0.map { !Self.heartRates.contains($0) } ?? false }) {
            return heartRateOutOfRange
        }
        return peakIsBelowAverage(row) ? peakBelowAverage : nil
    }

    /// Complete and valid: every number above zero (incline aside — 0 % is a value), both
    /// heart rates 40–230, and peak ≥ average.
    private func isValid(_ row: Row) -> Bool {
        columns.allSatisfy { field in
            guard let value = row.value(field) else { return false }
            switch field {
            case .duration: return Int(value) > 0
            case .intensity: return value > 0
            case .incline: return value >= 0
            case .averageHeartRate, .peakHeartRate: return Self.heartRates.contains(value)
            }
        } && (row.value(.peakHeartRate) ?? 0) >= (row.value(.averageHeartRate) ?? 0)
    }

    // MARK: - Input

    /// Moves the focus to a tapped cell.
    func select(_ cell: Cell) {
        guard rows.indices.contains(cell.row), columns.contains(cell.field) else { return }
        settle()
        focus = cell
    }

    /// One keypad press on the focused cell. A heart rate's last digit and a speed's tenth
    /// move on to the next cell by themselves — never into a new row.
    func type(_ key: TwoStageNumber.Key) {
        guard let outcome = rows[focus.row].inputs[focus.field]?.type(key) else { return }
        if outcome != .refused { isTouched = true }
        guard outcome == .complete else { return }
        if let next = cell(after: focus) {
            select(next)
        } else {
            // The last cell of the last row: complete, so judged — but never a new row.
            settle()
        }
    }

    /// *Next*: the next cell, left to right — and at the end of the last row, *New row*.
    func next() {
        if let next = cell(after: focus) {
            select(next)
        } else {
            addRow()
        }
    }

    /// A new row at the end, **seeded from the row above**, with the focus on its first
    /// cell.
    func addRow() {
        settle()
        let above = rows[rows.count - 1]
        rows.append(row(seededFrom: above.inputs.compactMapValues(\.value)))
        focus = Cell(row: rows.count - 1, field: columns[0])
        isTouched = true
    }

    /// Deletes a row — never the last remaining one.
    func deleteRow(_ index: Int) {
        guard canDeleteRows, rows.indices.contains(index) else { return }
        settle()
        rows.remove(at: index)
        if focus.row > index || focus.row == rows.count {
            focus = Cell(row: focus.row - 1, field: focus.field)
        }
        isTouched = true
    }

    private func settle() {
        rows[focus.row].inputs[focus.field]?.settle()
    }

    private func cell(after cell: Cell) -> Cell? {
        guard let column = columns.firstIndex(of: cell.field) else { return nil }
        if column + 1 < columns.count { return Cell(row: cell.row, field: columns[column + 1]) }
        if cell.row + 1 < rows.count { return Cell(row: cell.row + 1, field: columns[0]) }
        return nil
    }

    // MARK: - The machine

    /// Corrects the machine from the caption's menu — for every row, since a block is
    /// logged on one machine. **Picking another gym's machine moves the current gym at
    /// the pick** (SPEC §6.4); an archived gym's waits for the Save.
    ///
    /// An untouched sheet re-seeds from the machine you picked — the seed is a number
    /// held *there* (SPEC §13.7) — but a block already typed stays as typed: it is what
    /// you did, and the caption only corrects where you did it.
    func select(_ machine: Machine) {
        guard caption.select(machine), !isTouched else { return }
        rows = [row(seededFrom: Self.seed(erg, on: machine))]
        focus = Cell(row: 0, field: columns[0])
    }

    /// `New machine here` in the caption's menu: the gym is implied by its section, and
    /// **the sheet resolves to the new machine** with no second decision (SPEC §6.4).
    func createMachine(at gym: Gym, named name: String?) {
        caption.createMachine(at: gym, named: name)
    }

    /// `New gym…` came back with one: its section joins the menu, to make the machine in.
    func gymCreated(_ gym: Gym) {
        caption.gymCreated(gym)
    }

    // MARK: - Commit

    /// Writes **one entry per row**, with the typed values, onto the sheet's machine. The
    /// caller closes the sheet.
    ///
    /// The rows are stamped a second apart, ending now, so the last row — the last lap on
    /// the watch — is the most recent entry and seeds the next block.
    func save() {
        settle()
        guard canSave else { return }
        let now = Date.now
        for (index, row) in rows.enumerated() {
            context.insert(Entry(
                duration: Int(row.value(.duration) ?? 0),
                intensity: row.value(.intensity) ?? 0,
                incline: unit == .speed ? row.value(.incline) ?? 0 : 0,
                averageHeartRate: Int(row.value(.averageHeartRate) ?? 0),
                peakHeartRate: Int(row.value(.peakHeartRate) ?? 0),
                date: now.addingTimeInterval(Double(index - (rows.count - 1))),
                exercise: erg,
                machine: machine
            ))
        }
        // Once per Save, not once per row: one block is one visit (SPEC §13.7).
        caption.logged()
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onSave()
    }
}
