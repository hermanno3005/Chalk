import Foundation

/// How VoiceOver says the counts and durations Chalk writes as symbols (SPEC §15.6).
enum Spoken {
    /// `1 rep`, `5 reps`.
    static func reps(_ reps: Int) -> String {
        String(localized: "\(reps) reps")
    }

    /// A duration in words, where Chalk writes `m:ss`: `6 minutes`, `1 minute 30 seconds`,
    /// `1 hour 2 minutes`, `45 seconds`.
    static func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, rest = seconds % 60
        let parts = [
            hours > 0 ? String(localized: "\(hours) hours") : nil,
            minutes > 0 ? String(localized: "\(minutes) minutes") : nil,
            rest > 0 ? String(localized: "\(rest) seconds") : nil,
        ].compactMap(\.self)
        return parts.isEmpty ? String(localized: "\(seconds) seconds") : parts.joined(separator: " ")
    }

    /// Seconds that may hold a tenth, said as `written` shows them: `1 second`, `45.3
    /// seconds`. The number goes in beside `written` as the one the catalog picks the
    /// noun's plural by, so `1.5` takes the plural that `1` does not.
    static func seconds(_ seconds: Double, written: String) -> String {
        String(localized: "\(written) \(seconds) seconds")
    }

    /// `164 beats per minute`.
    static func heartRate(_ bpm: Int) -> String {
        String(localized: "\(bpm) beats per minute")
    }

    /// `1 percent incline`, `1.5 percent incline`.
    static func incline(_ incline: Double) -> String {
        String(localized: "\(EnduranceText.incline(incline)) percent incline")
    }
}
