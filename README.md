<!-- @format -->

# Intervally

A production-quality iOS and watchOS interval timer for run/walk workouts with reliable background alerts and Apple Watch companion app.

## Overview

Intervally is a SwiftUI-based interval timer app for iOS 17+ and watchOS 10+ that provides:

- Custom interval definitions (Run 4:00, Walk 1:00, etc.)
- Multiple saved presets with per-preset HealthKit tracking control
- Reliable background operation with screen locked
- Audio chimes, voice cues, and haptics at interval boundaries
- Accurate timing with drift correction
- **Apple Watch companion app** with always-on display and autonomous operation
- Per-preset control over HealthKit workout tracking (fitness vs productivity timers)

**Bundle ID:** `com.dominic.intervally`

## Features

### Intervals & Presets

- Define 2+ intervals per workout with custom titles, durations, colors, and voice cues
- Save named presets for quick access
- Choose cycle count (e.g., 6 cycles) or infinite repeat
- Reorder, edit, and delete intervals
- **Per-preset HealthKit toggle**: Enable workout tracking for fitness activities, disable for Pomodoro/cooking timers

### Session Controls

- Start / Pause / Resume / Stop
- Skip forward / backward between intervals
- Real-time display of current interval, remaining time, and next interval
- Total elapsed time tracking
- **3-2-1 countdown** before first interval (optional)

### Alerts & Feedback

- Audio chime at each interval boundary
- Optional voice announcement ("Run", "Walk")
- Haptic feedback (vibration)
- Configurable: toggle sounds, voice, haptics independently
- Adjustable speech rate for voice cues
- Respects silent mode

### Apple Watch Companion

- **Autonomous operation**: Watch runs its own timer after receiving workout structure
- **Always-on display**: Screen stays visible when you raise your wrist
- **Background execution**: Continues running when screen is off
- **HealthKit integration**: Optional workout tracking saves to Health app
- **Fast updates**: 0.5s when active, 2s when screen dimmed
- **Late-join support**: Open watch mid-workout and it syncs automatically
- **Configurable haptics**: Enable/disable watch haptics per preset

### Background Reliability

Intervally uses a multi-strategy approach for background accuracy:

1. **Audio Session Keep-Alive** (iPhone): Maintains an active `AVAudioSession` in `.playback` mode with background audio capability, allowing the timer to continue running accurately even when the screen is locked.

2. **HealthKit Workout Session** (Watch): Uses `HKWorkoutSession` to keep watch app alive and enable always-on display. Workout data is conditionally saved based on preset settings.

3. **Scheduled Local Notifications**: Pre-schedules `UNUserNotificationCenter` notifications at computed interval boundaries as a fallback, ensuring alerts fire even if the audio session is interrupted.

4. **Monotonic Time Reference**: Uses absolute `Date` calculations rather than relying on `Timer` alone, eliminating drift over long sessions.

5. **Foreground Reconciliation**: When returning to foreground, the app recalculates elapsed time against the original schedule to maintain accuracy (typically ≤ 0.5s drift per 10 minutes).

## Project Structure

All code is located in the `xcode/` directory:

```
xcode/Intervally/
├── Intervally iOS App/                   # iPhone App
│   ├── IntervallyApp.swift               # App entry point
│   ├── Models/
│   │   ├── Interval.swift                # Interval model
│   │   └── Preset.swift                  # Preset model with enableHealthKitWorkout
│   ├── Engine/
│   │   ├── IntervalEngine.swift          # Core timer engine
│   │   └── IntervalViewModel.swift       # Observable view model
│   ├── Services/
│   │   ├── AudioService.swift            # Audio session & chimes
│   │   ├── SpeechService.swift           # Voice announcements
│   │   ├── HapticsService.swift          # Haptic feedback
│   │   ├── NotificationService.swift     # Local notifications
│   │   └── WatchConnectivityService.swift # iPhone-Watch communication
│   ├── Persistence/
│   │   └── PresetStore.swift             # Preset storage with settings
│   ├── Views/
│   │   ├── HomeView.swift                # Main timer interface
│   │   ├── PresetEditorView.swift        # Preset creation/editing
│   │   ├── SettingsView.swift            # Settings UI
│   │   └── Components/
│   │       └── ProgressRing.swift        # Circular progress indicator
│   └── Assets.xcassets/
│
├── Intervally Watch App/                # Apple Watch App
│   ├── Intervally_WatchApp.swift        # Watch app entry point
│   ├── ContentView.swift                # Watch UI with LIVE indicator
│   ├── WatchConnectivityManager.swift   # Watch-iPhone communication
│   ├── WorkoutManager.swift             # HealthKit workout session management
│   └── Assets.xcassets/
│
└── Intervally.xcodeproj                 # Xcode project
```

