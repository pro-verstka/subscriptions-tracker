import SwiftUI

/// Строка списка: название и сумма, цветной прогресс-бар цикла и «сколько осталось».
struct SubscriptionRow: View {
    let subscription: Subscription

    private var amountText: String {
        subscription.amount.formatted(.currency(code: subscription.currencyCode))
    }

    private var fraction: Double {
        RenewalProgress.fraction(for: subscription)
    }

    private var accent: Color {
        RenewalProgress.color(forFraction: fraction)
    }

    private var renewalCaption: String {
        let days = RenewalProgress.daysRemaining(for: subscription)
        let date = subscription.nextRenewal.formatted(date: .abbreviated, time: .omitted)
        switch days {
        case 0:  return "Renews today · \(date)"
        case 1:  return "Renews tomorrow · \(date)"
        default: return "In \(days) days · \(date)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(subscription.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(amountText)
                    .font(.body)
                    .monospacedDigit()
            }

            HStack {
                Text(renewalCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(subscription.period.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: fraction)
                .tint(accent)
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 4)
    }
}
