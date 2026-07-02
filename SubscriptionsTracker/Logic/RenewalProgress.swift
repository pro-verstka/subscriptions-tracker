import SwiftUI

enum RenewalProgress {
    /// Fraction of the current billing cycle: 0 = just renewed, 1 = renewal due.
    /// The cycle spans from the previous renewal to the nearest future one.
    static func fraction(
        for subscription: Subscription,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let next = RenewalDate.nextOccurrence(
            of: subscription.renewalDate, period: subscription.period, now: now, calendar: calendar
        )
        let step = subscription.period.calendarStep
        guard
            let previous = calendar.date(byAdding: step.component, value: -step.value, to: next)
        else { return 0 }

        let total = next.timeIntervalSince(previous)
        guard total > 0 else { return 0 }

        let elapsed = now.timeIntervalSince(previous)
        return min(max(elapsed / total, 0), 1)
    }

    static func color(forFraction fraction: Double) -> Color {
        let hue = 0.33 * (1 - fraction) // hue 0.33 ≈ green, 0.0 = red
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }

    /// Whole days until the nearest renewal (never negative).
    static func daysRemaining(
        for subscription: Subscription,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let next = RenewalDate.nextOccurrence(
            of: subscription.renewalDate, period: subscription.period, now: now, calendar: calendar
        )
        let components = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: next)
        )
        return max(components.day ?? 0, 0)
    }
}
