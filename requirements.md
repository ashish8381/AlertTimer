# Requirements — TeamLogger Countdown

## 1. Overview

A lightweight, native macOS **background menu-bar utility** that detects
when TeamLogger (or any other app) performs a screen capture, and shows a
live countdown to the next expected capture in the menu bar.

Detection is based on tailing macOS's own unified log — specifically the
`ControlCenter` subsystem that drives the native orange/purple sensor
indicator dots — rather than any TeamLogger-specific API (none exists).

**Scope:** personal use only. Not intended for App Store distribution.

---

## 2. Goals

- Detect, in near real time, when TeamLogger takes a screenshot.
- Record the bundle ID, activity type, and timestamp of each capture.
- Display a live countdown in the menu bar to the next expected capture.
- Automatically reset/re-calibrate that countdown based on observed
  intervals, rather than a fixed guess.
- Keep a visible history of past capture events.

## 3. Non-goals

- Not attempting to block, spoof, or interfere with TeamLogger's capture.
- Not distributed via the App Store (App Sandbox must be off — see §7).
- Not guaranteed to survive future macOS versions unchanged, since the
  detection mechanism is undocumented (see §8, Risks).

---

## 4. Background research / findings

These findings came from live `log stream` captures on the developer's own
Mac (macOS Sequoia) and directly informed the design.

### 4.1 Detection mechanism
macOS's Control Center draws the menu-bar "app is capturing your screen"
indicator (introduced in Sonoma) based on log activity in:

```
subsystem: com.apple.controlcenter
category:  sensor-indicators
process:   ControlCenter
```

The key log line:
```
Active activity attributions changed to ["scr:27KU2G7D8T.com.build80.teamloggertimer"]
```
- `scr` = screen capture. `cam`, `mic`, and `loc` prefixes were also
  observed for camera, microphone, and location activity respectively,
  confirming the same mechanism covers all sensor types.
- The array lists all currently active attributions; comparing successive
  arrays gives clean start/stop transitions (set diff).
- No Full Disk Access or special entitlement is required to read this —
  unified log streaming is unprivileged.

### 4.2 TeamLogger's observed bundle ID
```
27KU2G7D8T.com.build80.teamloggertimer
```

### 4.3 Capture cadence (sample of 18 real captures)
- Base interval: **~4m29s average**, jittered between roughly 4:00 and 5:02
  per cycle — consistent with intentional randomization to avoid a
  predictable capture schedule.
- Each capture is near-instantaneous: 20–40ms between STARTED and STOPPED,
  i.e. a single-frame grab, not continuous recording.
- One observed outlier: a 14:44 gap (11:54:18 → 12:09:02, ~3x normal).
  **Confirmed** — the developer was away from the keyboard during this
  window. This validates the idle-skip hypothesis: TeamLogger pauses
  capturing during periods of no keyboard/mouse input and resumes once
  activity is detected again, rather than running on a strict fixed
  interval regardless of user presence.

### 4.4 False positives to filter
`com.apple.*` bundle IDs (e.g. `com.apple.systemuiserver`) also trigger the
same sensor-indicator mechanism — this is macOS capturing its own menu bar
icon images, not third-party monitoring. These must be excluded from
detection logic.

---

## 5. Functional requirements

| ID | Requirement |
|----|-------------|
| FR1 | The app shall run as a background menu-bar agent with no Dock icon. |
| FR2 | The app shall watch the unified log in real time for sensor-indicator activity attributed to TeamLogger's bundle ID. |
| FR3 | The app shall ignore activity from `com.apple.*` bundle IDs. |
| FR4 | On detecting a new TeamLogger screen-capture event, the app shall record the event (timestamp, type, bundle ID) to an in-memory (and optionally persisted) history list. |
| FR5 | The app shall display a live countdown (mm:ss) in the menu bar showing time until the next expected capture. |
| FR6 | On each detected capture, the countdown shall reset based on the current rolling average interval. |
| FR7 | The rolling average shall be seeded with the observed baseline (4m29s) and updated via exponential smoothing as new intervals are observed. |
| FR8 | Gaps larger than 2x the current rolling average shall be excluded from the average calculation (treated as idle-skips), so they don't distort future estimates. |
| FR9 | Clicking the menu-bar item shall open a popover showing: current countdown, current rolling average, and a scrollable list of past capture events (timestamp + type). |
| FR10 | The app shall start watching automatically on launch and stop cleanly on quit. |
| FR11 | On detecting a TeamLogger screen-capture event, the app shall display a local macOS notification (banner + sound) indicating a capture occurred, in addition to resetting the countdown and recording it in history. |
| FR12 | The app shall request local-notification authorization from the user on first launch, and shall not crash or malfunction if authorization is denied — it should simply skip posting notifications. |

