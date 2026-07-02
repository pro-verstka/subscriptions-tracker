import SwiftUI
import AppKit

struct AboutView: View {
    private let repositoryURL = URL(string: "https://github.com/pro-verstka/subscriptions-tracker")!

    private let versionText: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "Unknown"
    }()

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Subscriptions Tracker")
                .font(.title2.bold())

            Text("Track your subscriptions and total monthly spend, right from the menu bar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(versionText)
            }

            HStack {
                Text("Author")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("pro-verstka")
            }

            HStack {
                Text("Git")
                    .foregroundStyle(.secondary)
                Spacer()
                Link("github.com/pro-verstka/subscriptions-tracker", destination: repositoryURL)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
