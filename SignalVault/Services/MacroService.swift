import Foundation
import SwiftUI

actor MacroService {
    
    // Mission 16: The Global Macro Dashboard
    // Tracks "Heavy Hitters": Rates, Inflation, Jobs.
    
    func fetchMacroData() async -> MacroData {
        // Mock Data for Sandbox (Simulating a challenging environment)
        // In real app, fetch from FRED or Polygon.io
        
        let now = Date()
        let nextMeeting = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        
        return MacroData(
            fedRate: 5.5,          // High rates
            cpiYearly: 3.2,        // Sticky inflation
            unemploymentRate: 3.9, // Low but rising
            treasury10Y: 4.2,
            treasury2Y: 4.65,      // Yield Curve Inverted (Recession Warning)
            nextFedMeeting: nextMeeting
        )
    }
    
    func determineRegime(data: MacroData) -> MarketRegime {
        // "The Regime Filter"
        
        // 1. Recession Check (Yield Curve)
        if data.isYieldCurveInverted {
            return .riskOff // Inversion is bad for equities usually
        }
        
        // 2. Inflation/Rate Check
        if data.cpiYearly > 3.0 || data.fedRate > 5.0 {
            return .riskOff // Tight monetary policy
        }
        
        if data.cpiYearly < 2.5 && data.fedRate < 3.0 {
             return .riskOn // Loose money, growth mode
        }
        
        return .neutral
    }
    // Mission 32: Economic Calendar
    func fetchEconomicEvents() -> [EconomicEvent] {
         let now = Date()
         
         // Mock Events for Demo
         return [
             EconomicEvent(
                 title: "NFP (Non-Farm Payrolls)",
                 impact: .high,
                 date: now.addingTimeInterval(45 * 60) // 45 mins from now (triggers warning)
             ),
             EconomicEvent(
                 title: "FOMC Minutes",
                 impact: .high,
                 date: now.addingTimeInterval(3600 * 24 * 2) // 2 days
             ),
             EconomicEvent(
                 title: "CPI Release",
                 impact: .medium,
                 date: now.addingTimeInterval(3600 * 5) // 5 hours
             )
         ]
    }
}

struct EconomicEvent: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let impact: EventImpact
    let date: Date
    
    enum EventImpact: String, Sendable {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .yellow
            }
        }
    }
}

