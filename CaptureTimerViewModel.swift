//
//  CaptureTimerViewModel.swift
//
//  Drives the menu-bar countdown. Seeded with the average interval
//  observed from real TeamLogger logs (~4m29s, jittered 4:00-5:02),
//  then keeps refining that average live as more captures come in —
//  so the countdown adapts if TeamLogger's interval or idle-skip
//  behavior changes over time.
//

import Foundation
import Combine

final class CaptureTimerViewModel: ObservableObject {

    @Published var secondsRemaining: Int
    @Published var history: [CaptureEvent] = []
    @Published var averageInterval: TimeInterval
    @Published var isPaused: Bool = false

    /// Called whenever a new (non-Apple) capture event is detected, after
    /// it's been recorded and the countdown reset. Wire this up to
    /// NotificationManager (or anything else) from outside.
    var onCapture: ((CaptureEvent) -> Void)?

    /// Seed value from the observed sample (11 captures, ~4:02–5:02 range).
    /// Replace with a fresh measurement if TeamLogger's behavior changes.
    static let seedAverage: TimeInterval = 4 * 60 + 29 // 4m29s

    /// How much weight new observations get vs. the running average.
    /// 0.3 means each new interval nudges the average ~30% of the way.
    private let smoothing: Double = 0.3

    /// If a gap is more than this multiple of the average, treat it as
    /// an idle-skip (TeamLogger paused) rather than a real interval —
    /// don't let it distort the rolling average.
    private let idleSkipMultiplier: Double = 2.0

    private var lastCaptureDate: Date?
    private var tickTimer: Timer?
    private let watcher = TeamLoggerWatcher()

    init(seedAverage: TimeInterval = CaptureTimerViewModel.seedAverage) {
        self.averageInterval = seedAverage
        self.secondsRemaining = Int(seedAverage)
        loadHistory()
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "CaptureHistory"),
           let saved = try? JSONDecoder().decode([CaptureEvent].self, from: data) {
            
            // Only keep data from the last 2 days
            let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
            self.history = saved.filter { $0.timestamp > twoDaysAgo }
            
            self.lastCaptureDate = self.history.first?.timestamp
            recalculateAverage()
            if !isPaused {
                self.secondsRemaining = Int(averageInterval)
            }
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "CaptureHistory")
        }
    }

    private func recalculateAverage() {
        guard history.count >= 2 else {
            averageInterval = CaptureTimerViewModel.seedAverage
            return
        }
        
        var validGaps: [TimeInterval] = []
        for i in 0..<(history.count - 1) {
            let newest = history[i].timestamp
            let oldest = history[i+1].timestamp
            let gap = newest.timeIntervalSince(oldest)
            
            // Exclude gaps that look like idle skips (e.g. breaks)
            if gap < CaptureTimerViewModel.seedAverage * idleSkipMultiplier {
                validGaps.append(gap)
            }
        }
        
        if !validGaps.isEmpty {
            let total = validGaps.reduce(0, +)
            averageInterval = total / Double(validGaps.count)
        } else {
            averageInterval = CaptureTimerViewModel.seedAverage
        }
    }

    func start() {
        watcher.onCaptureStarted = { [weak self] event in
            self?.handleCapture(event)
        }
        watcher.start()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        watcher.stop()
        tickTimer?.invalidate()
        tickTimer = nil
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            tickTimer?.invalidate()
            tickTimer = nil
        } else {
            // Reset the countdown timer
            secondsRemaining = Int(averageInterval)
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard secondsRemaining > 0 else { return } // holds at 0 until next capture resets it
        secondsRemaining -= 1
    }

    private func handleCapture(_ event: CaptureEvent) {
        guard event.type == "scr" else { return } // this view model only tracks screen capture

        history.insert(event, at: 0)
        
        // Only keep data from the last 2 days
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        history = history.filter { $0.timestamp > twoDaysAgo }
        
        lastCaptureDate = event.timestamp
        saveHistory()
        recalculateAverage()

        // Auto-resume if we were paused
        if isPaused {
            isPaused = false
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }

        // Reset the countdown to the current average.
        secondsRemaining = Int(averageInterval)

        onCapture?(event)
    }

    var formattedRemaining: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var formattedAverage: String {
        let total = Int(averageInterval)
        let m = total / 60
        let s = total % 60
        return String(format: "%dm%02ds", m, s)
    }
}