## Architecture

### Models

- **Interval:** Represents a single interval (title, duration, color, voice cue)
- **Preset:** Collection of intervals with cycle count, name, and `enableHealthKitWorkout` flag

### Engine (iPhone)

- **IntervalEngine:** Core state machine managing session lifecycle

  - States: `.idle`, `.running`, `.paused`, `.finished`
  - Computes absolute schedule at start (array of boundary `Date`s)
  - Publishes current state, remaining time, and progress
  - Handles pause/resume/skip with schedule recalculation

- **IntervalViewModel:** `@Observable` view model bridging engine to SwiftUI

### Services (iPhone)

- **AudioService:** Manages `AVAudioSession` and plays chime sound
- **SpeechService:** Uses `AVSpeechSynthesizer` for voice announcements
- **HapticsService:** Triggers haptic feedback patterns
- **NotificationService:** Schedules/cancels local notifications for intervals
- **WatchConnectivityService:** Manages `WCSession` for iPhone-Watch communication

### Watch App

- **WatchConnectivityManager:** Manages watch-side communication and autonomous timer

  - Receives full workout structure from iPhone
  - Runs independent countdown timer (0.5s active, 2s dimmed)
  - Handles interval transitions locally
  - Adjusts update frequency based on Always-On mode

- **WorkoutManager:** Manages HealthKit workout session
  - Always starts session to keep app alive
  - Conditionally saves or discards workout based on `enableHealthKitWorkout`
  - Enables always-on display via HealthKit
  - Handles session cleanup and error recovery

### Views

- **HomeView (iPhone):** Main timer interface with large countdown, progress ring, controls
- **PresetEditorView (iPhone):** Create/edit intervals and presets, including HealthKit toggle
- **SettingsView (iPhone):** Configure audio, voice, haptics, and app behavior
- **ContentView (Watch):** Watch UI showing current interval, timer, and LIVE indicator
- **ProgressRing:** Custom circular progress indicator

### Persistence

- **PresetStore:** Saves/loads presets and settings to local JSON file

## Setup Instructions

### Requirements

- macOS with Xcode 15+
- iOS 17+ device for iPhone app testing
- watchOS 10+ device for Watch app testing (optional)
- Apple Developer account

### Quick Start

1. **Open Project**

   ```bash
   cd xcode/Intervally
   open Intervally.xcodeproj
   ```

2. **Configure Signing**

   - Select "Intervally iOS App" target → Signing & Capabilities
   - Choose your Team
   - Update Bundle Identifier if needed

3. **Build & Run**
   - Select your device
   - Press ⌘R to build and run

For detailed Watch app setup instructions including HealthKit configuration, see `xcode/WATCH_SETUP.md`.

## Usage

### Creating a Preset

1. Tap **New Preset** on home screen
2. Add intervals (title, duration, color, optional voice cue)
3. Reorder by dragging
4. Set cycle count or choose "Repeat Until Stopped"
5. **Toggle "Track as HealthKit Workout"** (enable for fitness, disable for productivity)
6. Save with a descriptive name

### Starting a Workout

**On iPhone:**

1. Select a preset from the home screen
2. Tap **Start**
3. Optional 3-2-1 countdown
4. Lock screen or background the app—alerts will continue
5. Use **Skip** buttons or **Pause** as needed
6. Tap **Stop** to end early

**On Apple Watch:**

1. Start workout on iPhone (Watch automatically syncs)
2. Raise your wrist to see timer
3. **LIVE** indicator shows HealthKit session is active
4. Lower wrist—app continues in background
5. Raise wrist anytime to check progress

### Settings

- **Sounds:** Enable/disable audio chimes
- **Voice:** Enable/disable voice announcements
- **Haptics:** Enable/disable vibration feedback
- **Speech Rate:** Adjust voice speed
- **Count-In:** Optional 3-2-1 countdown before first interval
- **Keep Screen Awake:** Prevent auto-lock during sessions
- **Watch Haptics:** Enable/disable haptics on Apple Watch

## Key Features Implementation Details

