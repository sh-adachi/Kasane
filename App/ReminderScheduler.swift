import Foundation
import Observation
import UserNotifications

@Observable @MainActor
final class ReminderScheduler {
    var statusMessage = "通知の設定を確認しています。"
    private let enabled: Bool
    private let center = UNUserNotificationCenter.current()
    private let delegate = ReminderDelegate()
    private var latest: HabitData?
    private var syncing = false

    init(enabled: Bool) {
        self.enabled = enabled
        if enabled { center.delegate = delegate }
        else { statusMessage = "体験・テスト中は通知を送信しません。" }
    }

    func requestPermission() async {
        guard enabled else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshStatus()
        } catch {
            statusMessage = "通知の許可を確認できませんでした。設定アプリでご確認ください。"
        }
    }

    func refreshStatus() async {
        guard enabled else { return }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            statusMessage = "通知は許可されています。曜日・時刻を設定して保存してください。"
        case .denied:
            statusMessage = "通知は許可されていません。iPhoneの設定から通知を有効にできます。"
        case .notDetermined:
            statusMessage = "「通知でお知らせ」をオンにすると、通知の許可を確認します。"
        @unknown default:
            statusMessage = "iPhoneの設定で通知の状態をご確認ください。"
        }
    }

    /// Coalesces edits and serializes replacements, including edits during an await.
    func synchronize(_ data: HabitData) {
        guard enabled else { return }
        latest = data
        guard !syncing else { return }
        syncing = true
        Task {
            while let snapshot = latest {
                latest = nil
                await replaceRequests(snapshot)
            }
            syncing = false
        }
    }

    private func replaceRequests(_ data: HabitData) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("kasane.reminder.") }.map(\.identifier))
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            await refreshStatus()
            return
        }
        let plan = ReminderPlan.requests(data: data, on: HabitCalendar.dayKey(Date()))
        var scheduled = 0
        do {
            for item in plan.prefix(60) {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = "\(item.targetMinutes)分から、今日の小さな積み重ねを。"
                content.sound = .default
                content.threadIdentifier = "kasane.routines"
                var components = DateComponents()
                components.calendar = Calendar(identifier: .gregorian)
                components.weekday = item.weekday
                components.hour = item.hour
                components.minute = item.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                try await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
                scheduled += 1
            }
            statusMessage = plan.count > 60
                ? "通知の曜日設定が多いため、60件まで設定しました。不要な通知をオフにしてください。"
                : "曜日ごとの通知を\(scheduled)件設定しています。通知はiPhoneの集中モードなどにより表示されない場合があります。"
        } catch {
            statusMessage = "一部の通知を設定できませんでした。アプリを開き直すと再設定します。"
        }
    }
}

private final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
