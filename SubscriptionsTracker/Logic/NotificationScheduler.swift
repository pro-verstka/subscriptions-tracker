import Foundation
import SwiftData
import UserNotifications

/// Локальные уведомления о приближающемся продлении подписки.
///
/// Дизайн: приложение НИКОГДА не взводит отложенные (pending) запросы с триггерами
/// на будущее. usernoted в macOS 26 привязывает запросы не к bundle id, а к идентичности
/// конкретного бинарника (`source`; для ad-hoc-подписи это cdhash, уникальный у каждой
/// сборки). После каждого обновления (updater подменяет бандл) или запуска dev-сборки
/// старые pending-запросы становятся «чужими»: новый бинарник не видит их через
/// `getPending`/`removeAllPending` и не может заменить по identifier, но система
/// продолжает их доставлять под тем же именем приложения. Так каждая сборка оставляла
/// свой взведённый запрос на одну и ту же дату — и в момент срабатывания они падали
/// пачкой одинаковых уведомлений. Никакой reset-and-rebuild это не лечит.
///
/// Поэтому напоминания доставляет минутный таймер постоянно работающего агента:
/// «пора ли напомнить» проверяется по данным, доставка немедленная (`trigger: nil`),
/// повтор гасится персистентным маркером `lastNotifiedRenewal` — ровно один раз за цикл.
@MainActor
enum NotificationScheduler {
    private static var timer: Timer?

    /// Запускается один раз при старте приложения (из `AppDelegate`). Подчищает
    /// взведённые запросы своего source (наследие версий с календарными триггерами)
    /// и заводит минутную проверку напоминаний.
    static func start() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard timer == nil else { return }
        let t = Timer(timeInterval: 60, repeats: true) { _ in
            Task { @MainActor in await checkNow() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Task {
            if AppSettings.shared.notificationsEnabled {
                await requestAuthorization()
            }
            await checkNow()
        }
    }

    /// Запрашивает разрешение на показ уведомлений (при старте и включении тумблера).
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Однократная проверка: показывает напоминания, чей момент наступил, и подчищает
    /// доставленные уведомления неактуальных подписок. Вызывается таймером раз в минуту
    /// и явно после любого изменения данных (форма, удаление, импорт, настройки) —
    /// чтобы реакция была мгновенной, а не в пределах минуты.
    static func checkNow() async {
        let context = AppModelContainer.shared.mainContext
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        await check(subscriptions)
    }

    private static func check(_ subscriptions: [Subscription]) async {
        let center = UNUserNotificationCenter.current()

        guard AppSettings.shared.notificationsEnabled else {
            // Уведомления выключены — убираем уже показанные напоминания.
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
        // подписок и старые копии с нестабильными id из прошлых версий. Убрать получится
        // только доставленные этим же бинарником — чужие source нам не видны.
        let validIDs = Set(active.compactMap { $0.notificationID.map { "sub-\($0)" } })
        let delivered = await center.deliveredNotifications()
        let stale = Set(delivered.map(\.request.identifier)).filter { !validIDs.contains($0) }
        if !stale.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(stale))
        }

        for subscription in active {
            guard let notificationID = subscription.notificationID else { continue }
            let nextRenewal = subscription.nextRenewal
            guard let reminderDate = calendar.date(
                byAdding: .day,
                value: -subscription.notifyDaysBefore,
                to: nextRenewal
            ) else { continue }

            // Момент напоминания ещё впереди — ничего не взводим, следующий тик проверит.
            // Продление позади — пропускаем (в норме недостижимо: nextRenewal всегда
            // в будущем, см. RenewalDate.nextOccurrence).
            guard reminderDate <= .now, nextRenewal > .now else { continue }

            // РОВНО ОДИН раз за цикл продления. Маркер ставим ДО доставки (оптимистично)
            // и синхронно между точками прерывания — это закрывает гонку двух
            // одновременных проверок. В следующем цикле nextRenewal уходит вперёд,
            // перестаёт совпадать с маркером, и напоминание перевзводится само.
            if subscription.lastNotifiedRenewal == nextRenewal { continue }
            subscription.lastNotifiedRenewal = nextRenewal
            try? AppModelContainer.shared.mainContext.save()

            let content = UNMutableNotificationContent()
            content.title = "Upcoming renewal: \(subscription.name)"
            content.body = "\(subscription.amount.formatted(.currency(code: subscription.currencyCode))) renews \(nextRenewal.formatted(date: .abbreviated, time: .omitted))."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "sub-\(notificationID)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
