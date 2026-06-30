import Foundation
import StoreKit

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published var purchaseError: String?
    @Published var purchaseMessage: String?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false

    let productIDs = [
        "com.indie.visaphotomaker.pro.lifetime"
    ]

    private var transactionUpdatesTask: Task<Void, Never>?
    private var isObservingTransactions = false

    private init() {}

    private func startObservingTransactionsIfNeeded() {
        guard !isObservingTransactions else { return }
        isObservingTransactions = true
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(update),
                   self.productIDs.contains(transaction.productID) {
                    self.purchasedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    var hasProAccess: Bool {
        !purchasedProductIDs.isEmpty
    }

    func loadProducts() async {
        startObservingTransactionsIfNeeded()
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: productIDs).sorted { $0.price < $1.price }
            await updatePurchases()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        startObservingTransactionsIfNeeded()
        purchaseError = nil
        purchaseMessage = nil
        guard !hasProAccess else {
            purchaseMessage = L10n.text(en: "Lifetime unlock is already active.", zh: "终身版已解锁。")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            AnalyticsService.logPurchaseStart(productID: product.id)
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                purchaseMessage = L10n.text(en: "Lifetime unlock is active.", zh: "已解锁终身版。")
                AnalyticsService.logPurchaseSuccess(productID: transaction.productID)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            AnalyticsService.logPurchaseFailure(productID: product.id, error: error.localizedDescription)
        }
    }

    func restore() async {
        startObservingTransactionsIfNeeded()
        purchaseError = nil
        purchaseMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await updatePurchases()
            purchaseMessage = hasProAccess
                ? (L10n.text(en: "Purchase restored.", zh: "购买已恢复。"))
                : (L10n.text(en: "No previous purchase was found.", zh: "没有找到可恢复的购买。"))
            AnalyticsService.logRestorePurchase(hasProAccess: hasProAccess)
        } catch {
            purchaseError = error.localizedDescription
            AnalyticsService.logPurchaseFailure(productID: nil, error: error.localizedDescription)
        }
    }

    func updatePurchases() async {
        startObservingTransactionsIfNeeded()
        var purchased = Set<String>()
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               productIDs.contains(transaction.productID) {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
