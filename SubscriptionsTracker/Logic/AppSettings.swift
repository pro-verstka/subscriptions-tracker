import Foundation
import Combine

/// Portable settings representation for export/import; enums as rawValue.
struct SettingsDTO: Codable {
    var notificationsEnabled: Bool
    var sortOrder: String
    var groupByCurrency: Bool
    var showAllSubscriptions: Bool
    var totalsPeriod: String
    var updateAutoCheckEnabled: Bool
}

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

    @Published var totalsPeriod: BillingPeriod {
        didSet { defaults.set(totalsPeriod.rawValue, forKey: Keys.totalsPeriod) }
    }

    /// `updateAutoCheckEnabled` lives outside `AppSettings` (read directly by
    /// `UpdateService`/`SettingsView`) but is stored in the same `UserDefaults`.
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

    /// Invalid enum rawValues keep the current value.
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
