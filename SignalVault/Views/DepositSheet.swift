import SwiftUI
import SwiftData

struct DepositSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let amounts: [Double] = [10_000, 50_000, 100_000]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "banknote")
                    .font(.system(size: 60))
                    .foregroundStyle(.green.gradient)
                    .padding()
                
                Text("Add Capital")
                    .font(.title2.bold())
                
                Text("Inject liquidity into your Sandbox Vault to increase buying power.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                ForEach(amounts, id: \.self) { amount in
                    Button(action: {
                        Task { @MainActor in
                            BankManager.shared.depositFunds(amount: amount, modelContext: modelContext)
                            HapticManager.shared.playSuccess()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Text("Deposit \(amount, format: .currency(code: "USD"))")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Vault Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
