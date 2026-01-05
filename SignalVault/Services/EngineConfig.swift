import Foundation

struct EngineConfig: Sendable, Hashable {
    let rsiPeriod: Int
    let macdFast: Int
    let macdSlow: Int
    let signalPeriod: Int
    
    // Explicitly nonisolated to ensure accessibility from any actor
    static let stock = EngineConfig(rsiPeriod: 14, macdFast: 12, macdSlow: 26, signalPeriod: 9)
    static let crypto = EngineConfig(rsiPeriod: 9, macdFast: 8, macdSlow: 21, signalPeriod: 9)
}
