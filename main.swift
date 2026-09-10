import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Keep a strong reference to the delegate and start the proper AppKit run loop.
// NSApplicationMain ensures full registration with LaunchServices and UserNotifications.
withExtendedLifetime(delegate) {
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
