import Foundation

/// Per-currency total, stored as a monthly amount; other periods derived on the fly.
struct CurrencyTotal: Identifiable {
    let currencyCode: String
    let monthlyAmount: Decimal
    var id: String { currencyCode }

    func amount(per period: BillingPeriod) -> Decimal {
        monthlyAmount / period.monthlyFactor
    }

    func formatted(per period: BillingPeriod) -> String {
        let value = amount(per: period).formatted(.currency(code: currencyCode))
        return "\(value)\(period.totalSuffix)"
    }
}

enum TotalsCalculator {
    /// Normalizes each subscription to a monthly amount and groups by currency
    /// code. `Decimal` arithmetic only.
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
