import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account] // Mission 42
    
    // API Key State
    @State private var apiKeyInput: String = ""
    
    // Simulation Settings
    @AppStorage("isRealisticSlippageEnabled") private var isRealisticSlippageEnabled = false
    
    // System Health (Mocked for now, but wired for future logic)
    @State private var isSocketConnected = true
    @State private var isCloudSyncActive = true
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: System Health
                Section("System Health") {
                    HStack {
                        Label("Market Data Feed", systemImage: "network")
                        Spacer()
                        Text(isSocketConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(isSocketConnected ? .green : .red)
                    }
                    
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text(isCloudSyncActive ? "Active" : "Disabled")
                            .foregroundStyle(isCloudSyncActive ? .green : .orange)
                    }
                }
                
                // Section 2: API Configuration
                Section("Data Provider") {
                    VStack(alignment: .leading) {
                        Text("Polygon.io API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        SecureField("Enter your API Key", text: $apiKeyInput)
                            .textContentType(.password)
                            .onSubmit {
                                Secrets.polygonAPIKey = apiKeyInput
                            }
                    }
                    
                    if apiKeyInput != "wANBaTZQHpr3h8T9BjrOpRpiCb9W20S1" && !apiKeyInput.isEmpty {
                         Button("Restore Default Key") {
                             apiKeyInput = ""
                             Secrets.polygonAPIKey = "" // Resets to default
                         }
                         .foregroundStyle(.red)
                    }
                }
                
                // Section 3: Social & Privacy (Mission 23)
                Section("Social Alpha") {
                    Toggle("Share Stats Publicly", isOn: .constant(false)) // MVP: Static toggle for now or wired to UserDefaults later
                        .tint(.purple)
                    
                    Text("Participate in the Global Leaderboard. Your P&L and Win Rate will be visible anonymously.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Mission 42: Safety Lock (The Guardian)
                if let account = accounts.first {
                    Section("Safety Lock (The Guardian)") {
                        Toggle("Max Daily Loss Protection", isOn: Bindable(account).isSafetyLockEnabled)
                            .tint(.red)
                        
                        if account.isSafetyLockEnabled {
                            VStack(alignment: .leading) {
                                Stepper(value: Bindable(account).maxDailyLossPercent, in: 0.01...0.20, step: 0.01) {
                                    HStack {
                                        Text("Max Daily Loss")
                                        Spacer()
                                        Text(account.maxDailyLossPercent, format: .percent.precision(.fractionLength(1)))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.red)
                                    }
                                }
                                Text("Trading will be disabled if session loss exceeds \(account.startingCapital * account.maxDailyLossPercent, format: .currency(code: "USD")).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                
                // Section 4: Simulation Control
                Section("Sandbox Configuration") {
                    Toggle("Realistic Slippage (0.05%)", isOn: $isRealisticSlippageEnabled)
                    
                    Button(role: .destructive) {
                        Task { @MainActor in
                            try? BankManager.shared.resetAccount(modelContext: modelContext)
                            HapticManager.shared.playSuccess()
                        }
                    } label: {
                        Label("Reset Sandbox", systemImage: "trash")
                    }
                }
                
                // Section 4: Support
                Section("Support & Info") {
                    Link(destination: URL(string: "mailto:support@signalvault.app?subject=SignalVault%20Feedback%20(v1.0.0)")!) {
                        Label("Report Bug / Feedback", systemImage: "ladybug")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .addKeyboardDoneButton()
            .hideKeyboardOnTap()
            .onAppear {
                // Pre-fill input if it's not default
                let current = Secrets.polygonAPIKey
                if current != "wANBaTZQHpr3h8T9BjrOpRpiCb9W20S1" {
                    apiKeyInput = current
                }
            }
        }
    }
}
