import Foundation

/// Итог «в месяц» по одной валюте. Хранится в месячном выражении; пересчёт
/// на другой период делается на лету в `amount(per:)`/`formatted(per:)`.
struct CurrencyTotal: Identifiable {
    let currencyCode: String
    let monthlyAmount: Decimal
    var id: String { currencyCode }

    /// Сумма, пересчитанная с «в месяц» на указанный период.
    func amount(per period: BillingPeriod) -> Decimal {
        monthlyAmount / period.monthlyFactor
    }

    /// Строка вида «25,00 $/mo» для указанного периода, по правилам валюты.
    func formatted(per period: BillingPeriod) -> String {
        let value = amount(per: period).formatted(.currency(code: currencyCode))
        return "\(value)\(period.totalSuffix)"
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
