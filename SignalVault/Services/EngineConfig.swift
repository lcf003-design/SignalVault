import Foundation

struct EngineConfig: Sendable, Hashable {
    let rsiPeriod: Int
    let macdFast: Int
    let macdSlow: Int
    let signalPeriod: Int
    
    // Explicitly nonisolated to ensure accessibility from any actor
    // Computed properties explicitly marked nonisolated to strict concurrency
    nonisolated static var stock: EngineConfig { EngineConfig(rsiPeriod: 14, macdFast: 12, macdSlow: 26, signalPeriod: 9) }
    nonisolated static var crypto: EngineConfig { EngineConfig(rsiPeriod: 9, macdFast: 8, macdSlow: 21, signalPeriod: 9) }
}
