import Foundation
import SwiftData

/// The app's single `ModelContainer`. Creating a second container against the same
/// store URL throws, so the SwiftUI scene and non-UI code share this one instance.
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
