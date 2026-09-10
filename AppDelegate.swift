//
//  AppDelegate.swift
//
//  Hosts the NSStatusItem (menu bar icon + live text) and a SwiftUI
//  popover for history. Runs as a background agent (no Dock icon) —
//  set LSUIElement = YES in Info.plist.
//

import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = CaptureTimerViewModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AlertTimer: applicationDidFinishLaunching started")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "…"
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.contentViewController = NSHostingController(
            rootView: HistoryView(viewModel: viewModel)
        )

        // Keep the status bar title in sync with the countdown, pause state, and average.
        Publishers.CombineLatest3(viewModel.$secondsRemaining, viewModel.$isPaused, viewModel.$averageInterval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)

        // Local notification whenever a TeamLogger capture is detected.
        NotificationManager.shared.requestAuthorization()
        viewModel.onCapture = { event in
            NotificationManager.shared.notifyCapture(event)
        }

        viewModel.start()
        updateTitle()
        
        // Test notification to debug why they aren't showing
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let event = CaptureEvent(timestamp: Date(), type: "scr", bundleID: "test.bundle.id")
            NotificationManager.shared.notifyCapture(event)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }

    private func updateTitle() {
        if viewModel.isPaused {
            statusItem.button?.title = "⏸ Paused"
        } else {
            statusItem.button?.title = "⏱ \(viewModel.formattedRemaining)"
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
