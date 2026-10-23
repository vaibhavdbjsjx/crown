import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = "crown.pro.yearly"
    @State private var showPrivacy = false
    @State private var appeared = false

    private var selected: Product? { store.products.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Theme.goldGradient)
                            .shadow(color: Theme.gold.opacity(0.5), radius: 20)
                            .scaleEffect(appeared ? 1 : 0.6)
                        Text("Crown Pro").font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("See what's really changing, month after month.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        feature("camera.viewfinder", "Unlimited monthly check-ins", "Guided scans with your last photo as an alignment guide")
                        feature("chart.line.uptrend.xyaxis", "Full history and trend line", "Every scan, every measurement, over time")
                        feature("rectangle.split.2x1.fill", "Compare and timelapse", "Slider comparisons and animated progress")
                        feature("checklist", "Routine tracking with streaks", "Daily and weekly steps, all in one place")
                    }
                    .card()

                    plans

                    if let message = store.message {
                        Text(message).font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.gold).multilineTextAlignment(.center)
                    }

                    Button {
                        guard let selected else { return }
                        Task {
                            await store.purchase(selected)
                            if store.isPro { dismiss() }
                        }
                    } label: {
                        if store.purchasing { ProgressView().tint(.black) } else { Text(ctaTitle) }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: selected != nil))
                    .disabled(selected == nil || store.purchasing)

                    Text(disclosure)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.tertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 18) {
                        Button("Restore") { Task { await store.restore(); if store.isPro { dismiss() } } }
                        Link("Terms of Use", destination: Legal.termsURL)
                        Button("Privacy Policy") { showPrivacy = true }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Theme.secondary) }
                        .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyPolicyView() } }
            .onAppear {
                store.message = nil
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            VStack(spacing: 12) {
                if store.loadFailed {
                    Text("Couldn't load plans from the App Store.").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.secondary)
                    Button("Try again") { Task { await store.loadProducts() } }.buttonStyle(SecondaryButtonStyle())
                } else {
                    ProgressView().tint(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 10) {
                if let yearly = store.yearly { planRow(yearly, badge: savingsBadge) }
                if let weekly = store.weekly { planRow(weekly, badge: trialText(weekly)) }
            }
        }
    }

    private func planRow(_ product: Product, badge: String?) -> some View {
        let isSelected = product.id == selectedID
        return Button { withAnimation(.spring(response: 0.3)) { selectedID = product.id } } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(isSelected ? Theme.gold : Theme.tertiary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.id == "crown.pro.yearly" ? "Yearly" : "Weekly").font(.system(.headline, design: .rounded))
                    Text("\(product.displayPrice) per \(product.id == "crown.pro.yearly" ? "year" : "week")")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                if let badge {
                    Text(badge).font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.goldGradient, in: Capsule())
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.stroke), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var savingsBadge: String? {
        guard let yearly = store.yearly, let weekly = store.weekly else { return nil }
        let weeklyYear = weekly.price * 52
        guard weeklyYear > 0 else { return nil }
        let saving = (1 - NSDecimalNumber(decimal: yearly.price / weeklyYear).doubleValue) * 100
        return saving >= 5 ? "Save \(Int(saving))%" : nil
    }

    private func trialText(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return "\(periodText(offer.period)) free"
    }

    private func periodText(_ p: Product.SubscriptionPeriod) -> String {
        switch p.unit {
        case .day: "\(p.value)-day"
        case .week: "\(p.value)-week"
        case .month: "\(p.value)-month"
        case .year: "\(p.value)-year"
        @unknown default: "Trial"
        }
    }

    private var ctaTitle: String {
        if let selected, let trial = trialText(selected) { return "Start \(trial) trial" }
        return "Continue"
    }

    private var disclosure: String {
        guard let selected else { return "" }
        let period = selected.id == "crown.pro.yearly" ? "year" : "week"
        var text = "\(selected.displayPrice) per \(period)"
        if let trial = trialText(selected) { text = "\(trial.capitalized) trial, then " + text }
        return text + ". Payment is charged to your Apple ID. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel any time in your App Store account settings."
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.gold).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail).font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.secondary)
            }
        }
    }
}
