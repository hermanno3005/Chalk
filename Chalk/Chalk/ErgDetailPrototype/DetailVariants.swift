import SwiftUI

// PROTOTYPE — three erg detail screens (#98), each given the same scope's zone lines.
//
// A — One zone:   strength's screen, transplanted. Pick a zone; one line; a scrub readout.
// B — Every zone: all five lines at once; scrub a duration, read every zone at it.
// C — Table:      no chart. Durations down, zones across, the numbers themselves.

enum DetailVariant: String, CaseIterable {
    case a = "A", b = "B", c = "C"

    var name: String {
        switch self {
        case .a: "One zone"
        case .b: "Every zone"
        case .c: "Table"
        }
    }
}

struct ProtoContext {
    let erg: ProtoErg
    let scope: ProtoScope
    let axis: ProtoAxis
    let ghost: Bool
    /// From `-prototype.zone`, so a screenshot can open on a zone with no line.
    let startZone: Int?
}

// MARK: - Shared pieces

/// The incline the lines are read at — speed ergs only. Entries at different inclines never
/// answer each other's question, so this is to the lookup what reps are to the curve.
struct InclineMenu: View {
    let inclines: [Double]
    @Binding var incline: Double

    var body: some View {
        Menu {
            Picker("Incline", selection: $incline) {
                ForEach(inclines, id: \.self) { Text(ProtoFormat.incline($0)).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                Text(ProtoFormat.incline(incline))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
    }
}

/// The big number: one intensity, with a speed's pace beside it.
struct BigIntensity: View {
    let value: Double
    let unit: ProtoUnit
    var size: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if unit == .level {
                    Text("Level").font(.title3).foregroundStyle(.secondary)
                }
                Text(ProtoFormat.value(value, unit))
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if unit != .level {
                    Text(ProtoFormat.unitLabel(unit)).font(.title3).foregroundStyle(.secondary)
                }
            }
            if let pace = ProtoFormat.secondary(value, unit) {
                Text(pace)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

struct ZoneTag: View {
    let zone: Int
    var dimmed = false

    var body: some View {
        Text("Z\(zone)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ProtoZones.color(zone).opacity(dimmed ? 0.3 : 1), in: RoundedRectangle(cornerRadius: 4))
    }
}

private func entries(_ n: Int) -> String { n == 1 ? "1 entry" : "\(n) entries" }

private func nearest(_ seconds: Int, in options: [Int]) -> Int {
    options.min { abs($0 - seconds) < abs($1 - seconds) } ?? seconds
}

// MARK: - A — One zone

struct OneZoneVariant: View {
    let ctx: ProtoContext
    @State private var zone: Int
    @State private var seconds: Int
    @State private var incline: Double

    init(ctx: ProtoContext) {
        self.ctx = ctx
        _zone = State(initialValue: ctx.startZone ?? ctx.scope.last.zone)
        _seconds = State(initialValue: ctx.scope.last.seconds)
        _incline = State(initialValue: ctx.scope.last.incline)
    }

    private var line: [ProtoPoint] { ctx.scope.line(zone: zone, incline: incline) }
    private var point: ProtoPoint? { line.first { $0.seconds == seconds } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { z in
                    let has = !ctx.scope.line(zone: z, incline: incline).isEmpty
                    Button {
                        zone = z
                    } label: {
                        Text("Z\(z)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 32)
                            .foregroundStyle(z == zone ? Color.white : has ? Color.primary : Color.secondary.opacity(0.4))
                            .background(
                                z == zone ? Color.accentColor : Color.secondary.opacity(has ? 0.14 : 0.05),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if ctx.erg.unit == .speed {
                    InclineMenu(inclines: ctx.scope.inclines, incline: $incline)
                }
            }

            if let point {
                VStack(alignment: .leading, spacing: 6) {
                    BigIntensity(value: point.value, unit: ctx.erg.unit)
                    Text("\(ProtoFormat.duration(seconds)) in Z\(zone) · \(point.hr) bpm · \(entries(point.count)) ›")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ZoneChart(
                    lines: [ProtoLine(zone: zone, points: line, color: .accentColor)],
                    unit: ctx.erg.unit,
                    axis: ctx.axis,
                    ghost: ctx.ghost,
                    selectedSeconds: seconds,
                    selectable: line.map(\.seconds),
                    onSelect: { seconds = $0 }
                )
            } else {
                emptyZone
            }
        }
        .animation(.snappy, value: seconds)
        .onChange(of: zone) { snap() }
        .onChange(of: incline) { snap() }
    }

    private func snap() {
        guard !line.isEmpty else { return }
        seconds = nearest(seconds, in: line.map(\.seconds))
    }

    /// A zone you have never landed in here: no line, and the zones either side of it,
    /// so a first visit that only reached Z5 still says which way to go.
    private var emptyZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No Z\(zone) on this \(ctx.erg.machine == nil ? "erg" : "machine") yet.")
                .font(.title3.weight(.medium))
            Text("Nothing you've logged here averaged \(ProtoZones.range(zone)).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(neighbours, id: \.zone) { n in
                HStack(spacing: 6) {
                    ZoneTag(zone: n.zone)
                    Text("\(ProtoFormat.duration(n.point.seconds)) at \(ProtoFormat.full(n.point.value, ctx.erg.unit)) — \(n.zone > zone ? "too hard" : "too easy")")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private var neighbours: [(zone: Int, point: ProtoPoint)] {
        let above = ((zone + 1)...max(zone + 1, 5)).lazy.filter { $0 <= 5 }
            .compactMap { z in self.pick(z).map { (z, $0) } }.first
        let below = stride(from: zone - 1, through: 1, by: -1).lazy
            .compactMap { z in self.pick(z).map { (z, $0) } }.first
        return [above, below].compactMap { $0 }.map { (zone: $0.0, point: $0.1) }
    }

    private func pick(_ z: Int) -> ProtoPoint? {
        let l = ctx.scope.line(zone: z, incline: incline)
        return l.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) }
    }
}

// MARK: - B — Every zone

struct EveryZoneVariant: View {
    let ctx: ProtoContext
    @State private var seconds: Int
    @State private var incline: Double

    init(ctx: ProtoContext) {
        self.ctx = ctx
        _seconds = State(initialValue: ctx.scope.last.seconds)
        _incline = State(initialValue: ctx.scope.last.incline)
    }

    private var lines: [ProtoLine] {
        (1...5).compactMap { z in
            let points = ctx.scope.line(zone: z, incline: incline)
            return points.isEmpty ? nil : ProtoLine(zone: z, points: points, color: ProtoZones.color(z))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(ProtoFormat.duration(seconds))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("intervals").font(.title3).foregroundStyle(.secondary)
                Spacer()
                if ctx.erg.unit == .speed {
                    InclineMenu(inclines: ctx.scope.inclines, incline: $incline)
                }
            }

            ZoneChart(
                lines: lines,
                unit: ctx.erg.unit,
                axis: ctx.axis,
                ghost: ctx.ghost,
                selectedSeconds: seconds,
                selectable: ctx.scope.durations(incline: incline),
                onSelect: { seconds = $0 },
                height: 200,
                endLabels: true
            )

            VStack(spacing: 0) {
                ForEach(lines.reversed()) { line in
                    row(line)
                    Divider()
                }
            }
        }
        .animation(.snappy, value: seconds)
        .onChange(of: incline) {
            seconds = nearest(seconds, in: ctx.scope.durations(incline: incline))
        }
    }

    private func row(_ line: ProtoLine) -> some View {
        let point = line.points.first { $0.seconds == seconds }
        return HStack(spacing: 10) {
            ZoneTag(zone: line.zone, dimmed: point == nil)
            if let point {
                Text(ProtoFormat.full(point.value, ctx.erg.unit))
                    .font(.title3.weight(.semibold))
                if let pace = ProtoFormat.secondary(point.value, ctx.erg.unit) {
                    Text(pace).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(point.hr) bpm · \(point.count) ›")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .monospacedDigit()
        .padding(.vertical, 8)
    }
}

// MARK: - C — Table

struct TableVariant: View {
    let ctx: ProtoContext
    @State private var zone: Int
    @State private var seconds: Int
    @State private var incline: Double

    init(ctx: ProtoContext) {
        self.ctx = ctx
        _zone = State(initialValue: ctx.scope.last.zone)
        _seconds = State(initialValue: ctx.scope.last.seconds)
        _incline = State(initialValue: ctx.scope.last.incline)
    }

    private var durations: [Int] { ctx.scope.durations(incline: incline) }

    private func point(_ z: Int, _ s: Int) -> ProtoPoint? {
        ctx.scope.line(zone: z, incline: incline).first { $0.seconds == s }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                if let p = point(zone, seconds) {
                    VStack(alignment: .leading, spacing: 6) {
                        BigIntensity(value: p.value, unit: ctx.erg.unit, size: 44)
                        Text("\(ProtoFormat.duration(seconds)) in Z\(zone) · \(p.hr) bpm · \(entries(p.count)) ›")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                if ctx.erg.unit == .speed {
                    InclineMenu(inclines: ctx.scope.inclines, incline: $incline)
                }
            }

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Color.clear.frame(width: 1, height: 1)
                    ForEach(1...5, id: \.self) { z in
                        Text("Z\(z)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ProtoZones.color(z))
                    }
                }
                ForEach(durations, id: \.self) { s in
                    GridRow {
                        Text(ProtoFormat.duration(s))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                        ForEach(1...5, id: \.self) { z in cell(z, s) }
                    }
                }
            }
        }
        .onChange(of: incline) {
            if let first = durations.first(where: { s in (1...5).contains { point($0, s) != nil } }) {
                seconds = first
                zone = (1...5).reversed().first { point($0, first) != nil } ?? zone
            }
        }
    }

    @ViewBuilder
    private func cell(_ z: Int, _ s: Int) -> some View {
        let selected = z == zone && s == seconds
        if let p = point(z, s) {
            Button {
                zone = z
                seconds = s
            } label: {
                Text(ProtoFormat.value(p.value, ctx.erg.unit))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(selected ? .white : .primary)
                    .background(
                        selected ? ProtoZones.color(z) : ProtoZones.color(z).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .buttonStyle(.plain)
        } else {
            Text("·")
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }
}
