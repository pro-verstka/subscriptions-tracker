import Foundation
import SwiftData

/// Одна отслеживаемая подписка.
///
/// `period` хранится как raw-строка (`periodRaw`) для стабильности схемы SwiftData;
/// доступ к типизированному значению — через computed-свойство `period`.
@Model
final class Subscription {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var periodRaw: String
    var renewalDate: Date
    var notifyDaysBefore: Int
    /// Подписка «на паузе»: скрыта из списка (если не включён показ всех),
    /// не входит в итоги и не получает уведомлений. Default в объявлении —
    /// для лёгкой миграции существующих хранилищ SwiftData.
    var isPaused: Bool = false

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
    }

    /// Ближайшая будущая дата продления, вычисленная от сохранённой даты.
    var nextRenewal: Date {
        RenewalDate.nextOccurrence(of: renewalDate, period: period)
    }
}
