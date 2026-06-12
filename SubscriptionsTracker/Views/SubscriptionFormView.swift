import SwiftUI
import SwiftData

/// Форма добавления/редактирования подписки. `subscription == nil` — режим добавления.
/// Показывается в отдельном окне (`Window` сцены), поэтому закрытие выполняется через
/// `@Environment(\.dismiss)`. Цель формы окну передаёт `SubscriptionFormPresenter`.
struct SubscriptionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Пока поддерживаем только эти валюты (код + символ).
    static let supportedCurrencies: [(code: String, symbol: String)] = [
        ("USD", "$"),
        ("EUR", "€"),
        ("RUB", "₽"),
    ]

    let subscription: Subscription?

    @State private var name: String
    @State private var amount: Decimal?
    @State private var currencyCode: String
    @State private var period: BillingPeriod
    @State private var renewalDate: Date
    @State private var notifyDaysBefore: Int

    private var isEditing: Bool { subscription != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (amount ?? 0) > 0
            && !currencyCode.isEmpty
    }

    init(subscription: Subscription?) {
        self.subscription = subscription
        _name = State(initialValue: subscription?.name ?? "")
        _amount = State(initialValue: subscription?.amount)
        let localeCurrency = Locale.current.currency?.identifier
        let defaultCurrency = Self.supportedCurrencies.contains(where: { $0.code == localeCurrency })
            ? localeCurrency!
            : "USD"
        _currencyCode = State(initialValue: subscription?.currencyCode ?? defaultCurrency)
        _period = State(initialValue: subscription?.period ?? .monthly)
        _renewalDate = State(initialValue: subscription?.renewalDate ?? .now)
        _notifyDaysBefore = State(initialValue: subscription?.notifyDaysBefore ?? 3)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name)

                DecimalField("Amount", value: $amount)

                Picker("Currency", selection: $currencyCode) {
                    ForEach(Self.supportedCurrencies, id: \.code) { currency in
                        Text("\(currency.symbol)  \(currency.code)").tag(currency.code)
                    }
                }

                Picker("Period", selection: $period) {
                    ForEach(BillingPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }

                DatePicker("Renewal date", selection: $renewalDate, displayedComponents: .date)

                Stepper("Notify \(notifyDaysBefore) day(s) before", value: $notifyDaysBefore, in: 0...60)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(12)
        }
        .frame(width: 360, height: 440)
        .navigationTitle(isEditing ? "Edit Subscription" : "New Subscription")
    }

    private func save() {
        guard let amount, canSave else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let subscription {
            subscription.name = trimmedName
            subscription.amount = amount
            subscription.currencyCode = currencyCode
            subscription.period = period
            subscription.renewalDate = renewalDate
            subscription.notifyDaysBefore = notifyDaysBefore
        } else {
            let new = Subscription(
                name: trimmedName,
                amount: amount,
                currencyCode: currencyCode,
                period: period,
                renewalDate: renewalDate,
                notifyDaysBefore: notifyDaysBefore
            )
            modelContext.insert(new)
        }

        try? modelContext.save()
        dismiss()
    }
}

/// Содержимое окна формы: берёт цель у `SubscriptionFormPresenter` и пересоздаёт
/// форму по `token`, чтобы каждое открытие начиналось с актуальными значениями.
struct SubscriptionFormScene: View {
    @ObservedObject private var presenter = SubscriptionFormPresenter.shared

    var body: some View {
        SubscriptionFormView(subscription: presenter.subscription)
            .id(presenter.token)
    }
}
