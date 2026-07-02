import Foundation

enum SubscriptionSort: String, CaseIterable, Identifiable {
    case renewalDate
    case name
    case amount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .renewalDate: return "Renewal date"
        case .name:        return "Name"
        case .amount:      return "Amount (high → low)"
        }
    }

    func apply(to subscriptions: [Subscription]) -> [Subscription] {
        switch self {
        case .renewalDate:
            return subscriptions.sorted { $0.nextRenewal < $1.nextRenewal }
        case .name:
            return subscriptions.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .amount:
            return subscriptions.sorted {
                ($0.amount * $0.period.monthlyFactor) > ($1.amount * $1.period.monthlyFactor)
            }
        }
    }
}
