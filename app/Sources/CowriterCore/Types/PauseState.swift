import Foundation

/// Whether suggestions are currently active, and if paused, until when.
public enum PauseState: Equatable, Sendable {
    case active
    case pausedUntil(Date)
    case pausedIndefinitely

    /// Standard pause durations offered in the menu.
    public enum Duration: CaseIterable, Sendable {
        case thirtyMinutes
        case oneHour
        case untilTomorrow
        case indefinitely

        public var displayName: String {
            switch self {
            case .thirtyMinutes: return "Pause for 30 minutes"
            case .oneHour: return "Pause for 1 hour"
            case .untilTomorrow: return "Pause until tomorrow"
            case .indefinitely: return "Pause indefinitely"
            }
        }
    }

    /// Resolve whether suggestions are active as of `now`. Expired pauses become active.
    public func isActive(now: Date) -> Bool {
        switch self {
        case .active: return true
        case .pausedIndefinitely: return false
        case .pausedUntil(let until): return now >= until
        }
    }

    /// Build a pause state from a chosen duration, relative to `now`.
    /// `calendar` is injectable so "until tomorrow" is testable deterministically.
    public static func from(
        _ duration: Duration,
        now: Date,
        calendar: Calendar = .current
    ) -> PauseState {
        switch duration {
        case .thirtyMinutes:
            return .pausedUntil(now.addingTimeInterval(30 * 60))
        case .oneHour:
            return .pausedUntil(now.addingTimeInterval(60 * 60))
        case .untilTomorrow:
            let startOfTomorrow = calendar.startOfDay(
                for: now.addingTimeInterval(24 * 60 * 60)
            )
            return .pausedUntil(startOfTomorrow)
        case .indefinitely:
            return .pausedIndefinitely
        }
    }
}
