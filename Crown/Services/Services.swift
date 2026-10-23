import LocalAuthentication
import SwiftUI
import UserNotifications

// MARK: - Reminders

/// Local notifications only; nothing is scheduled on a server.
enum Reminders {
    static let checkInID = "crown.checkin"
    static let routineID = "crown.routine"

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleCheckIn(after lastScan: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [checkInID])
        guard UserDefaults.standard.bool(forKey: "remindCheckIn"), let lastScan else { return }
        var due = Calendar.current.date(byAdding: .day, value: 30, to: lastScan) ?? lastScan
        due = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: due) ?? due
        guard due > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your monthly check-in is ready"
        content.body = "Same spot, same light. Two minutes to see how your hairline is tracking."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due), repeats: false)
        center.add(UNNotificationRequest(identifier: checkInID, content: content, trigger: trigger))
    }

    static func scheduleRoutine() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [routineID])
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "remindRoutine") else { return }
        let minutes = defaults.object(forKey: "routineMinutes") as? Int ?? 21 * 60
        let content = UNMutableNotificationContent()
        content.title = "Routine time"
        content.body = "Check off today's steps to keep your streak going."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        center.add(UNNotificationRequest(identifier: routineID, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
    }
}

// MARK: - App lock

@MainActor
final class AppLock: ObservableObject {
    @AppStorage("appLockEnabled") var enabled = false
    @Published var locked = false

    var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var canUse: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func lockIfNeeded() { if enabled { locked = true } }

    func unlock() async {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Passcode"
        let ok = (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your Crown progress photos")) ?? false
        if ok { withAnimation(.easeOut(duration: 0.35)) { locked = false } }
    }

    /// Confirms identity before turning the lock on, so it can't lock someone out.
    func enable() async -> Bool {
        let ok = (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Turn on app lock for Crown")) ?? false
        if ok { enabled = true }
        return ok
    }
}

struct LockScreen: View {
    @EnvironmentObject private var lock: AppLock
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 22) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.goldGradient)
                Text("Crown is locked").font(Typo.title)
                Text("Your progress photos are protected.")
                    .font(Typo.callout).foregroundStyle(Theme.secondary)
                Button("Unlock with \(lock.biometryName)") { Task { await lock.unlock() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
            }
        }
        .task { await lock.unlock() }
    }
}
