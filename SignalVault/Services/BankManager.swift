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
    
    // Mission 11: Sandbox Reset
    func resetAccount(modelContext: ModelContext) throws {
        // 1. Delete all accounts
        try modelContext.delete(model: Account.self)
        // 2. Delete all positions (optional deep clean)
        try modelContext.delete(model: Position.self)
        try modelContext.delete(model: SignalLog.self)
        
        // 3. Re-initialize
        let newAccount = Account(startingCapital: 100_000.0)
        modelContext.insert(newAccount)
        try modelContext.save()
        print("🔄 SANDBOX RESET: Vault restored to $100,000.00")
    }
}
