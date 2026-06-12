import SwiftUI

func formatTimeFromSeconds(totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

func formatToHHMMSS(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

/// Shared rest-timer duration options and formatting, used by the Settings
/// preference picker and the per-exercise rest override chips.
enum RestDuration {
    static let options = [15, 30, 45, 60, 90, 120, 180, 240, 300]

    /// Long form, e.g. "45 seconds", "1m 30s", "3 minutes".
    static func format(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes) minute\(minutes == 1 ? "" : "s")"
            }
        } else {
            return "\(seconds) seconds"
        }
    }

    /// Compact form for chips, e.g. "45s", "1:30", "3min".
    static func formatShort(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes):\(String(format: "%02d", remainingSeconds))"
            } else {
                return "\(minutes)min"
            }
        } else {
            return "\(seconds)s"
        }
    }
}

func convertToSeconds(_ input: String) -> Int {
    let paddedInput = String(repeating: "0", count: max(0, 6 - input.count)) + input
    let hours = Int(paddedInput.prefix(2)) ?? 0
    let minutes = Int(paddedInput.dropFirst(2).prefix(2)) ?? 0
    let seconds = Int(paddedInput.suffix(2)) ?? 0
    return hours * 3600 + minutes * 60 + seconds
}
