import UIKit
import SwiftUI

@MainActor
class HapticManager {
    static let shared = HapticManager()
    
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGeneratorLight = UIImpactFeedbackGenerator(style: .light)
    private let impactGeneratorMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactGeneratorHeavy = UIImpactFeedbackGenerator(style: .heavy)
    
    // Mission 8: "Long" haptic for Signal Changes
    // Using a pattern of haptics to simulate length
    func playSignalHaptic(type: TradeSignal) {
        switch type {
        case .strongBuy:
            notificationGenerator.notificationOccurred(.success)
            // Follow up for "tactile" feel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.impactGeneratorHeavy.impactOccurred()
            }
        case .strongSell:
            notificationGenerator.notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.impactGeneratorHeavy.impactOccurred()
            }
        case .neutral:
            impactGeneratorMedium.impactOccurred()
        }
    }
    
    func playToggleHaptic() {
        impactGeneratorLight.impactOccurred(intensity: 0.7)
    }
    
    func playSuccess() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    func playError() {
        notificationGenerator.notificationOccurred(.error)
    }
}
