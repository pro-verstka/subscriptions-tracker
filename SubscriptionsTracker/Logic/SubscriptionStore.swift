import Foundation
import SwiftData

struct SubscriptionDTO: Codable {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var period: String
    var renewalDate: Date
    var notifyDaysBefore: Int
    /// Optional for compatibility with old export files.
    var isPaused: Bool?
}

struct ImportResult {
    let added: Int
    let skipped: Int
}

struct ExportDocument: Codable {
    var subscriptions: [SubscriptionDTO]
    var settings: SettingsDTO
}

/// JSON export/import of subscriptions and settings.
@MainActor
enum SubscriptionStore {
    /// Identity is all fields — identical records are not duplicated on import.
    private static func identityKey(
        name: String, amount: Decimal, currencyCode: String,
        period: String, renewalDate: Date, notifyDaysBefore: Int
    ) -> String {
        "\(name)|\(amount)|\(currencyCode)|\(period)|\(renewalDate.timeIntervalSince1970)|\(notifyDaysBefore)"
    }
    static func exportJSON() throws -> Data {
        let context = AppModelContainer.shared.mainContext
        let subscriptions = try context.fetch(
            FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.renewalDate, order: .forward)])
        )
        let dtos = subscriptions.map {
            SubscriptionDTO(
                name: $0.name,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                period: $0.periodRaw,
                renewalDate: $0.renewalDate,
                notifyDaysBefore: $0.notifyDaysBefore,
                isPaused: $0.isPaused
            )
        }
        let document = ExportDocument(subscriptions: dtos, settings: AppSettings.shared.exportSnapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    @discardableResult
    static func importJSON(_ data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ExportDocument.self, from: data)
        let dtos = document.subscriptions

        let context = AppModelContainer.shared.mainContext
        let existing = try context.fetch(FetchDescriptor<Subscription>())
        var seen = Set(existing.map {
            identityKey(
                name: $0.name, amount: $0.amount, currencyCode: $0.currencyCode,
                period: $0.periodRaw, renewalDate: $0.renewalDate, notifyDaysBefore: $0.notifyDaysBefore
            )
        })

        var added = 0
        var skipped = 0
        for dto in dtos {
            let key = identityKey(
                name: dto.name, amount: dto.amount, currencyCode: dto.currencyCode,
                period: dto.period, renewalDate: dto.renewalDate, notifyDaysBefore: dto.notifyDaysBefore
            )
            // skips both existing records and duplicates within the file itself
            guard seen.insert(key).inserted else { skipped += 1; continue }

            context.insert(Subscription(
                name: dto.name,
                amount: dto.amount,
                currencyCode: dto.currencyCode,
                period: BillingPeriod(rawValue: dto.period) ?? .monthly,
                renewalDate: dto.renewalDate,
                notifyDaysBefore: dto.notifyDaysBefore,
                isPaused: dto.isPaused ?? false
            ))
            added += 1
        }
        try context.save()
        AppSettings.shared.apply(document.settings)
        return ImportResult(added: added, skipped: skipped)
    }
}
