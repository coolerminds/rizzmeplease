import Foundation

protocol PurchaseService {
    func purchase(pack: TokenPack) async throws -> Int
}

struct StubPurchaseService: PurchaseService {
    func purchase(pack: TokenPack) async throws -> Int {
        // Simulate slight latency to mirror StoreKit user flow.
        try await Task.sleep(nanoseconds: 300_000_000)
        return pack.amount
    }
}
