import Foundation

/// Вычисление даты продления.
enum RenewalDate {
    /// Возвращает ближайшее вхождение даты продления на момент `now` или позже,
    /// перематывая исходную дату вперёд с шагом биллингового периода.
    ///
    /// Используется `Calendar.date(byAdding:)`, поэтому арифметика месяцев и лет
    /// корректно учитывает реальную длину периодов (например, 31 января + 1 месяц).
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
