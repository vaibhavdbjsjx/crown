import StoreKit
import SwiftData
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var account: Account
    @EnvironmentObject private var lock: AppLock
    @Environment(\.modelContext) private var context
    @Query(sort: \Scan.date) private var scans: [Scan]
    @Query private var routine: [RoutineItem]
    @Query private var journal: [JournalEntry]
    @Query private var sheds: [ShedLog]

    @AppStorage("remindCheckIn") private var remindCheckIn = false
    @AppStorage("remindRoutine") private var remindRoutine = false
    @AppStorage("routineMinutes") private var routineMinutes = 21 * 60
    @State private var showPaywall = false
    @State private var manageSubscriptions = false
    @State private var confirmDeleteData = false
    @State private var confirmDeleteAccount = false
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var shown = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        identity.padding(.top, 12).reveal(shown)
                        membership.reveal(shown, index: 1)
                        reminders.reveal(shown, index: 2)
                        privacy.reveal(shown, index: 3)
                        about.reveal(shown, index: 4)
                        if account.isSignedIn { accountSection.reveal(shown, index: 5) }
                        Text("Crown \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · Made for people who'd rather know.")
                            .font(Typo.caption).foregroundStyle(Theme.tertiary)
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Your name", isPresented: $editingName) {
                TextField("Name", text: $nameDraft)
                Button("Save") { account.updateName(nameDraft) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete all scans, photos, journal and routine history? This can't be undone.",
                                isPresented: $confirmDeleteData, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) { deleteAllData() }
            }
            .confirmationDialog("Delete your Crown account? This signs you out and permanently erases all scans, photos and history on this iPhone.",
                                isPresented: $confirmDeleteAccount, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    deleteAllData()
                    account.signOut()
                }
            }
        }
        .onAppear {
            shown = true
            store.message = nil
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var identity: some View {
        if let p = account.profile {
            HStack(spacing: 16) {
                Text(initials(p.name))
                    .font(Typo.display(24))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 64, height: 64)
                    .background(Theme.goldGradient, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name.isEmpty ? "Crown member" : p.name).font(Typo.display(28))
                    if let email = p.email { Text(email).font(Typo.subhead).foregroundStyle(Theme.secondary) }
                    Label(p.provider == .apple ? "Signed in with Apple" : "Signed in with Gmail",
                          systemImage: p.provider == .apple ? "apple.logo" : "envelope.fill")
                        .font(Typo.micro).foregroundStyle(Theme.tertiary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                stat("\(scans.count)", "Scans")
                stat("\(max(0, Calendar.current.dateComponents([.day], from: p.joined, to: Date()).day ?? 0))", "Days")
                stat("\(routine.map(\.streak).max() ?? 0)", "Streak")
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Your account")
                Text("Make Crown yours.").font(Typo.display(34))
                Text("Sign in to personalise the app and put your name on doctor reports. Photos always stay on this iPhone.")
                    .font(Typo.subhead).foregroundStyle(Theme.secondary).padding(.bottom, 8)
                SignInButtons()
            }
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(Typo.numeral(26, weight: .regular))
            Eyebrow(label)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14, radius: 20)
    }

    private var membership: some View {
        Button {
            if store.isPro { manageSubscriptions = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "crown.fill").font(.system(size: 22)).foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isPro ? "Crown Pro" : "Upgrade to Crown Pro").font(Typo.title2).foregroundStyle(Theme.ivory)
                    Text(store.isPro ? "Active · Manage subscription" : "Unlimited scans, history, timelapse, reports")
                        .font(Typo.caption).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tertiary)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.champagne.opacity(0.16), Theme.ink2.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.champagne.opacity(0.3)))
        }
        .buttonStyle(PressableStyle())
    }

    private var reminders: some View {
        SettingsGroup(title: "Reminders") {
            ToggleRow(symbol: "calendar.badge.clock", title: "Monthly check-in", isOn: $remindCheckIn)
                .onChange(of: remindCheckIn) { _, on in
                    Task {
                        if on { _ = await Reminders.requestPermission() }
                        Reminders.scheduleCheckIn(after: scans.last?.date)
                    }
                }
            Divider2()
            ToggleRow(symbol: "bell", title: "Daily routine", isOn: $remindRoutine)
                .onChange(of: remindRoutine) { _, on in
                    Task {
                        if on { _ = await Reminders.requestPermission() }
                        Reminders.scheduleRoutine()
                    }
                }
            if remindRoutine {
                Divider2()
                HStack {
                    RowLabel(symbol: "clock", title: "Remind me at")
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { Calendar.current.date(bySettingHour: routineMinutes / 60, minute: routineMinutes % 60, second: 0, of: Date()) ?? Date() },
                        set: { d in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                            routineMinutes = (c.hour ?? 21) * 60 + (c.minute ?? 0)
                            Reminders.scheduleRoutine()
                        }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var privacy: some View {
        SettingsGroup(title: "Privacy & security") {
            ToggleRow(symbol: "faceid", title: "Lock with \(lock.biometryName)", isOn: Binding(
                get: { lock.enabled },
                set: { on in
                    if on { Task { _ = await lock.enable() } } else { lock.enabled = false }
                }))
                .disabled(!lock.canUse)
            Divider2()
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "iphone.gen3").font(.system(size: 15)).foregroundStyle(Theme.champagne).frame(width: 24)
                Text("Photos and measurements live only on this iPhone and are excluded from iCloud backups.")
                    .font(Typo.caption).foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, 10)
            Divider2()
            Button { confirmDeleteData = true } label: { RowLabel(symbol: "trash", title: "Delete all data", tint: Theme.rose) }
                .padding(.vertical, 12)
        }
    }

    private var about: some View {
        SettingsGroup(title: "About") {
            NavigationLink { AboutView() } label: { LinkRow(symbol: "ruler", title: "How Crown measures") }
            Divider2()
            NavigationLink { PrivacyPolicyView() } label: { LinkRow(symbol: "hand.raised", title: "Privacy Policy") }
            Divider2()
            Link(destination: Legal.termsURL) { LinkRow(symbol: "doc.text", title: "Terms of Use", external: true) }
            Divider2()
            Button { Task { await store.restore() } } label: { LinkRow(symbol: "arrow.clockwise", title: "Restore purchases") }
            if let message = store.message {
                Text(message).font(Typo.caption).foregroundStyle(Theme.champagne).padding(.bottom, 8)
            }
        }
    }

    private var accountSection: some View {
        SettingsGroup(title: "Account") {
            Button {
                nameDraft = account.profile?.name ?? ""
                editingName = true
            } label: { LinkRow(symbol: "pencil", title: "Edit name") }
            Divider2()
            Button { account.signOut() } label: { LinkRow(symbol: "rectangle.portrait.and.arrow.right", title: "Sign out") }
            Divider2()
            Button { confirmDeleteAccount = true } label: { RowLabel(symbol: "person.crop.circle.badge.xmark", title: "Delete account", tint: Theme.rose) }
                .padding(.vertical, 12)
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "C" : String(parts).uppercased()
    }

    private func deleteAllData() {
        scans.forEach { context.delete($0) }
        routine.forEach { context.delete($0) }
        journal.forEach { context.delete($0) }
        sheds.forEach { context.delete($0) }
        try? context.save()
        PhotoStore.deleteAll()
        Reminders.scheduleCheckIn(after: nil)
    }
}

// MARK: - Rows

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title).padding(.leading, 6)
            VStack(spacing: 0) { content }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.ink2.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.edgeGradient))
        }
    }
}

