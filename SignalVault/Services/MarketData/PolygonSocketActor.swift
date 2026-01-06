import Foundation

actor PolygonSocketActor {
    static let shared = PolygonSocketActor()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var isConnected = false
    private var reconnectAttempts = 0
    
    private var isAuthFailed = false
    
    // Stream continuation
    private var tickContinuation: AsyncStream<MarketTick>.Continuation?
    
    init() {
        self.session = URLSession(configuration: .default)
    }
    
    func registerContinuation(_ continuation: AsyncStream<MarketTick>.Continuation) {
        self.tickContinuation = continuation
    }
    
    func connect() {
        // Reset state on explicit connect
        isAuthFailed = false
        guard !isConnected else { return }
        
        print("🔌 Connecting to Polygon via Socket...")
        let url = URL(string: "wss://socket.polygon.io/stocks")! // Default to Stocks cluster
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
    
    func subscribe(symbols: [String], apiKey: String) async {
        guard !isAuthFailed else {
            print("🚫 Skipping subscription: Auth previously failed.")
            return
        }
        
        // 1. Authenticate
        let authMessage = "{\"action\":\"auth\",\"params\":\"\(apiKey)\"}"
        try? await send(text: authMessage)
        
        // 2. Subscribe (Trades)
        let params = symbols.map { "T.\($0)" }.joined(separator: ",")
        let subMessage = "{\"action\":\"subscribe\",\"params\":\"\(params)\"}"
        try? await send(text: subMessage)
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
                    print("❌ Socket Error: \(error)")
                    await self.handleDisconnection()
                }
            }
        }
    }
    
    private func handle(message: URLSessionWebSocketTask.Message) {
        // Decode JSON
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }
        
        do {
            let messages = try JSONDecoder().decode([PolygonMessage].self, from: data)
            
            for msg in messages {
                if let tick = msg.toMarketTick() {
                    tickContinuation?.yield(tick)
                } else if case .status(let status) = msg {
                    print("ℹ️ Polygon Status: \(status.status) - \(status.message)")
                    
                    if status.status == "auth_failed" {
                        self.isAuthFailed = true
                        print("🚫 Stopping Polygon Socket Reconnection due to Auth Failure.")
                        self.disconnect()
                    }
                }
            }
        } catch {
            print("⚠️ Decode Error: \(error)")
        }
    }
    
    private func handleDisconnection() async {
        isConnected = false
        
        if isAuthFailed {
            print("🛑 Socket Disconnected. Will NOT reconnect due to Auth Failure.")
            return
        }
        
        print("⚠️ Socket Disconnected. Reconnecting...")
        try? await Task.sleep(for: .seconds(2))
        connect()
    }
}
