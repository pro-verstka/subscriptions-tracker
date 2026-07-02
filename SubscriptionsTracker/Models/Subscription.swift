import Foundation
import SwiftData

@Model
final class Subscription {
    var name: String
    var amount: Decimal
    var currencyCode: String
    /// Stored as a raw string for SwiftData schema stability; typed access via `period`.
    var periodRaw: String
    var renewalDate: Date
    var notifyDaysBefore: Int
    /// Paused: hidden from the list (unless "Show all subscriptions" is on), excluded
    /// from totals and reminders. Default in the declaration eases store migration.
    var isPaused: Bool = false

    /// Stable notification identifier. Not derived from `persistentModelID`: that is
    /// not a stable external key (it changes across temporary→permanent and between
    /// fetches), which made delivered notifications pile up instead of collapsing.
    /// Optional for store migration; nil records are backfilled by `NotificationScheduler`.
    var notificationID: String?

    /// Renewal cycle (`nextRenewal`) a reminder was already shown for. Survives
    /// restarts; stops matching once `nextRenewal` moves on, re-arming the reminder.
    var lastNotifiedRenewal: Date?

    var period: BillingPeriod {
        get { BillingPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    init(
        name: String,
        amount: Decimal,
        currencyCode: String,
        period: BillingPeriod,
        renewalDate: Date,
        notifyDaysBefore: Int = 3,
        isPaused: Bool = false
    ) {
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.periodRaw = period.rawValue
        self.renewalDate = renewalDate
        self.notifyDaysBefore = notifyDaysBefore
        self.isPaused = isPaused
        self.notificationID = UUID().uuidString
    }

    /// Nearest future renewal date, computed from the stored date.
    var nextRenewal: Date {
        RenewalDate.nextOccurrence(of: renewalDate, period: period)
    }
}
