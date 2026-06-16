import SwiftUI

/// Прогресс текущего биллингового цикла подписки и цвет «срочности».
enum RenewalProgress {
    /// Доля пройденного цикла: 0 — только что продлили, 1 — наступает продление.
    /// Цикл = от предыдущего продления до ближайшего будущего (по периоду подписки).
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

    /// Цвет от зелёного (далеко) к красному (близко) — через жёлтый.
    static func color(forFraction fraction: Double) -> Color {
        let hue = 0.33 * (1 - fraction) // 0.33 ≈ зелёный, 0.0 = красный
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }

    /// Сколько целых дней осталось до ближайшего продления (не меньше 0).
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
