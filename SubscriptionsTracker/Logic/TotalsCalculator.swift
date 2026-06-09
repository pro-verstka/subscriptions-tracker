import Foundation

/// Итог «в месяц» по одной валюте.
struct CurrencyTotal: Identifiable {
    let currencyCode: String
    let monthlyAmount: Decimal
    var id: String { currencyCode }

    /// Строка вида «25,00 $/mo», отформатированная по правилам валюты.
    var formatted: String {
        let value = monthlyAmount.formatted(.currency(code: currencyCode))
        return "\(value)/mo"
    }
}

/// Подсчёт общих сумм подписок.
enum TotalsCalculator {
    /// Нормализует сумму каждой подписки к «в месяц» (умножение на `period.monthlyFactor`)
    /// и группирует по коду валюты. Арифметика — только в `Decimal`.
    static func monthlyTotals(for subscriptions: [Subscription]) -> [CurrencyTotal] {
        var sums: [String: Decimal] = [:]
        for subscription in subscriptions {
            let perMonth = subscription.amount * subscription.period.monthlyFactor
            sums[subscription.currencyCode, default: 0] += perMonth
        }
        return sums
            .map { CurrencyTotal(currencyCode: $0.key, monthlyAmount: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }
}
