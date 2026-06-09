import Foundation
import SwiftData

/// Переносимое представление подписки для экспорта/импорта в JSON.
struct SubscriptionDTO: Codable {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var period: String
    var renewalDate: Date
    var notifyDaysBefore: Int
}

/// Результат импорта.
struct ImportResult {
    let added: Int
    let skipped: Int
}

/// Экспорт/импорт подписок в JSON через общий контекст SwiftData.
@MainActor
enum SubscriptionStore {
    /// Ключ идентичности подписки — по всем полям. Идентичные записи при импорте
    /// не дублируются.
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
                notifyDaysBefore: $0.notifyDaysBefore
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dtos)
    }

    /// Декодирует JSON и добавляет подписки в хранилище, пропуская те, что уже есть
    /// (идентичные по всем полям). Возвращает количество добавленных и пропущенных.
    @discardableResult
    static func importJSON(_ data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([SubscriptionDTO].self, from: data)

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
            // пропускаем как уже существующие, так и дубли внутри самого файла
            guard seen.insert(key).inserted else { skipped += 1; continue }

            context.insert(Subscription(
                name: dto.name,
                amount: dto.amount,
                currencyCode: dto.currencyCode,
                period: BillingPeriod(rawValue: dto.period) ?? .monthly,
                renewalDate: dto.renewalDate,
                notifyDaysBefore: dto.notifyDaysBefore
            ))
            added += 1
        }
        try context.save()
        return ImportResult(added: added, skipped: skipped)
    }
}
