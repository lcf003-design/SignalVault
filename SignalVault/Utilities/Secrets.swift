import Foundation

enum Secrets {
    // Placeholder - Default Key
    private static let defaultKey = "wANBaTZQHpr3h8T9BjrOpRpiCb9W20S1"
    
    static var polygonAPIKey: String {
        get {
            UserDefaults.standard.string(forKey: "user_polygon_api_key") ?? defaultKey
        }
        set {
            if newValue.isEmpty {
                 UserDefaults.standard.removeObject(forKey: "user_polygon_api_key")
            } else {
                UserDefaults.standard.set(newValue, forKey: "user_polygon_api_key")
            }
        }
    }
}
