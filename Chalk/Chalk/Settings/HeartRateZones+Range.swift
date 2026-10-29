import Foundation

extension HeartRateZones {

    /// A zone's heart rates in words: `below 117 bpm`, `158–169 bpm`, `170+ bpm`. Z1 has no
    /// floor and Z5 no ceiling.
    func range(of zone: Int) -> String {
        switch zone {
        case ...1: "below \(lowerBounds[0]) bpm"
        case 5...: "\(lowerBounds[3])+ bpm"
        default: "\(lowerBounds[zone - 2])–\(lowerBounds[zone - 1] - 1) bpm"
        }
    }

    /// The zone a heart rate falls in, named with its range: `Z4 · 158–169 bpm`.
    func zoneLine(of heartRate: Int) -> String {
        let zone = zone(of: heartRate)
        return "Z\(zone) · \(range(of: zone))"
    }

    /// `range(of:)` as VoiceOver says it: `below 117 beats per minute`, `158 to 169 beats
    /// per minute`, `170 beats per minute and up`.
    func spokenRange(of zone: Int) -> String {
        switch zone {
        case ...1: "below \(Spoken.heartRate(lowerBounds[0]))"
        case 5...: "\(Spoken.heartRate(lowerBounds[3])) and up"
        default: "\(lowerBounds[zone - 2]) to \(Spoken.heartRate(lowerBounds[zone - 1] - 1))"
        }
    }

    /// `zoneLine(of:)` as VoiceOver says it: `Zone 4, 158 to 169 beats per minute`.
    func spokenZoneLine(of heartRate: Int) -> String {
        let zone = zone(of: heartRate)
        return "Zone \(zone), \(spokenRange(of: zone))"
    }
}