### Per-Preset HealthKit Control

Each preset has an `enableHealthKitWorkout` boolean property that controls whether workout data is saved to the Health app:

- **Enabled** (default): Full HealthKit workout tracking, data saved to Health app
- **Disabled**: HealthKit session starts (for always-on display) but workout is discarded on completion

This allows you to use the same app for both fitness workouts and productivity timers (Pomodoro, cooking, etc.) without cluttering your Health app data.

### Watch Autonomous Mode

The watch runs independently after receiving the full workout structure from iPhone:

1. iPhone sends complete workout data (intervals, cycles, current position)
2. Watch starts HealthKit session for always-on display
3. Watch runs local timer with automatic interval transitions
4. Watch only syncs with iPhone for pause/resume/stop commands
5. Fast updates (0.5s when active, 2s when dimmed) for smooth countdown

### Late-Join Support

If you open the watch app mid-workout:

1. Watch receives simple timer update from iPhone
2. Watch automatically requests full workout structure
3. iPhone sends complete workout data with current position
4. Watch switches to autonomous mode with fast updates
5. HealthKit session starts for always-on display

## Testing

### Manual Testing Checklist

- [ ] Start preset with 2 intervals × 3 cycles → verify 6 transitions
- [ ] Lock iPhone screen mid-session → verify alerts continue
- [ ] Background for 5 minutes → verify time accuracy on foreground
- [ ] Skip forward/backward → verify correct interval and timing
- [ ] Pause → wait 10s → resume → verify no lost time
- [ ] Toggle voice/sound/haptics in settings → verify changes take effect
- [ ] Start workout on iPhone → verify Watch syncs and shows LIVE indicator
- [ ] Open Watch mid-workout → verify late-join sync works
- [ ] Lower Watch wrist → verify app stays alive with dimmed screen
- [ ] Test preset with HealthKit OFF → verify workout not saved to Health app

## Known Limitations

### iPhone App

- **Audio Interruptions:** Phone calls or Siri will pause audio. The app auto-pauses the session and can be resumed manually.
- **Background Restrictions:** iOS may suspend the app if battery is critically low or Low Power Mode is enabled. Scheduled notifications will still fire.
- **Notification Limit:** iOS allows 64 pending local notifications. Long infinite-repeat sessions may exceed this; the app schedules the next ~50 intervals dynamically.

### Watch App

- **HealthKit Required:** Watch app requires HealthKit session to stay alive (even when workout tracking is disabled)
- **Late-Join Delay:** Opening watch mid-workout takes 1-2 seconds to sync full workout structure
- **Screen Dimming:** 2-second update interval in dimmed mode may show slight delay in second transitions

## Troubleshooting

### iPhone: Alerts Don't Fire in Background

1. Verify **Background Modes > Audio** is enabled in Xcode
2. Check notification permissions: Settings > Intervally > Notifications
3. Ensure audio file `chime.wav` is in bundle (or app will use system sound fallback)
4. Test with device volume up and not on silent (for audio)

### Watch: App Closes When Wrist Lowered

1. Verify HealthKit permission granted on Watch
2. Check for **LIVE** indicator (green dot) - confirms HealthKit session running
3. Ensure workout was started on iPhone first
4. Check Xcode console for "✅ Workout session started" log

### Watch: Slow Update Rate

1. If updates are coming every 10 seconds, watch is NOT in autonomous mode
2. Check iPhone console for "📱 Sent full workout sync to Watch (late-join)"
3. Restart workout and open Watch immediately to receive full structure
4. Verify no errors in Watch console about missing workout data

### Timer Drifts Over Time

- Ensure app is built in Release mode for testing (Debug mode has more overhead)
- Check for other apps consuming significant CPU/audio resources
- Expected drift: < 0.5s per 10 minutes

## Accessibility

- Dynamic Type support for all text
- VoiceOver labels on all interactive elements
- High-contrast color options
- Large tap targets (minimum 44pt)

## Future Enhancements

- Workout history and statistics
- Custom haptic patterns per interval
- Configurable alert sounds per interval
- iCloud sync for presets
- Widgets for home screen
- Siri Shortcuts support

## License

This is example code for educational purposes. Adapt as needed for your project.

---

**Built with SwiftUI for iOS 17+ and watchOS 10+**

Apple frameworks: AVFoundation, UserNotifications, CoreHaptics, HealthKit, WatchConnectivity
