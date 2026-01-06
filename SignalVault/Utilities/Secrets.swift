import Foundation

enum Secrets {
    // Placeholder - Default Key
    private static let defaultKey = "wANBaTZQHpr3h8T9BjrOpRpiCb9W20S1"
    
    // Mission 43: Alpaca Credentials
    static var alpacaAPIKeyID: String {
        get {
            UserDefaults.standard.string(forKey: "user_alpaca_key_id") ?? ""
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: "user_alpaca_key_id")
            } else {
                UserDefaults.standard.set(newValue, forKey: "user_alpaca_key_id")
            }
        }
    }
    
    static var alpacaSecretKey: String {
         get {
             UserDefaults.standard.string(forKey: "user_alpaca_secret_key") ?? ""
         }
         set {
             if newValue.isEmpty {
                 UserDefaults.standard.removeObject(forKey: "user_alpaca_secret_key")
             } else {
                 UserDefaults.standard.set(newValue, forKey: "user_alpaca_secret_key")
             }
         }
     }
}
