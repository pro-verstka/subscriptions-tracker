import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription
    /// Fed from `TimelineView` so progress, days left and dates keep updating over time.
    let now: Date

    private var amountText: String {
        subscription.amount.formatted(.currency(code: subscription.currencyCode))
    }

    private var fraction: Double {
        RenewalProgress.fraction(for: subscription, now: now)
    }

    private var accent: Color {
        subscription.isPaused ? .gray : RenewalProgress.color(forFraction: fraction)
    }

    private var nextRenewal: Date {
        RenewalDate.nextOccurrence(of: subscription.renewalDate, period: subscription.period, now: now)
    }

    private var renewalCaption: String {
        if subscription.isPaused { return "Paused" }
        let days = RenewalProgress.daysRemaining(for: subscription, now: now)
        let date = nextRenewal.formatted(date: .abbreviated, time: .omitted)
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

            // Paused rows keep the (empty) bar so row heights stay equal.
            ProgressView(value: subscription.isPaused ? 0 : fraction)
                .tint(accent)
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 4)
        .opacity(subscription.isPaused ? 0.55 : 1)
        .overlay(alignment: .leading) {
            if subscription.isPaused {
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
        }
    }
}