## 6. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NFR1 | The app shall be lightweight — no polling; log events are pushed via `log stream`, not repeated queries. |
| NFR2 | The app shall require no special permission prompts for its core function (log streaming is unprivileged). |
| NFR3 | The app shall not require Full Disk Access unless the optional TCC.db permission-history view is enabled. |
| NFR4 | The app shall be built with Swift, using AppKit for the menu-bar/status-item host and SwiftUI for the popover UI. |
| NFR5 | The app shall degrade gracefully if the underlying log predicate stops matching in a future macOS version (i.e. simply show no detections, not crash). |

---

## 7. Technical stack & architecture

- **Language:** Swift
- **UI:** AppKit (`NSStatusItem`, `NSPopover` host) + SwiftUI (popover content)
- **Detection:** `Process` wrapping `/usr/bin/log stream --style ndjson --predicate ...`, parsed as NDJSON
- **Notifications:** `UserNotifications` framework (`UNUserNotificationCenter`), local notifications only — no push/remote notification setup or entitlements needed
- **AVFoundation:** not required for the current scope (no camera/mic capture is performed by this app itself); reserved only if a future feature surfaces *other* apps' camera/mic activity using the same sensor-indicator data already available from the log

### Components
- `TeamLoggerWatcher` — spawns and parses the log stream, filters noise, emits start/stop events.
- `CaptureTimerViewModel` (`ObservableObject`) — owns the countdown, rolling average, and history; ticks every second; exposes an `onCapture` callback for side effects like notifications.
- `NotificationManager` — wraps `UNUserNotificationCenter`; requests authorization on launch and posts a banner+sound notification for each detected capture, including while the app is "foregrounded" (menu-bar apps have no windowed foreground/background distinction, so `willPresent` is overridden to always show the banner).
- `AppDelegate` — hosts the `NSStatusItem`, updates its title from the view model, manages the popover, wires `viewModel.onCapture` to `NotificationManager`.
- `HistoryView` (SwiftUI) — displays countdown, average, and history list.

### Build constraints
- **App Sandbox must be disabled** — `Process` cannot spawn `/usr/bin/log` under sandbox restrictions.
- `LSUIElement = YES` in Info.plist — background agent, no Dock icon.
- Signed with a personal Developer ID; no App Store distribution, no notarization required for local-only use.

---

## 8. Risks / limitations

- **Undocumented mechanism:** the entire detection approach relies on private, undocumented log behavior (`com.apple.controlcenter:sensor-indicators`). Apple can change or remove this in any macOS update without notice.
- **Bundle ID coupling:** the watcher currently filters to one hardcoded bundle ID. If TeamLogger is reinstalled with a different bundle ID, or the app wants to generalize to "any non-Apple screen capturer," `TeamLoggerWatcher.teamLoggerBundleID` needs updating or the filter logic needs to change to allow-list-by-exclusion instead.
- **No sandboxing = no App Store path.** Acceptable for this personal-use scope, but should not be treated as a template for a distributable product without redesign (e.g. an XPC helper).
- **Average interval accuracy** depends on a small sample (18 events from one session). Longer-term data collection would sharpen the seed value and idle-skip threshold.
- **Idle-skip behavior is confirmed but not yet formally detected.** The app currently infers an idle-skip only after the fact, by seeing an oversized gap once the next capture arrives (FR8). It does not yet know *during* the gap that the user is idle — it just holds the countdown at 0. A true idle-aware countdown (freezing or hiding the timer while genuinely idle, rather than sitting at 0:00) would need to read system idle time directly.

---

## 9. Future enhancements (not in current scope)

- Persist history across app restarts (e.g. to a local JSON file or SQLite).
- Read live system idle time (`ioreg -c IOHIDSystem` / `HIDIdleTime`) so the
  countdown can visibly show "idle — paused" instead of sitting at 0:00
  during a real idle-skip, rather than only inferring it retroactively.
- Surface camera/mic/location activity from other apps using the same detection mechanism, already partially observed (`cam`, `mic`, `loc` prefixes).
- Optional local notification a few seconds before the next expected capture.
- Generalize bundle-ID filtering to "any non-Apple app" instead of one hardcoded ID.
