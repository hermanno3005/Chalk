import Foundation

/// How VoiceOver says the counts and durations Chalk writes as symbols (SPEC §15.6).
enum Spoken {
    /// `1 rep`, `5 reps`.
    static func reps(_ reps: Int) -> String {
        reps == 1 ? "1 rep" : "\(reps) reps"
    }

    /// A duration in words, where Chalk writes `m:ss`: `6 minutes`, `1 minute 30 seconds`,
    /// `1 hour 2 minutes`, `45 seconds`.
    static func duration(_ seconds: Int) -> String {
        let units: [(count: Int, noun: String)] = [
            (seconds / 3600, "hour"),
            ((seconds % 3600) / 60, "minute"),
            (seconds % 60, "second"),
        ]
        let parts = units.filter { $0.count > 0 }.map { count($0.count, $0.noun) }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }

    /// `1 minute`, `2 minutes`, `1 entry`, `12 entries`.
    static func count(_ count: Int, _ noun: String) -> String {
        if count == 1 { return "1 \(noun)" }
        return noun.hasSuffix("y") ? "\(count) \(noun.dropLast())ies" : "\(count) \(noun)s"
    }

    /// `164 beats per minute`.
    static func heartRate(_ bpm: Int) -> String {
        "\(bpm) beats per minute"
    }

    /// `1 percent incline`, `1.5 percent incline`.
    static func incline(_ incline: Double) -> String {
        "\(EnduranceText.incline(incline)) percent incline"
    }
}
