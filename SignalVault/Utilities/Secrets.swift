import Foundation

enum Secrets {
    // Placeholder - Default Key
    private static let defaultKey = "gLsSEi_3CFu0ufqRTQWPo_byasJkT2ax"
    
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
    
    // Mission 49: Massive / Polygon Credentials
    static var polygonAPIKey: String {
        get {
            let val = UserDefaults.standard.string(forKey: "user_polygon_key") ?? defaultKey
            return val.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty {
                UserDefaults.standard.removeObject(forKey: "user_polygon_key")
            } else {
                UserDefaults.standard.set(clean, forKey: "user_polygon_key")
            }
        }
    }
}
