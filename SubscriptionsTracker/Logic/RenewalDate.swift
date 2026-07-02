import Foundation

enum RenewalDate {
    /// Nearest occurrence of the renewal date at or after `now`, rolling the stored
    /// date forward in billing-period steps. Uses `Calendar.date(byAdding:)`, so
    /// month/year arithmetic respects real period lengths (e.g. Jan 31 + 1 month).
    static func nextOccurrence(
        of stored: Date,
        period: BillingPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        var date = stored
        let step = period.calendarStep
        var guardCount = 0
        while date < now, guardCount < 10_000 {
            guard let next = calendar.date(byAdding: step.component, value: step.value, to: date) else {
                break
            }
            date = next
            guardCount += 1
        }
        return date
    }
}
