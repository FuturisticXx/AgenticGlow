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

    /// How far out a reset can be before its countdown stops being worth
    /// showing.
    public static let countdownHorizon: TimeInterval = 24 * 60 * 60

    /// Whether a reset is close enough that a relative countdown helps.
    ///
    /// Codex can report its weekly-scale window as the *current* window
    /// (no separate 5-hour window at all), which is how captions like
    /// "Weekly resets in 166h 12m left (Sat, Aug 1 at 2:31 AM)" happened:
    /// a three-digit hour count sitting in front of the calendar date that
    /// already answers the question. Under a day the countdown is the
    /// useful half; past that the date is, so the countdown is dropped.
    ///
    /// Keyed off the actual distance rather than the window kind or a
    /// same-day check: a 5-hour window opened late at night resets
    /// tomorrow and still wants its countdown.
    public static func showsCountdown(_ resetAt: Date?, now: Date) -> Bool {
        guard let resetAt else { return false }
        return resetAt.timeIntervalSince(now) < countdownHorizon
    }

    public static func absoluteResetLabel(_ resetAt: Date?, now: Date, calendar: Calendar = .current) -> String? {
        guard let resetAt else { return nil }
        let style: Date.FormatStyle = calendar.isDate(resetAt, inSameDayAs: now)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return resetAt.formatted(style)
    }

    /// The reset detail a widget caption shows, composed to stay on one
    /// line beside a low-allowance warning icon.
    ///
    /// Two words are dropped against the longer phrasing the popover
    /// uses, and both were redundant rather than informative: "in 3h 27m
    /// left" said the same thing twice, and "Sep 7 at 12:16 AM" spends a
    /// word where a separator reads the same. Nothing semantic goes: the
    /// countdown, the weekday, the date, and the exact time all survive.
    /// Written for the case that truncated on a real desktop widget,
    /// "5h resets in 3h 27m left (Mon, Sep 7 at 12:16 A...".
    public static func captionResetDetail(
        _ resetAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let resetAt else { return nil }
        let absolute = compactAbsoluteResetLabel(resetAt, now: now, calendar: calendar)
        guard showsCountdown(resetAt, now: now) else { return absolute }
        guard let countdown = countdownLabel(resetAt, now: now) else { return absolute }
        return absolute.map { "in \(countdown) (\($0))" } ?? "in \(countdown)"
    }

    /// Same information as `absoluteResetLabel`, with the separator doing
    /// the work "at" was doing.
    public static func compactAbsoluteResetLabel(
        _ resetAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let resetAt else { return nil }
        if calendar.isDate(resetAt, inSameDayAs: now) {
            return resetAt.formatted(.dateTime.hour().minute())
        }
        let day = resetAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let time = resetAt.formatted(.dateTime.hour().minute())
        return "\(day) · \(time)"
    }

    /// `relativeResetLabel` without its trailing "left", for phrasings
    /// that already supply the preposition.
    public static func countdownLabel(_ resetAt: Date?, now: Date) -> String? {
        guard let label = relativeResetLabel(resetAt, now: now) else { return nil }
        guard label.hasSuffix(" left") else { return label }
        return String(label.dropLast(" left".count))
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
