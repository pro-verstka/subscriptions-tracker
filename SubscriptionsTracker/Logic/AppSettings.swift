import Foundation
import Combine

/// Переносимое представление настроек приложения для экспорта/импорта.
/// `sortOrder` и `totalsPeriod` хранятся как rawValue соответствующих enum.
struct SettingsDTO: Codable {
    var notificationsEnabled: Bool
    var sortOrder: String
    var groupByCurrency: Bool
    var showAllSubscriptions: Bool
    var totalsPeriod: String
    var updateAutoCheckEnabled: Bool
}

/// Настройки приложения. Хранятся локально в `UserDefaults`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var sortOrder: SubscriptionSort {
        didSet { defaults.set(sortOrder.rawValue, forKey: Keys.sortOrder) }
    }

    @Published var groupByCurrency: Bool {
        didSet { defaults.set(groupByCurrency, forKey: Keys.groupByCurrency) }
    }

    @Published var showAllSubscriptions: Bool {
        didSet { defaults.set(showAllSubscriptions, forKey: Keys.showAllSubscriptions) }
    }

    /// Период, в котором показываются итоговые суммы в шапке (клик по сумме переключает).
    @Published var totalsPeriod: BillingPeriod {
        didSet { defaults.set(totalsPeriod.rawValue, forKey: Keys.totalsPeriod) }
    }

    /// Снимок настроек для экспорта. `updateAutoCheckEnabled` живёт вне `AppSettings`
    /// (его читают `UpdateService`/`SettingsView`), но хранится в том же `UserDefaults`.
    var exportSnapshot: SettingsDTO {
        SettingsDTO(
            notificationsEnabled: notificationsEnabled,
            sortOrder: sortOrder.rawValue,
            groupByCurrency: groupByCurrency,
            showAllSubscriptions: showAllSubscriptions,
            totalsPeriod: totalsPeriod.rawValue,
            updateAutoCheckEnabled: Self.bool(Keys.updateAutoCheckEnabled, default: true, defaults)
        )
    }

    /// Применяет импортированные настройки. Невалидные rawValue enum'ов оставляют текущее значение.
    func apply(_ dto: SettingsDTO) {
        notificationsEnabled = dto.notificationsEnabled
        sortOrder = SubscriptionSort(rawValue: dto.sortOrder) ?? sortOrder
        groupByCurrency = dto.groupByCurrency
        showAllSubscriptions = dto.showAllSubscriptions
        totalsPeriod = BillingPeriod(rawValue: dto.totalsPeriod) ?? totalsPeriod
        defaults.set(dto.updateAutoCheckEnabled, forKey: Keys.updateAutoCheckEnabled)
    }

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let sortOrder = "sortOrder"
        static let groupByCurrency = "groupByCurrency"
        static let showAllSubscriptions = "showAllSubscriptions"
        static let totalsPeriod = "totalsPeriod"
        static let updateAutoCheckEnabled = "updateAutoCheckEnabled"
    }

    private let defaults = UserDefaults.standard

    private init() {
        notificationsEnabled = Self.bool(Keys.notificationsEnabled, default: true, defaults)
        let rawSort = defaults.string(forKey: Keys.sortOrder) ?? SubscriptionSort.renewalDate.rawValue
        sortOrder = SubscriptionSort(rawValue: rawSort) ?? .renewalDate
        groupByCurrency = Self.bool(Keys.groupByCurrency, default: true, defaults)
        showAllSubscriptions = Self.bool(Keys.showAllSubscriptions, default: false, defaults)
        let rawPeriod = defaults.string(forKey: Keys.totalsPeriod) ?? BillingPeriod.monthly.rawValue
        totalsPeriod = BillingPeriod(rawValue: rawPeriod) ?? .monthly
    }

    private static func bool(_ key: String, default def: Bool, _ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? def : defaults.bool(forKey: key)
    }
}
