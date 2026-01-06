import SwiftUI
import SwiftData

@main
struct SignalVaultApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ SwiftData Error: \(error). Attempting Destructive Reset...")
            // Fallback: Delete store and recreate (Dev only)
             let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appending(path: "default.store")
             try? FileManager.default.removeItem(at: url)
             try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
             try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
             
             do {
                 return try ModelContainer(for: schema, configurations: [modelConfiguration])
             } catch {
                 fatalError("Could not create ModelContainer after reset: \(error)")
             }
        }
    }()

    // Shared Market Service
    @State private var marketService: MarketDataProvider = {
        // Mission 43: Auto-Switch to Alpaca
        if !Secrets.alpacaAPIKeyID.isEmpty {
            return LiveMarketService()
        } else {
            return MockMarketService()
        }
    }()
    
    // Risk Monitor
    @State private var riskMonitor: RiskMonitorActor?

    var body: some Scene {
        WindowGroup {
            ContentView(marketService: marketService, riskMonitor: riskMonitor)
                .task {
                    // Initialize Risk Monitor with Container
                    if riskMonitor == nil {
                        let monitor = RiskMonitorActor(marketService: marketService, modelContainer: sharedModelContainer)
                        await monitor.startMonitoring()
                        riskMonitor = monitor
                    }
                    
                    // Apply Daily Decay (Simulating Overnight)
                    let decayService = ThetaDecayService(modelContainer: sharedModelContainer)
                    try? await decayService.applyDailyDecay()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
