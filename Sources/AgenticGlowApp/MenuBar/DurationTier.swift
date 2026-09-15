/// Shared seconds -> (unit, value, remainder) decomposition so the row
/// timer, the menu bar timer, and the detail panel's "last updated" text
/// agree on tier boundaries (60s, 3600s) even though each renders its own
/// string style.
enum DurationTier {
    case seconds(Int)
    case minutes(Int, remainderSeconds: Int)
    case hours(Int, remainderMinutes: Int)

    init(seconds: Int) {
        let seconds = max(0, seconds)
        if seconds < 60 {
            self = .seconds(seconds)
        } else if seconds < 3_600 {
            self = .minutes(seconds / 60, remainderSeconds: seconds % 60)
        } else {
            self = .hours(seconds / 3_600, remainderMinutes: (seconds % 3_600) / 60)
        }
    }
}
