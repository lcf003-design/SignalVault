import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account] // Mission 42
    
    // API Key State
    @State private var apiKeyInput: String = ""
    @State private var secretInput: String = ""
    
    // Simulation Settings
    @AppStorage("isRealisticSlippageEnabled") private var isRealisticSlippageEnabled = false
    
    // UI State
    @State private var isCredentialsSaved = false
    @State private var isVerifying = false
    @State private var verificationMessage = ""
    @State private var isVerified = false
    
    // System Health (Mocked for now, but wired for future logic)
    @State private var isSocketConnected = true
    @State private var isCloudSyncActive = true
    
    // ... verification logic ...
    
    @MainActor
    private func verifyKey() {
        isVerifying = true
        verificationMessage = ""
        
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            isVerifying = false
            return
        }
        
        Task {
            // Check Tickers Endpoint (Usually always accessible if key is valid)
            let urlString = "https://api.polygon.io/v3/reference/tickers?active=true&limit=1&apiKey=\(key)"
            guard let url = URL(string: urlString) else {
                isVerifying = false
                return
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResp = response as? HTTPURLResponse {
                    if httpResp.statusCode == 200 {
                        isVerified = true
                        verificationMessage = "✅ Key Valid! (Access Granted)"
                        HapticManager.shared.playSuccess()
                    } else {
                        isVerified = false
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let reason = (json?["error"] as? String) ?? (json?["message"] as? String) ?? "Unknown"
                        
                        if httpResp.statusCode == 401 {
                            verificationMessage = "🚫 Invalid Key (401): \(reason)"
                        } else if httpResp.statusCode == 403 {
                            verificationMessage = "🚫 Access Denied (403): \(reason). Check entitlements."
                        } else {
                            verificationMessage = "⚠️ Error \(httpResp.statusCode): \(reason)"
                        }
                    }
                }
            } catch {
                verificationMessage = "⚠️ Network Error: \(error.localizedDescription)"
            }
            isVerifying = false
        }
    }
    
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
                Section("Data Provider: Massive (Polygon)") {
                    VStack(alignment: .leading) {
                        Text("Massive API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter Massive/Polygon Key", text: $apiKeyInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .submitLabel(.done)
                            .onSubmit {
                                Secrets.polygonAPIKey = apiKeyInput
                            }
                    }
                    
                    if !verificationMessage.isEmpty {
                        Text(verificationMessage)
                            .font(.caption)
                            .foregroundStyle(isVerified ? .green : .red)
                    }
                    
                    Link("Get Massive API Key (Use Free Default)", destination: URL(string: "https://polygon.io")!) 
                        .font(.caption)
                    
                    HStack {
                         Button {
                            print("🔘 Verify Button Tapped")
                            Secrets.polygonAPIKey = apiKeyInput // Save
                            HapticManager.shared.playToggleHaptic()
                            verifyKey()
                         } label: {
                             if isVerifying {
                                 ProgressView()
                             } else {
                                 Text("Verify & Save")
                                     .frame(maxWidth: .infinity)
                             }
                         }
                         .buttonStyle(.borderedProminent)
                         .disabled(apiKeyInput.isEmpty || isVerifying)
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
                // Pre-fill input
                apiKeyInput = Secrets.polygonAPIKey
                // secretInput unused for Massive
            }
        }
    }
}
