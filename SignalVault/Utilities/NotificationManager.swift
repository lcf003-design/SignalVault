import UserNotifications
import SwiftUI
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
                if granted {
                    print("✅ [Notifications] Permission Granted")
                    self.configureCategories()
                } else if let error = error {
                    print("❌ [Notifications] Permission Failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Mission 22: Actionable Alerts
    private func configureCategories() {
        let buyAction = UNNotificationAction(identifier: "BUY_ACTION", title: "Execute BUY", options: [.foreground, .authenticationRequired])
        let sellAction = UNNotificationAction(identifier: "SELL_ACTION", title: "Execute SELL", options: [.foreground, .authenticationRequired])
        
        let signalCategory = UNNotificationCategory(identifier: "SIGNAL_ALERT", actions: [buyAction, sellAction], intentIdentifiers: [], options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([signalCategory])
    }
    
    // Simulate Background Pulse
    func scheduleMockCriticalAlert(symbol: String, isBuy: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 STRATEGIC SIGNAL: \(symbol)"
        content.body = "Strong \(isBuy ? "BUY" : "SELL") Signal Detected. Conviction: 98%. Tap to Execute."
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "SIGNAL_ALERT"
        content.interruptionLevel = .timeSensitive
        
        // Trigger in 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [Notifications] Failed to schedule: \(error)")
            } else {
                print("✅ [Notifications] Critical Alert Scheduled for 5s")
            }
        }
    }
    
    // Delegate: Handle In-App Notification (Show it anyway for Pulse effect)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    
    // Delegate: Handle Action Response
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        // userInfo is available if needed: let userInfo = response.notification.request.content.userInfo
        
        if actionID == "BUY_ACTION" {
            // Post notification for Observer to handle navigation/execution
            NotificationCenter.default.post(name: NSNotification.Name("ExecuteTradeFromNotification"), object: nil, userInfo: ["type": "BUY"])
        } else if actionID == "SELL_ACTION" {
            NotificationCenter.default.post(name: NSNotification.Name("ExecuteTradeFromNotification"), object: nil, userInfo: ["type": "SELL"])
        }
        
        completionHandler()
    }
}
