import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = "crown.pro.yearly"
    @State private var showPrivacy = false
    @State private var shown = false

    private var selected: Product? { store.products.first { $0.id == selectedID } }

    private let features: [(String, String, String)] = [
        ("viewfinder", "Unlimited check-ins", "Guided scans with last-scan alignment"),
        ("chart.xyaxis.line", "Full history & trend", "Every measurement, with journal markers"),
        ("rectangle.split.2x1", "Compare & timelapse", "Slider compare and animated progress"),
        ("doc.richtext", "Doctor-ready PDF", "A clean report for your dermatologist"),
        ("checklist", "Routine & shed tracking", "Streaks, adherence and shedding trends"),
    ]

    var body: some View {
        ZStack {
            AppBackground(intensity: 1.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        IconButton(symbol: "xmark", label: "Close") { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill").foregroundStyle(Theme.goldGradient)
                            Eyebrow("Crown Pro", color: Theme.champagne)
                        }
                        Text("See the full\npicture.")
                            .font(Typo.display(46))
                            .foregroundStyle(Theme.ivory)
                        Text("Know what's changing, month after month, with the tools that make progress obvious.")
                            .font(Typo.callout).foregroundStyle(Theme.secondary).lineSpacing(3)
                    }
                    .reveal(shown)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                            HStack(spacing: 14) {
                                Image(systemName: f.0).font(.system(size: 15)).foregroundStyle(Theme.champagne)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.champagne.opacity(0.09), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.1).font(Typo.headline)
                                    Text(f.2).font(Typo.caption).foregroundStyle(Theme.tertiary)
                                }
                            }
                            .reveal(shown, index: i + 1)
                        }
                    }
                    .card()

                    plans.reveal(shown, index: 6)

                    if let message = store.message {
                        Text(message).font(Typo.caption).foregroundStyle(Theme.champagne).frame(maxWidth: .infinity)
                    }

                    Button {
                        guard let selected else { return }
                        Task {
                            await store.purchase(selected)
                            if store.isPro { Haptics.success(); dismiss() }
                        }
                    } label: {
                        if store.purchasing { ProgressView().tint(Theme.ink) } else { Text(ctaTitle) }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: selected != nil))
                    .disabled(selected == nil || store.purchasing)

                    Text(disclosure)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 20) {
                        Button("Restore") { Task { await store.restore(); if store.isPro { dismiss() } } }
                        Link("Terms", destination: Legal.termsURL)
                        Button("Privacy") { showPrivacy = true }
                    }
                    .font(Typo.caption.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyPolicyView() } }
        .onAppear {
            store.message = nil
            shown = true
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            VStack(spacing: 12) {
                if store.loadFailed {
                    Text("Couldn't load plans from the App Store.").font(Typo.subhead).foregroundStyle(Theme.secondary)
                    Button("Try again") { Task { await store.loadProducts() } }.buttonStyle(SecondaryButtonStyle())
                } else {
                    ProgressView().tint(Theme.champagne)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        } else {
            VStack(spacing: 10) {
                if let yearly = store.yearly { planRow(yearly, title: "Yearly", badge: savingsBadge, perWeek: perWeek(yearly)) }
                if let weekly = store.weekly { planRow(weekly, title: "Weekly", badge: trialText(weekly).map { "\($0) free" }, perWeek: nil) }
            }
        }
    }

    private func planRow(_ product: Product, title: String, badge: String?, perWeek: String?) -> some View {
        let isSelected = product.id == selectedID
        return Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedID = product.id }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(isSelected ? Color.clear : Theme.tertiary, lineWidth: 1.5)
                    if isSelected {
                        Circle().fill(Theme.goldGradient)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(Typo.title2)
                        if let badge {
                            Text(badge.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.8)
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Theme.goldGradient, in: Capsule())
                        }
                    }
                    Text(perWeek ?? "Billed weekly").font(Typo.caption).foregroundStyle(Theme.tertiary)
                }
                Spacer()
                Text(product.displayPrice).font(Typo.numeral(22, weight: .regular))
            }
            .padding(18)
            .background(isSelected ? Theme.champagne.opacity(0.07) : Theme.ink2.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.edgeGradient), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func perWeek(_ yearly: Product) -> String {
        let weekly = yearly.price / 52
        return "Just \(weekly.formatted(yearly.priceFormatStyle)) per week, billed yearly"
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
        switch offer.period.unit {
        case .day: return "\(offer.period.value)-day"
        case .week: return "\(offer.period.value)-week"
        case .month: return "\(offer.period.value)-month"
        case .year: return "\(offer.period.value)-year"
        @unknown default: return nil
        }
    }

    private var ctaTitle: String {
        if let selected, let trial = trialText(selected) { return "Start \(trial) free trial" }
        return "Unlock Crown Pro"
    }

    private var disclosure: String {
        guard let selected else { return "" }
        let period = selected.id == "crown.pro.yearly" ? "year" : "week"
        var text = "\(selected.displayPrice) per \(period)"
        if let trial = trialText(selected) { text = "\(trial.capitalized) free trial, then " + text }
        return text + ". Charged to your Apple ID. Renews automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in your App Store account settings."
    }
}
