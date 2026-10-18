import SwiftUI

// PROTOTYPE — three log sheets for one endurance entry (#97). They disagree about
// structure: A keeps §6's one giant number per stage, B makes the written form itself the
// editor with a keypad that never leaves, and C is a grid shaped like the watch's lap list,
// so a whole block is typed in one sheet. Each still writes **one entry per interval** —
// C's rows are entries, not a session, and nothing groups them once saved.

enum LogVariant: String, CaseIterable {
    case a = "A", b = "B", c = "C"

    var name: String {
        switch self {
        case .a: return "Staged"
        case .b: return "Sentence"
        case .c: return "Lap list"
        }
    }
}

/// How a screenshot opens the prototype: launch arguments, not taps.
struct ProtoStart {
    var autoOpen = false
    var focus: ProtoField?
    var keypad = false
    var prefill = 0

    static func fromDefaults() -> ProtoStart {
        let defaults = UserDefaults.standard
        return ProtoStart(
            autoOpen: defaults.bool(forKey: "prototype.autoOpen"),
            focus: defaults.string(forKey: "prototype.focus").flatMap(ProtoField.init(rawValue:)),
            keypad: defaults.bool(forKey: "prototype.keypad"),
            prefill: defaults.integer(forKey: "prototype.prefill")
        )
    }
}

struct ProtoSheetConfig {
    let erg: ProtoLogErg
    let verdict: ProtoVerdictMode
    /// The *after Save* pill: §6.7 closes the sheet; logging after the block may want it
    /// to stay open, reseeded from what was just saved. A and B only — C is a batch.
    let staysOpen: Bool
    let tally: ProtoTally
    let start: ProtoStart

    /// Seeded from your most recent entry on this erg (or machine), as §6.3 seeds reps.
    var seed: ProtoValues { tally.saved.last?.values ?? erg.last }
}

// MARK: - Shared pieces

/// §6.4's caption, unchanged: gym-bound only, both stages, tappable. A stub menu here.
struct ProtoCaption: View {
    let machine: String?

