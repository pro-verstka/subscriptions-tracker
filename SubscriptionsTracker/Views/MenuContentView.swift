import SwiftUI
import SwiftData
import AppKit

/// Содержимое выпадающего окна в menubar: итоги по валютам, список подписок,
/// кнопки добавления и выхода.
struct MenuContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updater = UpdateService.shared
    @Query private var subscriptions: [Subscription]

    @State private var editingSubscription: Subscription?
    @State private var isAddingSubscription = false
    @State private var listContentHeight: CGFloat = 0

    /// Подписки, сгруппированные по валюте, с месячным итогом группы.
    private struct CurrencyGroup: Identifiable {
        let total: CurrencyTotal
        let subscriptions: [Subscription]
        var id: String { total.currencyCode }
    }

    private var groups: [CurrencyGroup] {
        let sort = settings.sortOrder
        return TotalsCalculator.monthlyTotals(for: subscriptions).map { total in
            let inGroup = subscriptions.filter { $0.currencyCode == total.currencyCode }
            return CurrencyGroup(total: total, subscriptions: sort.apply(to: inGroup))
        }
    }

    private var totals: [CurrencyTotal] {
        TotalsCalculator.monthlyTotals(for: subscriptions)
    }

    /// Отпечаток полей, влияющих на расписание уведомлений. Меняется при добавлении,
    /// удалении или правке релевантных полей — это триггер для пересчёта уведомлений.
    private var schedulingFingerprint: String {
        subscriptions
            .map { "\($0.persistentModelID.hashValue):\($0.renewalDate.timeIntervalSince1970):\($0.notifyDaysBefore):\($0.periodRaw)" }
            .joined(separator: "|")
    }

    private var isShowingForm: Bool { isAddingSubscription || editingSubscription != nil }

    var body: some View {
        // Форма встраивается в то же окно, а не открывается как `.sheet`: окно menubar
        // (стиль `.window`) закрывается при потере фокуса, поэтому отдельное окно-sheet
        // схлопывалось бы при клике по нему. Инлайн-переключение этого избегает.
        VStack(spacing: 0) {
            if isShowingForm {
                SubscriptionFormView(subscription: editingSubscription) {
                    isAddingSubscription = false
                    editingSubscription = nil
                }
            } else {
                list
            }
        }
        .task {
            if AppSettings.shared.notificationsEnabled {
                await NotificationScheduler.requestAuthorization()
            }
            await NotificationScheduler.reschedule(for: subscriptions)
        }
        .onChange(of: schedulingFingerprint) {
            let current = subscriptions
            Task { await NotificationScheduler.reschedule(for: current) }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !subscriptions.isEmpty {
                header
                Divider()
            }
            content
            if showsUpdateBanner {
                Divider()
                updateBanner
            }
            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: - Update banner

    private var showsUpdateBanner: Bool {
        switch updater.state {
        case .available, .downloading, .installing, .failed: return true
        case .idle, .checking: return false
        }
    }

    @ViewBuilder
    private var updateBanner: some View {
        switch updater.state {
        case .available(let release):
            Button {
                updater.checkForUpdate(manual: true)
            } label: {
                Label("Update available (\(release.version))", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help("Click to download and install")
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

        case .downloading:
            updateStatusRow("Downloading update…", systemImage: "arrow.down.circle")

        case .installing:
            updateStatusRow("Installing update…", systemImage: "gearshape.2")

        case .failed(let message):
            Button {
                updater.checkForUpdate(manual: true)
            } label: {
                Label("Update failed — retry", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help(message)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

        case .idle, .checking:
            EmptyView()
        }
    }

    private func updateStatusRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView().controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Header (итоги по валютам — колонками)

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly total")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                    if index > 0 {
                        Divider().frame(height: 30)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(total.currencyCode)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(total.formatted)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, index > 0 ? 10 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    // MARK: - Content (список, сгруппированный по валюте)

    private func groupHeader(_ group: CurrencyGroup) -> some View {
        HStack {
            Text(group.total.currencyCode)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(group.total.formatted)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
    }

    @ViewBuilder
    private var content: some View {
        if subscriptions.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No subscriptions yet")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            // ScrollView не имеет собственной высоты, а окно MenuBarExtra подгоняется
            // под контент — без явной высоты список схлопнулся бы в 0. Высота растёт
            // с числом строк до `maxVisibleRows`, дальше включается прокрутка.
            ScrollView {
                LazyVStack(spacing: 0) {
                    if settings.groupByCurrency {
                        ForEach(groups) { group in
                            groupHeader(group)
                            Divider()
                            ForEach(group.subscriptions) { subscription in
                                row(subscription)
                                Divider()
                            }
                        }
                    } else {
                        ForEach(settings.sortOrder.apply(to: subscriptions)) { subscription in
                            row(subscription)
                            Divider()
                        }
                    }
                }
                // измеряем реальную высоту контента, чтобы область списка точно
                // подгонялась под строки (без зазоров) и упиралась в потолок
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listContentHeight = $0 }
            }
            .frame(height: min(listContentHeight, maxListHeight))
        }
    }

    private func row(_ subscription: Subscription) -> some View {
        SubscriptionRow(subscription: subscription)
            .contentShape(Rectangle())
            .onTapGesture { editingSubscription = subscription }
            .contextMenu {
                Button("Edit") { editingSubscription = subscription }
                Button("Delete", role: .destructive) { delete(subscription) }
            }
    }

    /// Потолок высоты списка: вмещает несколько строк с заголовками групп, дальше — прокрутка.
    private let maxListHeight: CGFloat = 420

    // MARK: - Footer (кнопки)

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                isAddingSubscription = true
            } label: {
                Label("Add", systemImage: "plus")
            }

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
    }

    // MARK: - Actions

    private func delete(_ subscription: Subscription) {
        modelContext.delete(subscription)
        try? modelContext.save()
    }

    private func openSettings() {
        openWindow(id: "settings")
        NSApp.activate() // вынести окно настроек на передний план у agent-приложения
    }
}
