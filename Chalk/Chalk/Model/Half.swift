import Foundation

/// Which half of Chalk something belongs to: strength, for lifting, or endurance, for
/// indoor ergs.
///
/// Stored on `ExerciseGroup.half` as its `rawValue`, as `kind` is (ADR-0001). An
/// exercise or erg needs no field of its own — its half is whether it has a unit
/// (ADR-0008).
enum Half: String, Codable, CaseIterable {
    case strength
    case endurance
}
