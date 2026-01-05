import Foundation

protocol MarketDataProvider: Sendable {
    func connect() async throws
    func streamQuotes(for symbols: [String]) async -> AsyncStream<MarketTick>
    func fetchOptionChain(for symbol: String) async throws -> [OptionContract]
}
