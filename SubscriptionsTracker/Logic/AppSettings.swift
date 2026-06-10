import Foundation
import Combine

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

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let sortOrder = "sortOrder"
        static let groupByCurrency = "groupByCurrency"
        static let showAllSubscriptions = "showAllSubscriptions"
    }

    private let defaults = UserDefaults.standard

    private init() {
        notificationsEnabled = Self.bool(Keys.notificationsEnabled, default: true, defaults)
        let rawSort = defaults.string(forKey: Keys.sortOrder) ?? SubscriptionSort.renewalDate.rawValue
        sortOrder = SubscriptionSort(rawValue: rawSort) ?? .renewalDate
        groupByCurrency = Self.bool(Keys.groupByCurrency, default: true, defaults)
        showAllSubscriptions = Self.bool(Keys.showAllSubscriptions, default: false, defaults)
    }

    private static func bool(_ key: String, default def: Bool, _ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? def : defaults.bool(forKey: key)
    }
}
