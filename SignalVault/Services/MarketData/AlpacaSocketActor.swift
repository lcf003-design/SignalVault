import Foundation

actor AlpacaSocketActor {
    static let shared = AlpacaSocketActor()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var isConnected = false
    private var reconnectAttempts = 0
    private var isAuthFailed = false
    
    // Stream continuation
    private var tickContinuation: AsyncStream<MarketTick>.Continuation?
    
    // Alpaca uses IEX feed for free tier
    private let endpoint = "wss://stream.data.alpaca.markets/v2/iex"
    
    init() {
        self.session = URLSession(configuration: .default)
    }
    
    func registerContinuation(_ continuation: AsyncStream<MarketTick>.Continuation) {
        self.tickContinuation = continuation
    }
    
    func connect() {
        isAuthFailed = false
        guard !isConnected else { return }
        
        print("🦙 Connecting to Alpaca (IEX)...")
        guard let url = URL(string: endpoint) else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        reconnectAttempts = 0
    }
    
    func subscribe(symbols: [String], keyID: String, secretKey: String) async {
        guard !isAuthFailed else { return }
        
        // 1. Authenticate
        // Format: { "action": "auth", "key": "...", "secret": "..." }
        let authMsg = """
        {"action": "auth", "key": "\(keyID)", "secret": "\(secretKey)"}
        """
        try? await send(text: authMsg)
        
        // Wait briefly for auth confirmation (Alpaca sends "authenticated")
        try? await Task.sleep(for: .seconds(1))
        
        // 2. Subscribe
        // Format: { "action": "subscribe", "trades": ["AAPL", ...] }
        let symbolList = symbols.map { "\"\($0)\"" }.joined(separator: ",")
        let subMsg = """
        {"action": "subscribe", "trades": [\(symbolList)]}
        """
        try? await send(text: subMsg)
    }
    
    private func send(text: String) async throws {
        let message = URLSessionWebSocketTask.Message.string(text)
        try await webSocketTask?.send(message)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            Task {
                switch result {
                case .success(let message):
                    await self.handle(message: message)
                    await self.receiveMessage() // Loop
                case .failure(let error):
                    print("❌ Alpaca Socket Error: \(error)")
                    await self.handleDisconnection()
                }
            }
        }
    }
    
    private func handle(message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }
        
        // Alpaca sends Arrays of messages: [{"T":"t", ...}, {"T":"success", ...}]
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for msg in jsonArray {
                    processMessage(msg)
                }
            }
        } catch {
            print("⚠️ Alpaca Decode Error: \(error)")
        }
    }
    
    private func processMessage(_ msg: [String: Any]) {
        guard let type = msg["T"] as? String else { return }
        
        switch type {
        case "success":
            if let result = msg["msg"] as? String, result == "authenticated" {
                print("✅ Alpaca: Authenticated")
            }
            
        case "error":
            if let code = msg["code"] as? Int, code == 402 {
                print("🚫 Alpaca: Auth Failed (Check Keys)")
                self.isAuthFailed = true
                self.disconnect()
            }
            
        case "t": // Trade
            // Alpaca Trade Format: {"T":"t", "S":"AAPL", "p":150.0, "s":100, ...}
            if let symbol = msg["S"] as? String,
               let price = msg["p"] as? Double,
               let size = msg["s"] as? Double { // size = volume
                
                let tick = MarketTick(symbol: symbol, price: price, volume: size, timestamp: Date())
                tickContinuation?.yield(tick)
            }
            
        case "subscription":
            print("✅ Alpaca: Subscribed")
            
        default:
            break
        }
    }
    
    private func handleDisconnection() async {
        isConnected = false
        if isAuthFailed { return }
        print("⚠️ Reconnecting Alpaca...")
        try? await Task.sleep(for: .seconds(2))
        connect()
    }
}