    var body: some View {
        if let machine {
            Menu {
                Button(machine) {}
                Button("New machine here", systemImage: "plus") {}
                Button("New gym…", systemImage: "building.2") {}
            } label: {
                Label(machine, systemImage: "square.stack.3d.up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.vertical, 6)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

/// The verdict line's slot, also where an impossible entry says why Save is off. The
/// space is reserved whether or not anything shows, so nothing above it moves.
struct ProtoStatusLine: View {
    let values: ProtoValues
    let config: ProtoSheetConfig

    var body: some View {
        Group {
            if let problem = ProtoCheck.problem(values) {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Text(ProtoCheck.verdict(values, config.erg, config.verdict) ?? " ")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 22)
    }
}

/// The app's keypad, with every press counted.
struct ProtoKeypad: View {
    let decimalIsDead: Bool
    let tally: ProtoTally
    let onKey: (TwoStageNumber.Key) -> Void

    var body: some View {
        NumberKeypad(decimalIsDead: decimalIsDead) { key in
            tally.tap()
            withAnimation(.snappy(duration: 0.15)) { onKey(key) }
        }
    }
}

struct SavedCounter: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Label("\(count) logged", systemImage: "checkmark")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - A — Staged

/// §6 borrowed whole: **one giant number per stage**, steppers for nudges and the keypad
/// a tap on the number away. Five stages on a treadmill, four elsewhere. Every earlier
/// answer rides in the header as a capsule, as `N reps` does, one tap from correction.
struct StagedSheet: View {
    let config: ProtoSheetConfig
    @State private var editor: ProtoEditor
    @State private var savedHere = 0
    @Environment(\.dismiss) private var dismiss

    init(config: ProtoSheetConfig) {
        self.config = config
        var editor = ProtoEditor(erg: config.erg, seed: config.seed, focus: config.start.focus)
        if config.start.keypad { editor.toggleKeypad() }
        _editor = State(initialValue: editor)
    }

    private var unit: ProtoUnit { config.erg.unit }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                crumbs
                Spacer(minLength: 0)
                ProtoCaption(machine: config.erg.machine)
                Text(ProtoText.name(editor.focus, unit))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                giant
                subline
                Spacer(minLength: 0)
                input
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(config.erg.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if editor.isLast {
                        Button("Save", action: save)
                            .fontWeight(.semibold)
                            .disabled(!ProtoCheck.canSave(editor.values, config.erg))
                    } else {
                        Button("Next", action: next)
                            .disabled(editor.values[editor.focus] == nil)
                    }
                }
            }
        }
    }

    /// Every earlier answer, tappable — `N reps`, generalised to four of them.
    private var crumbs: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(earlier, id: \.self) { field in
                        Button {
                            config.tally.tap()
                            withAnimation(.snappy) { editor.focus(on: field) }
                        } label: {
                            Text(crumb(field))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
            SavedCounter(count: savedHere)
        }
        .frame(height: 44)
    }

    private var earlier: [ProtoField] {
        Array(config.erg.fields.prefix { $0 != editor.focus })
    }

    private func crumb(_ field: ProtoField) -> String {
        let number = editor.text(field)
        switch field {
        case .duration: return number
        case .average: return "\(number) avg"
        case .peak: return "\(number) peak"
        case .intensity where unit == .level: return "Level \(number)"
        default: return "\(number) \(ProtoText.unit(field, unit))"
        }
    }

    private var giant: some View {
        Button {
            config.tally.tap()
            withAnimation(.snappy) { editor.toggleKeypad() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(editor.text(editor.focus))
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(ProtoText.unit(editor.focus, unit))
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// A speed's pace under it; on the heart-rate stages, the verdict. Silent elsewhere,
    /// as §6.5 keeps stage one silent.
    @ViewBuilder
    private var subline: some View {
        switch editor.focus {
        case .intensity where unit == .speed:
            Text(editor.values[.intensity].map { $0 > 0 ? ProtoText.pace($0) : " " } ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 22)
        case .average, .peak:
            ProtoStatusLine(values: editor.values, config: config)
        default:
            Text(" ").font(.subheadline).frame(minHeight: 22)
        }
    }

    @ViewBuilder
    private var input: some View {
        if editor.isTyping {
            ProtoKeypad(decimalIsDead: editor.decimalIsDead, tally: config.tally) { editor.type($0) }
        } else {
            HStack(spacing: 16) {
                stepper(-1, "minus")
                stepper(+1, "plus")
            }
        }
    }

    private func stepper(_ direction: Int, _ symbol: String) -> some View {
        Button {
            config.tally.tap()
            withAnimation(.snappy) { editor.step(direction) }
        } label: {
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    /// A blank stage opens with the keypad already up (§6.3).
    private func next() {
        config.tally.tap()
        withAnimation(.snappy) {
            editor.next()
            if editor.values[editor.focus] == nil { editor.toggleKeypad() }
        }
    }

    private func save() {
        config.tally.tap()
        editor.settle()
        config.tally.saved.append(.init(values: editor.values))
        if config.staysOpen {
            withAnimation(.snappy) {
                savedHere += 1
                editor = ProtoEditor(erg: config.erg, seed: editor.values)
            }
        } else {
            dismiss()
        }
    }
}

// MARK: - B — Sentence

/// **The written form is the editor.** `6:00 at 15.0 km/h · 1 % · 168/174 bpm`, every
/// number a tappable field, the focused one marked, and one keypad that never leaves.
/// Typing replaces the focused number; a heart rate's last digit and a speed's tenth move
/// on by themselves, and *Next* skips a seed that is already right.
struct SentenceSheet: View {
    let config: ProtoSheetConfig
    @State private var editor: ProtoEditor
    @State private var savedHere = 0
    @Environment(\.dismiss) private var dismiss

    init(config: ProtoSheetConfig) {
        self.config = config
        _editor = State(initialValue: ProtoEditor(erg: config.erg, seed: config.seed, focus: config.start.focus))
    }

    private var unit: ProtoUnit { config.erg.unit }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    ProtoCaption(machine: config.erg.machine)
                    Spacer(minLength: 0)
                    SavedCounter(count: savedHere)
                }
                .frame(height: 36)
                Spacer(minLength: 0)
                sentence
                Spacer(minLength: 0)
                ProtoStatusLine(values: editor.values, config: config)
                    .padding(.bottom, 10)
                HStack {
                    Text(ProtoText.name(editor.focus, unit))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        config.tally.tap()
                        withAnimation(.snappy(duration: 0.15)) { editor.next() }
                    } label: {
                        Label("Next", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .disabled(editor.isLast)
                }
                .padding(.bottom, 8)
                ProtoKeypad(decimalIsDead: editor.decimalIsDead, tally: config.tally) { key in
                    if editor.type(key), !editor.isLast { editor.next() }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(config.erg.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!ProtoCheck.canSave(editor.values, config.erg))
                }
            }
        }
    }

    private var sentence: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                token(.duration)
                word("at")
                if unit == .level { word("Level") }
                token(.intensity)
                if unit != .level { word(ProtoText.unit(.intensity, unit)) }
            }
            if unit == .speed {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    word(editor.values[.intensity].map { $0 > 0 ? "\(ProtoText.pace($0)) ·" : "·" } ?? "·")
                    token(.incline)
                    word("% incline")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                token(.average)
                word("/")
                token(.peak)
                word("bpm")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func token(_ field: ProtoField) -> some View {
        let focused = editor.focus == field
        let text = editor.text(field)
        return Button {
            config.tally.tap()
            withAnimation(.snappy(duration: 0.15)) { editor.focus(on: field) }
        } label: {
            Text(text.isEmpty ? "–" : text)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(focused ? Color.accentColor.opacity(0.16) : Color.clear)
                )
                .overlay(alignment: .bottom) {
                    if focused {
                        Capsule().fill(Color.accentColor).frame(height: 3).padding(.horizontal, 6)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func word(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    private func save() {
        config.tally.tap()
        editor.settle()
        config.tally.saved.append(.init(values: editor.values))
        if config.staysOpen {
            withAnimation(.snappy) {
                savedHere += 1
                editor = ProtoEditor(erg: config.erg, seed: editor.values)
            }
        } else {
            dismiss()
        }
    }
}

// MARK: - C — Lap list

/// **A grid shaped like the watch's lap list**: one row per entry, columns in the watch's
/// order, a new row seeded from the one above, one keypad. You type the block top to
/// bottom, the way you read it off the wrist, and Save writes one entry per row.
struct LapListSheet: View {
    let config: ProtoSheetConfig
    @State private var rows: [ProtoEditor]
    @State private var current: Int
    @Environment(\.dismiss) private var dismiss

    init(config: ProtoSheetConfig) {
        self.config = config
        let erg = config.erg
        var rows: [ProtoEditor]
        if config.start.prefill > 0 {
            rows = erg.laps.compactMap(\.entry).prefix(config.start.prefill).map {
                ProtoEditor(erg: erg, seed: $0)
            }
        } else {
            rows = [ProtoEditor(erg: erg, seed: config.seed)]
        }
        let current = rows.count - 1
        if let focus = config.start.focus { rows[current].focus(on: focus) }
        _rows = State(initialValue: rows)
        _current = State(initialValue: current)
    }

    private var erg: ProtoLogErg { config.erg }
    private var allValid: Bool { rows.allSatisfy { ProtoCheck.canSave($0.values, erg) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProtoCaption(machine: erg.machine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollViewReader { proxy in
                    ScrollView {
                        grid
                        Button {
                            config.tally.tap()
                            withAnimation(.snappy) { addRow() }
                        } label: {
                            Label("Add an entry", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 6)
                        .id("add")
                    }
                    .onChange(of: rows.count) { proxy.scrollTo("add") }
                }
                ProtoStatusLine(values: rows[current].values, config: config)
                    .padding(.vertical, 8)
                HStack {
                    Text("Row \(current + 1) · \(ProtoText.name(rows[current].focus, erg.unit))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        config.tally.tap()
                        withAnimation(.snappy(duration: 0.15)) { next() }
                    } label: {
                        Label(atEnd ? "New row" : "Next", systemImage: atEnd ? "return" : "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .padding(.bottom, 8)
                ProtoKeypad(decimalIsDead: rows[current].decimalIsDead, tally: config.tally) { key in
                    if rows[current].type(key), !rows[current].isLast { rows[current].next() }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(erg.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(rows.count == 1 ? "Save" : "Save \(rows.count)", action: save)
                        .fontWeight(.semibold)
                        .disabled(!allValid)
                }
            }
        }
    }

    private var atEnd: Bool { rows[current].isLast && current == rows.count - 1 }

    private var grid: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 6) {
            GridRow {
                ForEach(erg.fields, id: \.self) { field in
                    Text(ProtoText.column(field, erg.unit))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(" ").font(.caption)
            }
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(erg.fields, id: \.self) { field in
                        cell(index, field)
                    }
                    badge(index)
                        .frame(width: 34)
                }
                .contextMenu {
                    if rows.count > 1 {
                        Button("Delete This Entry", systemImage: "trash", role: .destructive) {
                            withAnimation { delete(index) }
                        }
                    }
                }
            }
        }
    }

    private func cell(_ index: Int, _ field: ProtoField) -> some View {
        let focused = index == current && rows[index].focus == field
        let text = rows[index].text(field)
        return Button {
            config.tally.tap()
            withAnimation(.snappy(duration: 0.15)) {
                rows[current].settle()
                current = index
                rows[index].focus(on: field)
            }
        } label: {
            Text(text.isEmpty ? "–" : text)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(focused ? Color.accentColor.opacity(0.2) : Color(.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(focused ? Color.accentColor : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    /// The zone the row's average lands in, or why it cannot be saved.
    @ViewBuilder
    private func badge(_ index: Int) -> some View {
        let values = rows[index].values
        if ProtoCheck.problem(values) != nil {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        } else if config.verdict != .none, let average = values[.average], (40...230).contains(average) {
            Text("Z\(ProtoZones.zone(average))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            Text(" ")
        }
    }

    private func next() {
        if !rows[current].next() {
            if current == rows.count - 1 {
                addRow()
            } else {
                current += 1
                rows[current].focus(on: .duration)
            }
        }
    }

    private func addRow() {
        rows[current].settle()
        rows.append(ProtoEditor(erg: erg, seed: rows[rows.count - 1].values))
        current = rows.count - 1
    }

    private func delete(_ index: Int) {
        rows.remove(at: index)
        current = min(current, rows.count - 1)
    }

    private func save() {
        config.tally.tap()
        rows[current].settle()
        for row in rows { config.tally.saved.append(.init(values: row.values)) }
        dismiss()
    }
}
