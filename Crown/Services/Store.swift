import StoreKit
import SwiftUI

@MainActor
final class Store: ObservableObject {
    static let productIDs = ["crown.pro.weekly", "crown.pro.yearly"]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var loadFailed = false
    @Published var purchasing = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    init() {
        #if DEBUG
        if DemoData.isEnabled && !ProcessInfo.processInfo.arguments.contains("-paywall") { isPro = true }
        #endif
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updates?.cancel() }

    var weekly: Product? { products.first { $0.id == "crown.pro.weekly" } }
    var yearly: Product? { products.first { $0.id == "crown.pro.yearly" } }

    func loadProducts() async {
        loadFailed = false
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            loadFailed = loaded.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func refreshEntitlements() async {
        #if DEBUG
        if DemoData.isEnabled && !ProcessInfo.processInfo.arguments.contains("-paywall") { isPro = true; return }
        #endif
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    func purchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    message = "The purchase couldn't be verified. Please try again."
                }
            case .pending:
                message = "Your purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        purchasing = true
        defer { purchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "Crown Pro restored." : "No active subscription was found for this Apple ID."
        } catch {
            message = "Couldn't reach the App Store. Please try again."
        }
    }
}
