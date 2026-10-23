import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var scans: [Scan]
    @Query private var routine: [RoutineItem]
    @State private var showPaywall = false
    @State private var manageSubscriptions = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Crown Pro") {
                    if store.isPro {
                        Label("Crown Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.gold)
                        Button("Manage subscription") { manageSubscriptions = true }
                    } else {
                        Button { showPaywall = true } label: { Label("Upgrade to Crown Pro", systemImage: "crown.fill") }
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                    if let message = store.message {
                        Text(message).font(.footnote).foregroundStyle(Theme.secondary)
                    }
                }
                Section {
                    NavigationLink { PrivacyPolicyView() } label: { Label("Privacy Policy", systemImage: "hand.raised.fill") }
                    Link(destination: Legal.termsURL) { Label("Terms of Use", systemImage: "doc.text.fill") }
                    NavigationLink { AboutView() } label: { Label("How Crown measures", systemImage: "info.circle.fill") }
                } header: {
                    Text("About")
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete all scans and data", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Photos and measurements live only on this iPhone and are excluded from iCloud backups. Deleting removes them permanently.")
                }
                Section {
                    Text(Legal.disclaimer).font(.footnote).foregroundStyle(Theme.secondary)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0").foregroundStyle(Theme.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .confirmationDialog("Delete all scans, photos and routine history? This can't be undone.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive, action: deleteAll)
            }
            .onAppear { store.message = nil }
        }
    }

    private func deleteAll() {
        scans.forEach { context.delete($0) }
        routine.forEach { context.delete($0) }
        try? context.save()
        PhotoStore.deleteAll()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Last updated October 2026").font(.footnote).foregroundStyle(Theme.tertiary)
                block("Summary", "Crown is designed so your photos never leave your iPhone. We don't run servers that receive your data, we don't have accounts, and we don't use analytics or advertising SDKs.")
                block("Photos", "Progress photos you take or import are saved in Crown's private storage on your device. They are excluded from iCloud backups and are never uploaded, shared or sold. You can delete any scan, or all data, at any time in the app.")
                block("Analysis", "Hairline, temple and crown estimates are calculated on your iPhone using Apple's Vision framework. No image or measurement is sent to us or any third party.")
                block("Camera", "Crown asks for camera access only to take progress photos. You can turn access off in iOS Settings and import photos from your library instead; Crown only receives the specific photo you choose.")
                block("Purchases", "Subscriptions are processed by Apple. We never see your payment details. Apple may share anonymized purchase information with us as described in Apple's privacy policy.")
                block("Sharing", "Progress cards you choose to share contain only your score, stage and number of scans, never your photos. Sharing happens through the iOS share sheet to apps you pick.")
                block("Children", "Crown is not directed at children under 13.")
                block("Changes", "If this policy changes, the updated version will appear in the app with a new date.")
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .rounded))
            Text(text).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.secondary)
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                item("Hairline position", "Crown finds your brows and chin, samples your forehead skin tone, then measures how far above your brows the hairline begins. It's shown relative to your face so distance from the camera doesn't matter.")
                item("Temple recession", "The same measurement is taken above the outer corners of your eyes and compared with the centre. Higher temples than midline indicates recession.")
                item("Crown density", "In the crown photo, Crown estimates how much of the central area shows scalp versus hair, using your skin tone from the front photo.")
                item("Stage", "Scores are combined into a 1 to 7 scale modelled on the Norwood pattern so you can follow a trend. It's an estimate from photos, not a clinical grading.")
                item("Getting reliable results", "Scan in the same spot and light each month, pull hair back from your forehead, and use the outline and last-scan guide. Lighting and styling changes affect readings more than a month of real change.")
                Text(Legal.disclaimer).font(.footnote).foregroundStyle(Theme.tertiary)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("How Crown measures")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .rounded))
            Text(text).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.secondary)
        }
    }
}
