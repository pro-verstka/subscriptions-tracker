import SwiftUI

/// Hands the form window its target: a subscription to edit, or `nil` to add.
/// `token` changes on every open so the form's `@State` is recreated via `.id(token)`.
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
