import SwiftUI
import SwiftData

@main
struct SignalVaultApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            Position.self,
            SignalLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Shared Market Service
    @State private var marketService: MarketDataProvider = {
        if Secrets.polygonAPIKey != "YOUR_POLYGON_API_KEY" && !Secrets.polygonAPIKey.isEmpty {
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
