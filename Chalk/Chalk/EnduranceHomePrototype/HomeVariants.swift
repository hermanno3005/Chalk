import SwiftUI

// PROTOTYPE — four answers to "how do you get from strength to endurance on the home
// screen?" (#96). Strength is the real `LibraryView` in every one; endurance is the stub,
// identical in every one. Only the way between them changes.

enum HomeVariant: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var name: String {
        switch self {
        case .a: "Segmented control"
        case .b: "Tab bar"
        case .c: "Title menu"
        case .d: "One library"
        }
    }
}

/// **A — a segmented control where the title was.** Always visible, one tap, and the
/// clearest statement that there are exactly two halves. Costs the "Chalk" title.
struct SegmentedHome: View {
    let store: ProtoStore
    @Binding var half: Half

    var body: some View {
        let picker = AnyView(
            Picker("Half", selection: $half) {
                ForEach(Half.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        )
        switch half {
        case .strength:
            LibraryView(
                model: store.strength,
                hooks: LibraryPrototypeHooks(principal: picker, overflowExtras: AnyView(SettingsRow()))
            )
        case .endurance:
            EnduranceLibraryStub(ergs: store.ergs, gyms: store.strength.gyms, principal: picker)
        }
    }
}

/// **B — a tab bar.** The platform's own answer for two top-level places, and each tab
/// keeps its own navigation stack, so leaving a detail screen open on one side and coming
/// back finds it still there. Costs a bar at the bottom, right where the search field
/// lives.
struct TabHome: View {
    let store: ProtoStore
    @Binding var half: Half

    var body: some View {
        TabView(selection: $half) {
            Tab(Half.strength.rawValue, systemImage: "dumbbell", value: Half.strength) {
                LibraryView(
                    model: store.strength,
                    hooks: LibraryPrototypeHooks(overflowExtras: AnyView(SettingsRow()))
                )
            }
            Tab(Half.endurance.rawValue, systemImage: "figure.indoor.cycle", value: Half.endurance) {
                EnduranceLibraryStub(ergs: store.ergs, gyms: store.strength.gyms)
            }
        }
    }
}

/// **C — the title is a menu.** `Strength ⌄` in the nav bar; tap it to switch. No new
/// chrome at all — the cost is two taps and a switch you have to know is there. Fits a
/// dev who trains the halves on separate days and switches about once per visit.
struct TitleMenuHome: View {
    let store: ProtoStore
    @Binding var half: Half

    var body: some View {
        let menu = AnyView(
            ForEach(Half.allCases, id: \.self) { option in
                Button {
                    half = option
                } label: {
                    if option == half {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        )
        switch half {
        case .strength:
            LibraryView(
                model: store.strength,
                hooks: LibraryPrototypeHooks(
                    title: Half.strength.rawValue,
                    titleMenu: menu,
                    overflowExtras: AnyView(SettingsRow())
                )
            )
        case .endurance:
            EnduranceLibraryStub(
                ergs: store.ergs,
                gyms: store.strength.gyms,
                title: Half.endurance.rawValue,
                titleMenu: menu
            )
        }
    }
}

/// **D — one library, no toggle.** Ergs are a section of the same grid, above the first
/// group; one resume card shows the last thing you did in either half; search finds both.
/// The variant that argues against the charting decision, so it can be judged rather
/// than assumed away.
struct OneLibraryHome: View {
    let store: ProtoStore
    @State private var openedErg: ProtoErg?
    @State private var logging: ProtoErg?

    var body: some View {
        LibraryView(model: store.strength, hooks: hooks)
            .sheet(item: $openedErg) { erg in NavigationStack { ErgDetailStub(erg: erg) } }
            .sheet(item: $logging) { LogIntervalStub(erg: $0) }
    }

    private var hooks: LibraryPrototypeHooks {
        var hooks = LibraryPrototypeHooks(overflowExtras: AnyView(SettingsRow()))
        hooks.searchPrompt = "Search or add"
        if store.ergWasLast, let erg = store.ergs.first, let interval = erg.last {
            hooks.resumeOverride = AnyView(
                ErgResumeCard(erg: erg, interval: interval, onOpen: { openedErg = erg }) { logging = erg }
            )
        }
        if !store.ergs.isEmpty {
            hooks.leadingSections = AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ergs").font(.footnote.weight(.semibold))
                        Spacer()
                        Text("\(store.ergs.count)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    ErgGrid(ergs: store.ergs) { openedErg = $0 }
                }
            )
        }
        let ergs = store.ergs
        hooks.extraResults = { query in
            AnyView(
                ForEach(ergs.filter { $0.name.localizedCaseInsensitiveContains(query) }) { erg in
                    Button {
                        openedErg = erg
                    } label: {
                        HStack {
                            Text(erg.name).foregroundStyle(.primary)
                            Spacer()
                            Text("erg").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            )
        }
        return hooks
    }
}
