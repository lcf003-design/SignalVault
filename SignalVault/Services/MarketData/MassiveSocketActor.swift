import Foundation
import Combine

actor MassiveSocketActor {
    static let shared = MassiveSocketActor()
    
    // Polygon.io / Massive Endpoint
    private var endpoint = "wss://socket.polygon.io/stocks" // Default to Real-Time
    
    // ...
    
    private func switchToDelayedAndReconnect() async {
        self.endpoint = "wss://delayed.polygon.io/stocks"
        if let key = storedKey {
            // Reset flags
            isAuthFailed = false
            currentStatus = .connecting
            // Small delay
            try? await Task.sleep(for: .seconds(1))
            connect(apiKey: key)
        }
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    
    private var isConnected = false
    private var reconnectAttempts = 0
    private var isAuthFailed = false
    
    // Credentials for Reconnection
    private var storedKey: String?
    
    // continuous streams
    private var continuations: [UUID: AsyncStream<MarketTick>.Continuation] = [:]
    
    // Auto-Resubscribe tracking
    private var pendingSymbols: Set<String> = []
    
    public enum SocketStatus: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case authenticated
        case failed(String)
    }
    
    private var statusContinuations: [UUID: AsyncStream<SocketStatus>.Continuation] = [:]
    private(set) var currentStatus: SocketStatus = .disconnected {
        didSet {
            print("M▲SSIVE Socket Status: \(currentStatus)")
            for continuation in statusContinuations.values {
                continuation.yield(currentStatus)
            }
        }
    }
    
    init() {
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - Status Stream
    func statusStream() -> AsyncStream<SocketStatus> {
        AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            continuation.yield(currentStatus)
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in await self?.removeStatusContinuation(id: id) }
            }
        }
    }
    
    private func removeStatusContinuation(id: UUID) {
        statusContinuations.removeValue(forKey: id)
    }
    
    // MARK: - Tick Stream
    func registerContinuation(_ continuation: AsyncStream<MarketTick>.Continuation) -> UUID {
        let id = UUID()
        continuations[id] = continuation
        return id
    }
    
    func unregisterContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
    
    // MARK: - Connection
    func connect(apiKey: String) {
        self.storedKey = apiKey
        isAuthFailed = false
        
        guard !isConnected else { return }
        
        currentStatus = .connecting
        print("M▲SSIVE: Connecting to \(endpoint)...")
        
        guard let url = URL(string: endpoint) else {
            currentStatus = .failed("Invalid URL")
            return
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        currentStatus = .connected
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
        reconnectAttempts = 0
        currentStatus = .disconnected
    }
    
    func subscribe(symbols: [String]) async {
        guard !isAuthFailed, let key = storedKey else { return }
        
        // Anti-Race: Wait if authenticating
        if currentStatus != .authenticated {
             if isConnected {
                 print("🔐 Massive: Sending Auth...")
                 let authMsg = "{\"action\":\"auth\",\"params\":\"\(key)\"}"
                 try? await send(text: authMsg)
                 
                 var attempts = 0
                 while currentStatus != .authenticated && !isAuthFailed && isConnected && attempts < 20 {
                     try? await Task.sleep(for: .seconds(0.2))
                     attempts += 1
                 }
             }
        }
        
        guard currentStatus == .authenticated else { return }
        
        let valid = symbols.filter { !$0.isEmpty }
        guard !valid.isEmpty else { return }
        
        // Track symbols for reconnection
        valid.forEach { pendingSymbols.insert($0) }
        
        // Send Sub
        // T.* = Trades (Includes After Hours)
        // Q.* = Quotes
        let tradeParams = valid.map { "T.\($0)" }.joined(separator: ",")
        let quoteParams = valid.map { "Q.\($0)" }.joined(separator: ",")
        let allParams = "\(tradeParams),\(quoteParams)"
        
        print("📡 Massive: Subscribing to \(valid.count) symbols (Including Extended Hours)")
        let subMsg = "{\"action\":\"subscribe\",\"params\":\"\(allParams)\"}"
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
                    await self.receiveMessage()
                case .failure(let error):
                    print("❌ Massive Error: \(error)")
                    await self.updateStatus(.failed(error.localizedDescription))
                    await self.handleDisconnection()
                }
            }
        }
    }
    
    private func updateStatus(_ newStatus: SocketStatus) {
        self.currentStatus = newStatus
    }
    
    private func handle(message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }
        
        // Polygon sends Array of objects
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for msg in jsonArray {
                    processMessage(msg)
                }
            }
        } catch {
            print("⚠️ Massive Decode Error: \(error)")
        }
    }
    
    private func processMessage(_ msg: [String: Any]) {
        guard let type = msg["ev"] as? String else { return }
        
        switch type {
        case "status":
            // {"ev":"status","status":"auth_success","message":"authenticated"}
            if let status = msg["status"] as? String {
                if status == "auth_success" {
                    print("✅ Massive: Authenticated")
                    currentStatus = .authenticated
                    if !pendingSymbols.isEmpty {
                        Task { await subscribe(symbols: Array(pendingSymbols)) }
                    }
                } else if status == "auth_failed" {
                    let errMsg = msg["message"] as? String ?? "Unknown Auth Error"
                    print("🚫 Massive: Auth Failed - Reason: \(errMsg)")
                    isAuthFailed = true
                    currentStatus = .failed("Auth Failed: \(errMsg)")
                    disconnect()
                    
                    // Fallback to Delayed Endpoint if on Real-time
                    if endpoint.contains("socket.polygon.io") {
                        print("⚠️ Attempting Fallback to Delayed Endpoint...")
                        Task {
                            await self.switchToDelayedAndReconnect()
                        }
                    }
                } else if status == "success" {
                    print("✅ Massive: Subscribed")
                }
            }
            
        case "T": // Trade
            // {"ev":"T","sym":"AAPL","p":150.0,"s":100,...}
            if let symbol = msg["sym"] as? String,
               let price = msg["p"] as? Double,
               let size = msg["s"] as? Double {
                
                let tick = MarketTick(symbol: symbol, price: price, volume: size, timestamp: Date())
                broadcast(tick)
            }
            
        case "Q": // Quote
            // {"ev":"Q","sym":"AAPL","bp":149.9,"ap":150.1,...}
            if let symbol = msg["sym"] as? String,
               let bid = msg["bp"] as? Double,
               let ask = msg["ap"] as? Double {
                
                let mid = (bid + ask) / 2.0
                let tick = MarketTick(symbol: symbol, price: mid, volume: 0, timestamp: Date())
                broadcast(tick)
            }
            
        default:
            break
        }
    }
    
    private func broadcast(_ tick: MarketTick) {
        for continuation in continuations.values {
            continuation.yield(tick)
        }
    }
    
    private func handleDisconnection() async {
        isConnected = false
        if isAuthFailed { return }
        
        print("⚠️ Reconnecting Massive...")
        try? await Task.sleep(for: .seconds(2))
        
        if let key = storedKey {
            connect(apiKey: key)
        }
    }
}
