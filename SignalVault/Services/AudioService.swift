import Foundation
import AVFoundation

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
        // "High Conviction Buy Signal for BTC at ninety-six thousand..."
        // Format price to be speakable? Default formatter is usually okay but might say "dollars".
        // Let's rely on AVSpeech default number handling, or simple string.
        
        let priceString = String(format: "%.0f", price) // Speak whole numbers for clarity on high value crypto?
        // Or "at 96400"
        
        let text = "\(direction) Signal for \(symbol) at \(priceString)"
        announce(text: text)
    }
}
