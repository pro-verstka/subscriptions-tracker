import SwiftUI

/// Передаёт окну формы текущую цель: подписку для редактирования или `nil` для добавления.
/// `token` меняется при каждом открытии, чтобы пересоздавать `@State` формы
/// (через `.id(token)`) — иначе при повторном открытии остались бы старые значения.
@MainActor
final class SubscriptionFormPresenter: ObservableObject {
    static let shared = SubscriptionFormPresenter()

    @Published private(set) var subscription: Subscription?
    @Published private(set) var token = UUID()

    func present(_ subscription: Subscription?) {
        self.subscription = subscription
        self.token = UUID()
    }

    private init() {}
}
