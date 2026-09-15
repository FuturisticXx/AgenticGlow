import Foundation

/// Detects a weekly allowance window rolling over: the previously known
/// reset time has passed and the provider now reports a later one.
public enum WeeklyResetDetector {
    public static func didReset(
        previous: ProviderAllowance?,
        current: ProviderAllowance,
        now: Date
    ) -> Bool {
        guard
            let previousReset = previous?.weeklyResetAt,
            let currentReset = current.weeklyResetAt
        else { return false }
        return previousReset <= now && currentReset > previousReset
    }
}