struct RowLabel: View {
    let symbol: String
    let title: String
    var tint: Color = Theme.ivory
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(tint == Theme.ivory ? Theme.champagne : tint).frame(width: 24)
            Text(title).font(Typo.callout).foregroundStyle(tint)
        }
    }
}

struct LinkRow: View {
    let symbol: String
    let title: String
    var external = false
    var body: some View {
        HStack {
            RowLabel(symbol: symbol, title: title)
            Spacer()
            Image(systemName: external ? "arrow.up.right" : "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct ToggleRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) { RowLabel(symbol: symbol, title: title) }
            .tint(Theme.champagne)
            .padding(.vertical, 10)
    }
}

// MARK: - Legal

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            AppBackground(intensity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy").font(Typo.display(34))
                    Text("Last updated October 2026").font(Typo.caption).foregroundStyle(Theme.tertiary)
                    block("In short", "Crown is built so your photos never leave your iPhone. There's no Crown server that receives your data, and no analytics or advertising SDKs.")
                    block("Photos", "Progress photos you take or import are saved in Crown's private storage on your device, excluded from iCloud backups, and never uploaded, shared or sold. You can delete any scan, or all data, at any time.")
                    block("Analysis", "Hairline, temple and crown estimates are calculated on your iPhone using Apple's Vision framework. No image or measurement is sent to us or to anyone else.")
                    block("Sign-in", "If you sign in with Apple or Gmail, Crown receives your name, email address and an account identifier from Apple or Google. These are stored only in this iPhone's Keychain and used to personalise the app and your reports. Crown never sees your password. You can sign out or delete your account in the You tab.")
                    block("Camera and notifications", "Camera access is used only to take progress photos. Reminders are local notifications scheduled on your device. You can turn either off in iOS Settings.")
                    block("Purchases", "Subscriptions are processed by Apple. Crown never sees your payment details.")
                    block("Sharing", "Progress cards you share contain only your score, stage and number of scans, never your photos. PDF reports are created on your device and shared only where you choose.")
                    block("Children", "Crown is not directed at children under 13.")
                    block("Changes", "If this policy changes, the updated version will appear here with a new date.")
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typo.title2)
            Text(text).font(Typo.subhead).foregroundStyle(Theme.secondary).lineSpacing(3)
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            AppBackground(intensity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Crown\nmeasures").font(Typo.display(34))
                    item("01", "Hairline position", "Crown finds your brows and chin, samples your forehead skin tone, then measures how far above your brows the hairline begins. It's relative to your face, so distance from the camera doesn't matter.")
                    item("02", "Temple recession", "The same measurement above the outer corners of your eyes, compared with the centre. Temples sitting higher than the midline indicates recession.")
                    item("03", "Crown density", "In the crown photo, Crown estimates how much of the central area shows scalp versus hair, using your skin tone from the front photo.")
                    item("04", "Photo quality", "Each scan is graded on light, evenness, sharpness and head angle. Low-quality scans are flagged so you don't mistake lighting for change.")
                    item("05", "Stage", "Scores combine into a I–VII scale modelled on the Norwood pattern so you can follow a trend. It's an estimate from photos, not a clinical grading.")
                    Text(Legal.disclaimer).font(Typo.caption).foregroundStyle(Theme.tertiary)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(n).font(Typo.numeral(22)).foregroundStyle(Theme.goldGradient)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Typo.title2)
                Text(text).font(Typo.subhead).foregroundStyle(Theme.secondary).lineSpacing(3)
            }
        }
    }
}
