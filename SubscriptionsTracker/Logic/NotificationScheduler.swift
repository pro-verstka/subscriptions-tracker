import Foundation
import SwiftData
import UserNotifications

/// Локальные уведомления о приближающемся продлении подписки.
@MainActor
enum NotificationScheduler {
    /// Запрашивает разрешение на показ уведомлений (один раз при старте).
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Фетчит подписки из общего хранилища и пересоздаёт уведомления.
    static func rescheduleFromStore() async {
        let context = AppModelContainer.shared.mainContext
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await reschedule(for: subscriptions)
    }

    /// Сбрасывает все запланированные уведомления и пересоздаёт по одному на подписку,
    /// на дату `nextRenewal − notifyDaysBefore`. Если эта дата уже прошла, но само
    /// продление ещё впереди (подписку добавили внутри окна напоминания) — уведомление
    /// показывается немедленно, но РОВНО ОДИН раз за цикл: повтор гасится по
    /// персистентному маркеру `lastNotifiedRenewal`. Подписки на паузе пропускаются.
    /// Если уведомления выключены в настройках — очищает и запланированные, и уже
    /// показанные. Вызывать при любом изменении данных.
    static func reschedule(for subscriptions: [Subscription]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard AppSettings.shared.notificationsEnabled else {
            // Уведомления выключены — заодно убираем уже показанные напоминания.
            center.removeAllDeliveredNotifications()
            return
        }

        // Бэкфилл идентичности для легаси-записей (созданных до появления `notificationID`).
        // Сохраняем только если реально что-то проставили — в установившемся режиме saves нет.
        var didMutate = false
        for subscription in subscriptions where subscription.notificationID == nil {
            subscription.notificationID = UUID().uuidString
            didMutate = true
        }
        if didMutate { try? AppModelContainer.shared.mainContext.save() }

        let calendar = Calendar.current
        let active = subscriptions.filter { !$0.isPaused }

        // Подчищаем «осиротевшие» доставленные уведомления: записи удалённых/паузнутых
        // подписок и старые копии с нестабильными id из прошлых версий. Доставленные активных
        // подписок остаются — следующая доставка заменит их по стабильному id, а не размножит.
        let validIDs = Set(active.compactMap { $0.notificationID.map { "sub-\($0)" } })
        let delivered = await center.deliveredNotifications()
        let stale = Set(delivered.map(\.request.identifier)).filter { !validIDs.contains($0) }
        if !stale.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(stale))
        }

        for subscription in active {
            guard let notificationID = subscription.notificationID else { continue }
            let identifier = "sub-\(notificationID)"
            let nextRenewal = subscription.nextRenewal
            guard let plannedFireDate = calendar.date(
                byAdding: .day,
                value: -subscription.notifyDaysBefore,
                to: nextRenewal
            ) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming renewal: \(subscription.name)"
            content.body = "\(subscription.amount.formatted(.currency(code: subscription.currencyCode))) renews \(nextRenewal.formatted(date: .abbreviated, time: .omitted))."
            content.sound = .default

            if plannedFireDate > .now {
                // Плановая дата напоминания ещё впереди — обычное отложенное уведомление.
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: plannedFireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                try? await center.add(request)
            } else if nextRenewal > .now {
                // Плановая дата прошла, но продление ещё впереди (подписку добавили внутри окна
                // напоминания или продление совсем близко) — не теряем уведомление, показываем
                // его сразу. Но РОВНО ОДИН раз за цикл: reschedule работает по принципу
                // reset-and-rebuild и вызывается часто, поэтому повтор гасим персистентным
                // маркером. Маркер ставим ДО доставки (оптимистично) — это закрывает гонку
                // двух одновременных пересчётов; немедленная доставка (trigger: nil) убирает
                // 60-секундное pending-окно, в котором следующий reset отменил бы напоминание.
                if subscription.lastNotifiedRenewal == nextRenewal { continue }
                subscription.lastNotifiedRenewal = nextRenewal
                try? AppModelContainer.shared.mainContext.save()
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
                try? await center.add(request)
            }
            // Иначе продление уже позади — пропускаем (в норме недостижимо: nextRenewal
            // всегда в будущем, см. RenewalDate.nextOccurrence).
        }
    }
}
