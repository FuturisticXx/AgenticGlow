import Foundation

/// Small, pure formatting helpers for widget copy. Deliberately separate
/// from the app target's AllowancePresentation/StatusPresentation (which
/// are AppKit/SwiftUI app-only and not importable from an extension), but
/// follows the same conventions: exact seconds under one minute, absolute
/// clock time alongside relative countdowns.
public enum WidgetSnapshotFormatting {
    public static func percentLeftLabel(_ percent: Double?) -> String {
        guard let percent else { return "Unavailable" }
        return "\(Int(percent.rounded()))% left"
    }

    public static func elapsedLabel(seconds: Int?) -> String? {
        guard let seconds, seconds >= 0 else { return nil }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
    }

    public static func relativeResetLabel(_ resetAt: Date?, now: Date) -> String? {
        guard let resetAt else { return nil }
        let interval = resetAt.timeIntervalSince(now)
        guard interval > 0 else { return "Resetting" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(max(minutes, 1))m left" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h left" : "\(hours)h \(remainingMinutes)m left"
    }

    public static func absoluteResetLabel(_ resetAt: Date?, now: Date, calendar: Calendar = .current) -> String? {
        guard let resetAt else { return nil }
        let style: Date.FormatStyle = calendar.isDate(resetAt, inSameDayAs: now)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return resetAt.formatted(style)
    }

    public static func lastUpdatedLabel(_ date: Date, now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 60 { return "Just now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}
