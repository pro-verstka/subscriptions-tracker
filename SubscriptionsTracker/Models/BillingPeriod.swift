import Foundation

enum BillingPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    var totalSuffix: String {
        switch self {
        case .weekly:  return "/wk"
        case .monthly: return "/mo"
        case .yearly:  return "/yr"
        }
    }

    /// Converts one payment of this period to a monthly amount:
    /// weekly = 52/12, yearly = 1/12.
    var monthlyFactor: Decimal {
        switch self {
        case .weekly:  return Decimal(52) / Decimal(12)
        case .monthly: return 1
        case .yearly:  return Decimal(1) / Decimal(12)
        }
    }

    /// Calendar step for rolling a renewal date forward.
    var calendarStep: (component: Calendar.Component, value: Int) {
        switch self {
        case .weekly:  return (.day, 7)
        case .monthly: return (.month, 1)
        case .yearly:  return (.year, 1)
        }
    }
}
