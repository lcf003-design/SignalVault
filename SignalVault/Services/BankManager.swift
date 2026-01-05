import Foundation
import SwiftData

@MainActor
class BankManager {
    static let shared = BankManager()
    
    private init() {}
    
    func ensureAccountExists(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        do {
            let count = try modelContext.fetchCount(descriptor)
            if count == 0 {
                let newAccount = Account(startingCapital: 100_000.0)
                modelContext.insert(newAccount)
                try modelContext.save()
                print("Vault Initialized: $100,000.00 deposited.")
            }
        } catch {
            print("Failed to fetch or create account: \(error)")
        }
    }
}
