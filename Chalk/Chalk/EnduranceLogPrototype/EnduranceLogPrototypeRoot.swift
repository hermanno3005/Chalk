import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out (#97).
//
// Three log sheets for an endurance entry, switchable from the black bar below the app,
// hosted on a rough erg screen that shows **the block you just ran as your watch's lap
// list shows it**, rests included. The job being judged is transcribing that block after
// it ends, so the bar keeps score: taps and sheet opens it took, and what was written.

struct EnduranceLogPrototypeRoot: View {
    @AppStorage("prototype.variant") private var variant = LogVariant.a.rawValue
    @AppStorage("prototype.erg") private var ergID = ProtoLogErg.treadmill.id
    @AppStorage("prototype.verdict") private var verdict = ProtoVerdictMode.zone.rawValue
    @AppStorage("prototype.staysOpen") private var staysOpen = false
    @State private var tally = ProtoTally()
    private let start = ProtoStart.fromDefaults()

    private var currentVariant: LogVariant { LogVariant(rawValue: variant) ?? .a }
    private var erg: ProtoLogErg { ProtoLogErg.all.first { $0.id == ergID } ?? .treadmill }
    private var verdictMode: ProtoVerdictMode { ProtoVerdictMode(rawValue: verdict) ?? .zone }

    var body: some View {
        VStack(spacing: 0) {
            ErgHostView(
                variant: currentVariant,
                config: ProtoSheetConfig(
                    erg: erg, verdict: verdictMode, staysOpen: staysOpen, tally: tally, start: start
                )
            )
            .id("\(variant)-\(ergID)")
            switcher
        }
        .onChange(of: ergID) { tally.reset() }
        .onChange(of: variant) { tally.reset() }
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(currentVariant.rawValue) — \(currentVariant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 150)
                Button { cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 6) {
                pill(erg.name) {
                    let all = ProtoLogErg.all
                    ergID = all[((all.firstIndex { $0.id == erg.id } ?? 0) + 1) % all.count].id
                }
                pill(verdictMode.rawValue) {
                    let all = ProtoVerdictMode.allCases
                    verdict = all[(all.firstIndex(of: verdictMode)! + 1) % all.count].rawValue
                }
                pill(currentVariant == .c ? "save: batch" : staysOpen ? "save: stays open" : "save: closes") {
                    staysOpen.toggle()
                }
            }
            Text("\(tally.taps) taps · \(tally.opens) opens · \(tally.saved.count) saved")
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func cycleVariant(_ step: Int) {
        let all = LogVariant.allCases
        let index = all.firstIndex(of: currentVariant)!
        variant = all[(index + step + all.count) % all.count].rawValue
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
        }
    }
}

/// A rough erg detail screen — the caller, judged only for what it hands the sheet. The
/// lap list stands in for your wrist; *Logged today* is what each Save actually wrote.
struct ErgHostView: View {
    let variant: LogVariant
    let config: ProtoSheetConfig
    @State private var logging = false

    private var erg: ProtoLogErg { config.erg }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(erg.laps) { lap in
                        HStack(spacing: 10) {
                            Text("Lap \(lap.number)")
                                .foregroundStyle(.secondary)
                                .frame(width: 46, alignment: .leading)
                            Text(lap.time)
                                .frame(width: 48, alignment: .leading)
                            Text("\(lap.average)/\(lap.peak)")
                            Spacer()
                            Text(lap.set)
                                .font(.footnote)
                                .foregroundStyle(lap.entry == nil ? .tertiary : .secondary)
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Prototype · your watch's lap list")
                } footer: {
                    Text("Time, then average/peak, as the watch shows them. What you set is from memory: the watch doesn't know.")
                }
                Section("Logged today") {
                    if config.tally.saved.isEmpty {
                        Text("Nothing yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(config.tally.saved.reversed()) { saved in
                            Text(ProtoText.written(saved.values, erg.unit))
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(erg.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { config.tally.reset() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    config.tally.opens += 1
                    logging = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $logging) {
                switch variant {
                case .a: StagedSheet(config: config)
                case .b: SentenceSheet(config: config)
                case .c: LapListSheet(config: config)
                }
            }
            .onAppear {
                guard config.start.autoOpen else { return }
                config.tally.opens += 1
                logging = true
            }
        }
    }
}
