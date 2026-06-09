import Foundation
import SwiftData

/// Единый `ModelContainer` приложения. Один контейнер на процесс — повторное создание
/// против того же URL стора бросает ошибку, поэтому используем общий статический экземпляр
/// и для SwiftUI-сцены, и для планировщика уведомлений.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Subscription.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
