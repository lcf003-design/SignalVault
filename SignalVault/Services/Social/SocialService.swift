import Foundation
import SwiftData

struct PublicTraderProfile: Identifiable {
    let id = UUID()
    let nickname: String
    let pnlPercent: Double
    let winRate: Double
    let isSharingTrades: Bool
    
    var tier: String {
        if pnlPercent >= 50.0 { return "🐳" } // Whale
        else if pnlPercent >= 20.0 { return "🦈" } // Shark
        else { return "🐟" } // Minnow
    }
}

protocol SocialProvider {
    func fetchLeaderboard() async -> [PublicTraderProfile]
}

class MockSocialService: SocialProvider {
    func fetchLeaderboard() async -> [PublicTraderProfile] {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        return [
            PublicTraderProfile(nickname: "Satoshi_N", pnlPercent: 145.2, winRate: 68.5, isSharingTrades: false),
            PublicTraderProfile(nickname: "RoaringKitty", pnlPercent: 89.4, winRate: 42.0, isSharingTrades: true),
            PublicTraderProfile(nickname: "AlphaSeeker", pnlPercent: 52.1, winRate: 55.2, isSharingTrades: true),
            PublicTraderProfile(nickname: "DiamondHands", pnlPercent: 33.5, winRate: 48.0, isSharingTrades: true),
            PublicTraderProfile(nickname: "OptionsWizard", pnlPercent: 28.2, winRate: 61.5, isSharingTrades: false),
            PublicTraderProfile(nickname: "YOLO_Trader", pnlPercent: 12.4, winRate: 35.0, isSharingTrades: true),
            PublicTraderProfile(nickname: "SafeSaver", pnlPercent: 5.6, winRate: 85.0, isSharingTrades: false),
            PublicTraderProfile(nickname: "RektEffect", pnlPercent: -15.2, winRate: 20.0, isSharingTrades: false),
            PublicTraderProfile(nickname: "BuyHighSellLow", pnlPercent: -45.0, winRate: 15.0, isSharingTrades: true)
        ]
    }
}
