import Foundation
import AVFoundation

@MainActor
class AudioService: NSObject {
    static let shared = AudioService()
    
    private let synthesizer = AVSpeechSynthesizer()
    var isEnabled: Bool = true
    
    override init() {
        super.init()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Audio Session Error: \(error)")
        }
    }
    
    func announce(text: String) {
        guard isEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52 // Slightly faster than default
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func announceSignal(symbol: String, price: Double, signal: TradeSignal) {
        let direction: String
        if case .strongBuy = signal {
            direction = "High Conviction Buy"
        } else {
            direction = "Strong Sell"
        }
        
        let priceString = String(format: "%.0f", price)
        let text = "\(direction) Signal for \(symbol) at \(priceString)"
        announce(text: text)
    }
    
    // Mission 34: Sniper Sound
    func playSniperSound() {
        guard isEnabled else { return }
        // "Target Acquired" in a deeper, more robotic voice would be cool.
        // For now, AVSpeech with adjusted pitch.
        
        let utterance = AVSpeechUtterance(string: "Target Acquired. Execution Imminent.")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") // British accent sounds more... tactical?
        utterance.rate = 0.45
        utterance.pitchMultiplier = 0.8 // Deeper
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
}
