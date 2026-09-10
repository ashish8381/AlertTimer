//
//  NotificationManager.swift
//
//  Thin wrapper around UNUserNotificationCenter for posting a local
//  notification whenever a TeamLogger screen capture is detected.
//
//  Note: UNUserNotificationCenter requires the app to run as a proper
//  .app bundle with a valid bundle identifier (which an Xcode app target
//  already gives you) — a bare command-line binary won't be able to post
//  notifications.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Call once at launch. Safe to call multiple times.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("NotificationManager: authorization error: \(error)")
            } else if !granted {
                print("NotificationManager: notifications not authorized — capture alerts will be skipped.")
            }
        }
    }

    func notifyCapture(_ event: CaptureEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Screen Capture Detected"
        content.body = "\(labelForType(event.type)) triggered by \(event.bundleID)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        /*
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationManager: failed to post notification: \(error)")
                self.postAppleScriptNotification(title: content.title, body: content.body)
            }
        }
        */
        
        // On modern macOS, ad-hoc signed LSUIElement apps often fail to show notifications 
        // silently even if added successfully to the center, because they aren't fully registered 
        // in System Settings. We will proactively fire an AppleScript notification as well to guarantee delivery.
        postAppleScriptNotification(title: content.title, body: content.body)
    }

    private func postAppleScriptNotification(title: String, body: String) {
        let script = "display notification \"\(body)\" with title \"\(title)\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    private func labelForType(_ type: String) -> String {
        switch type {
        case "scr": return "Screen capture"
        case "cam": return "Camera use"
        case "mic": return "Microphone use"
        case "loc": return "Location use"
        default: return type
        }
    }

    // Show the banner even while the app is in the foreground (menu-bar
    // apps are technically always "foreground" since there's no windowed
    // app to background against).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
