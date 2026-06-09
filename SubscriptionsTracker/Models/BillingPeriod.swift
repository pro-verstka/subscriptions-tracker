import Foundation

/// Биллинговый цикл подписки.
enum BillingPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// Человекочитаемое название для UI.
    var title: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    /// Множитель, приводящий одну оплату этого периода к сумме «в месяц».
    /// weekly: 52 недели / 12 месяцев; monthly: 1; yearly: 1 / 12.
    var monthlyFactor: Decimal {
        switch self {
        case .weekly:  return Decimal(52) / Decimal(12)
        case .monthly: return 1
        case .yearly:  return Decimal(1) / Decimal(12)
        }
    }

    /// Календарный шаг для перемотки даты продления вперёд.
    var calendarStep: (component: Calendar.Component, value: Int) {
        switch self {
        case .weekly:  return (.day, 7)
        case .monthly: return (.month, 1)
        case .yearly:  return (.year, 1)
        }
    }
}
