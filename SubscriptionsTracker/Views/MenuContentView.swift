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

    /// Подписки, сгруппированные по валюте, с месячным итогом группы.
    private struct CurrencyGroup: Identifiable {
        let total: CurrencyTotal
        let subscriptions: [Subscription]
        var id: String { total.currencyCode }
    }

    /// Активные подписки — участвуют в итогах и уведомлениях.
    private var activeSubscriptions: [Subscription] {
        subscriptions.filter { !$0.isPaused }
    }

    /// Подписки, отображаемые в списке (с учётом «Show all subscriptions»).
    private var displayedSubscriptions: [Subscription] {
        settings.showAllSubscriptions ? subscriptions : activeSubscriptions
    }

    /// Группы строятся по валютам отображаемых подписок, а суммы — только по активным:
    /// валютная группа, где всё на паузе, остаётся видимой с нулевым итогом.
    private var groups: [CurrencyGroup] {
        let sort = settings.sortOrder
        let activeTotals = Dictionary(
            uniqueKeysWithValues: TotalsCalculator.monthlyTotals(for: activeSubscriptions)
                .map { ($0.currencyCode, $0) }
        )
        return Set(displayedSubscriptions.map(\.currencyCode)).sorted().map { code in
            let total = activeTotals[code] ?? CurrencyTotal(currencyCode: code, monthlyAmount: 0)
            let inGroup = displayedSubscriptions.filter { $0.currencyCode == code }
            return CurrencyGroup(total: total, subscriptions: sort.apply(to: inGroup))
        }
    }

    private var totals: [CurrencyTotal] {
        TotalsCalculator.monthlyTotals(for: activeSubscriptions)
    }

    var body: some View {
        // Форма открывается отдельным окном (сцена `subscriptionForm`), а не инлайн:
        // окно menubar (стиль `.window`) закрывается при потере фокуса, что и происходит
        // при активации окна формы — это ожидаемо, как и при открытии Settings.
        // Напоминаниями занимается NotificationScheduler (стартует в AppDelegate),
        // этой вью для них ничего делать не нужно.
        list
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !totals.isEmpty {
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
            HStack(spacing: 4) {
                Text("\(settings.totalsPeriod.title) total")
                Image(systemName: "arrow.left.arrow.right")
            }
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
                        Text(total.formatted(per: settings.totalsPeriod))
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
        .contentShape(Rectangle())
        .onTapGesture { cycleTotalsPeriod() }
        .help("Click to switch period (week / month / year)")
    }

    // MARK: - Content (список, сгруппированный по валюте)

    private func groupHeader(_ group: CurrencyGroup) -> some View {
        HStack {
            Text(group.total.currencyCode)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(group.total.formatted(per: settings.totalsPeriod))
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
        // У ScrollView нет собственной высоты, а окно MenuBarExtra подгоняется под
        // контент, поэтому область списка имеет фиксированную высоту: строк меньше —
        // снизу пустое место, больше — прокрутка. Динамическое измерение убрано:
        // окно схлопывалось при первом запуске и не ужималось при удалении строк.
        Group {
            if displayedSubscriptions.isEmpty {
                VStack(spacing: 6) {
                    // Различаем «подписок нет вовсе» и «все на паузе и скрыты».
                    Image(systemName: subscriptions.isEmpty ? "tray" : "pause.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(subscriptions.isEmpty ? "No subscriptions yet" : "All subscriptions are paused")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // `TimelineView` каждую минуту прогоняет актуальный `now` в строки,
                    // чтобы прогресс и дата продления не застывали (см. SubscriptionRow).
                    TimelineView(.everyMinute) { context in
                        LazyVStack(spacing: 0) {
                            if settings.groupByCurrency {
                                ForEach(groups) { group in
                                    groupHeader(group)
                                    Divider()
                                    ForEach(group.subscriptions) { subscription in
                                        row(subscription, now: context.date)
                                        Divider()
                                    }
                                }
                            } else {
                                ForEach(settings.sortOrder.apply(to: displayedSubscriptions)) { subscription in
                                    row(subscription, now: context.date)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: listHeight)
    }

    private func row(_ subscription: Subscription, now: Date) -> some View {
        SubscriptionRow(subscription: subscription, now: now)
            .contentShape(Rectangle())
            .onTapGesture { presentForm(subscription) }
            .contextMenu {
                Button("Edit") { presentForm(subscription) }
                Button(subscription.isPaused ? "Resume" : "Pause") { togglePause(subscription) }
                Button("Delete", role: .destructive) { delete(subscription) }
            }
    }

    /// Фиксированная высота области списка: если строк больше — прокрутка,
    /// если меньше — пустое место снизу.
    private let listHeight: CGFloat = 420

    // MARK: - Footer (кнопки)

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                presentForm(nil)
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
        // Явная проверка: доставленное уведомление удалённой подписки убираем сразу,
        // не дожидаясь минутного тика планировщика.
        Task { await NotificationScheduler.checkNow() }
    }

    /// Ставит подписку на паузу или возобновляет её.
    private func togglePause(_ subscription: Subscription) {
        subscription.isPaused.toggle()
        try? modelContext.save()
        Task { await NotificationScheduler.checkNow() }
    }

    /// Переключает период отображения итогов по кругу: month → year → week → …
    private func cycleTotalsPeriod() {
        let all = BillingPeriod.allCases
        let index = all.firstIndex(of: settings.totalsPeriod) ?? 0
        settings.totalsPeriod = all[(index + 1) % all.count]
    }

    private func openSettings() {
        openWindow(id: "settings")
        NSApp.activate() // вынести окно настроек на передний план у agent-приложения
    }

    /// Открывает окно формы: `nil` — добавление, иначе редактирование подписки.
    private func presentForm(_ subscription: Subscription?) {
        SubscriptionFormPresenter.shared.present(subscription)
        openWindow(id: "subscriptionForm")
        NSApp.activate() // вынести окно формы на передний план у agent-приложения
    }
}
