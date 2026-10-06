# AlertTimer

AlertTimer is a lightweight, native macOS background menu-bar utility. It detects when specific apps (like TeamLogger) perform a screen capture and displays a live countdown to the next expected capture in the menu bar. 

## Technology Stack

This project is built using modern Apple technologies without relying on heavy third-party dependencies or Xcode project files, emphasizing a lightweight and native approach.

### Core Technologies

*   **Language:** [Swift](https://developer.apple.com/swift/)
*   **Architecture:** MVVM (Model-View-ViewModel) pattern
*   **Build System:** Custom Bash script (`build.sh`) directly invoking the Swift compiler (`swiftc`), bypassing the need for an `.xcodeproj`.

### macOS Frameworks & APIs

*   **AppKit:** Used for the core application lifecycle, hosting the menu-bar agent (`NSStatusItem`), and managing the popover (`NSPopover`).
*   **SwiftUI:** Used for rendering the modern, declarative user interface inside the menu-bar popover (`HistoryView.swift`).
*   **UserNotifications:** Utilized for delivering local macOS notifications (banner and sound) when a capture event is detected.
*   **Foundation (`Process`):** Used to spawn and monitor background shell processes.
*   **Unified Logging System:** The core detection mechanism relies on parsing macOS's native unified log in real-time. It streams logs via `/usr/bin/log stream --style ndjson` to detect `com.apple.controlcenter` sensor-indicator activity without requiring special system privileges or API hooks.

## How it works

The application tail-reads the macOS unified log for specific system events related to screen captures (the same mechanism that drives the orange/purple sensor indicator dots in the macOS menu bar). 

1. `TeamLoggerWatcher` continuously monitors the log stream.
2. When a capture event matching the target bundle ID is found, it notifies the `CaptureTimerViewModel`.
3. The view model recalculates the expected interval (accounting for idle times) and updates the countdown.
4. The `AppDelegate` updates the `NSStatusItem` in the menu bar and triggers a local notification via the `NotificationManager`.

## Building the App

To build the application, simply run the included build script:

```bash
./build.sh
```

This will compile the Swift files, package them into a `.app` bundle, generate the AppIcon, create the `Info.plist`, and apply local code signing.
