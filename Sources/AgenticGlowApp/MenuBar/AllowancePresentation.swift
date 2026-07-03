import Foundation
import AgenticGlowCore

struct AllowancePresentation {
    let currentValue: String
    let currentDetail: String
    let weeklyValue: String
    let currentProgress: Double
    let weeklyProgress: Double?
    let accessibilityCurrent: String
    let accessibilityWeekly: String?

    init(allowance: ProviderAllowance, now: Date) {
        let currentLeft = allowance.currentPercentLeft.map(Self.percent) ?? "Unavailable"
        let currentUsed = allowance.currentPercentUsed.map(Self.percent)
        if allowance.provider == .claude, let currentUsed {
            currentValue = "\(currentLeft)% left · \(currentUsed)% used"
        } else {
            currentValue = "\(currentLeft)% left"
        }
        currentDetail = [
            allowance.currentWindowLabel,
            allowance.currentResetAt.map { Self.relativeReset($0, now: now) }
        ].compactMap { $0 }.joined(separator: " · ")
        currentProgress = (allowance.currentPercentLeft ?? 0) / 100

        if let weeklyLeft = allowance.weeklyPercentLeft {
            var parts = ["Week \(Self.percent(weeklyLeft))%"]
            if allowance.provider == .claude, let used = allowance.weeklyPercentUsed {
                parts[0] += " · \(Self.percent(used))% used"
            }
            if let reset = allowance.weeklyResetAt {
                parts.append(Self.weeklyReset(reset))
            }
            weeklyValue = parts.joined(separator: " · ")
            weeklyProgress = weeklyLeft / 100
        } else {
            weeklyValue = "Week unavailable"
            weeklyProgress = nil
        }

        accessibilityCurrent = Self.spoken(
            provider: allowance.provider,
            window: allowance.currentWindowLabel,
            left: allowance.currentPercentLeft,
            used: allowance.currentPercentUsed,
            reset: allowance.currentResetAt
        )
        accessibilityWeekly = allowance.weeklyPercentLeft.map {
            Self.spoken(
                provider: allowance.provider,
                window: "weekly",
                left: $0,
                used: allowance.weeklyPercentUsed,
                reset: allowance.weeklyResetAt
            )
        }
    }

    private static func percent(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    private static func relativeReset(_ reset: Date, now: Date) -> String {
        let seconds = max(0, Int(reset.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func weeklyReset(_ reset: Date) -> String {
        reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private static func spoken(
        provider: AgentProvider,
        window: String,
        left: Double?,
        used: Double?,
        reset: Date?
    ) -> String {
        var parts = [provider == .codex ? "Codex" : "Claude", window]
        if let left { parts.append("\(percent(left)) percent left") }
        if provider == .claude, let used { parts.append("\(percent(used)) percent used") }
        if let reset {
            parts.append("resets \(reset.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: ", ")
    }
}
