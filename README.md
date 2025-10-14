# RunLoop

A minimal, production-quality iOS interval timer for run/walk workouts with reliable background alerts.

## Overview

RunLoop is a SwiftUI-based interval timer app for iOS 17+ that provides:
- Custom interval definitions (Run 4:00, Walk 1:00, etc.)
- Multiple saved presets
- Reliable background operation with screen locked
- Audio chimes, voice cues, and haptics at interval boundaries
- Accurate timing with drift correction
- Live Activity support (Dynamic Island)

**Bundle ID:** `com.example.runloop`

## Features

### Intervals & Presets
- Define 2+ intervals per workout with custom titles, durations, colours, and voice cues
- Save named presets for quick access
- Choose cycle count (e.g., 6 cycles) or infinite repeat
- Reorder, edit, and delete intervals

### Session Controls
- Start / Pause / Resume / Stop
- Skip forward / backward between intervals
- Real-time display of current interval, remaining time, and next interval
- Total elapsed time tracking

### Alerts & Feedback
- Audio chime at each interval boundary
- Optional voice announcement ("Run", "Walk")
- Haptic feedback (vibration)
- Configurable: toggle sounds, voice, haptics independently
- Volume control for voice cues
- Respects silent mode

### Background Reliability
RunLoop uses a dual-strategy approach for background accuracy:

1. **Audio Session Keep-Alive:** Maintains an active `AVAudioSession` in `.playback` mode with background audio capability, allowing the timer to continue running accurately even when the screen is locked.

2. **Scheduled Local Notifications:** Pre-schedules `UNUserNotificationCenter` notifications at computed interval boundaries as a fallback, ensuring alerts fire even if the audio session is interrupted.

3. **Monotonic Time Reference:** Uses absolute `Date` calculations rather than relying on `Timer` alone, eliminating drift over long sessions.

4. **Foreground Reconciliation:** When returning to foreground, the app recalculates elapsed time against the original schedule to maintain accuracy (typically ≤ 0.5s drift per 10 minutes).

## Project Setup

### 1. Xcode Configuration

#### Background Modes
Enable the following capabilities in your target's **Signing & Capabilities**:

1. **Background Modes**
   - ☑️ Audio, AirPlay, and Picture in Picture
   - ☑️ Background fetch (optional, for future enhancements)

2. **Push Notifications** (for Live Activity)
   - ☑️ Enable if implementing Live Activity

#### Info.plist Entries
Add the following keys:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<key>NSMicrophoneUsageDescription</key>
<string>RunLoop does not use the microphone.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>RunLoop uses speech synthesis to announce intervals.</string>

<key>UISupportsDocumentBrowser</key>
<false/>
```

### 2. Audio Assets

Add a short audio file to play at interval boundaries:

1. Add `chime.wav` (or `.aif`, `.m4a`) to the **Resources** folder
2. Ensure the file is added to the target's **Copy Bundle Resources** build phase
3. Keep the audio file under 30 seconds for notification compatibility
4. Recommended: 1-2 second chime in `.wav` format at 44.1 kHz

**Placeholder:** The code references `chime.wav`. Replace with your preferred sound file.

### 3. Permissions

The app requests permission for:
- **Notifications:** Local notifications for interval alerts (requested on first launch)
- **Audio:** Background audio session (no explicit prompt required)

### 4. Live Activity (Optional)

To enable Live Activity with Dynamic Island:

1. Add **Push Notifications** capability
2. Ensure `RunLoopActivityAttributes.swift` is included
3. Add `NSSupportsLiveActivities` key to Info.plist:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

4. The Live Activity shows current interval, remaining time, and Skip/Pause actions

## Architecture

### Models
- **Interval:** Represents a single interval (title, duration, colour, voice cue)
- **Preset:** Collection of intervals with cycle count and name

### Engine
- **IntervalEngine:** Core state machine managing session lifecycle
  - States: `.idle`, `.running`, `.paused`, `.finished`
  - Computes absolute schedule at start (array of boundary `Date`s)
  - Publishes current state, remaining time, and progress
  - Handles pause/resume/skip with schedule recalculation

- **IntervalViewModel:** `@Observable` view model bridging engine to SwiftUI

### Services
- **AudioService:** Manages `AVAudioSession` and plays chime sound
- **SpeechService:** Uses `AVSpeechSynthesizer` for voice announcements
- **HapticsService:** Triggers haptic feedback patterns
- **NotificationService:** Schedules/cancels local notifications for intervals

### Views
- **HomeView:** Main timer interface with large countdown, progress ring, controls
- **PresetEditorView:** Create/edit intervals and presets
- **SettingsView:** Configure audio, voice, haptics, and app behaviour
- **ProgressRing:** Custom circular progress indicator

### Persistence
- **PresetStore:** Saves/loads presets and settings to local JSON file

## Timer Accuracy & Drift Handling

### Why Accuracy Matters
Traditional `Timer`-based approaches accumulate drift due to:
- OS scheduling variability
- Background suspension
- Context switching overhead

### Our Approach
1. **Absolute Timeline:** At session start, compute all interval boundaries as absolute `Date` values based on `Date.now`
2. **Drift-Free Calculation:** On each tick, calculate `remaining = boundaryDate.timeIntervalSince(Date.now)`
3. **Background Reconciliation:** When foregrounding, recompute position in timeline without adjusting boundaries
4. **Result:** Drift stays below 0.5s per 10 minutes under normal conditions

### Example
```swift
// Session starts at 14:00:00.000
// Interval 1: Run 4:00 → boundary at 14:04:00.000
// Interval 2: Walk 1:00 → boundary at 14:05:00.000

// App goes to background at 14:02:30
// User opens app at 14:04:15
// Engine calculates: now (14:04:15) is past first boundary (14:04:00)
// → Transition to Walk interval
// → Remaining = 14:05:00 - 14:04:15 = 45s
```

## Usage

### Creating a Preset
1. Tap **New Preset** on home screen
2. Add intervals (title, duration, colour, optional voice cue)
3. Reorder by dragging
4. Set cycle count or choose "Repeat Until Stopped"
5. Save with a descriptive name

### Starting a Workout
1. Select a preset from the home screen
2. Tap **Start**
3. Lock screen or background the app—alerts will continue
4. Use **Skip** buttons or **Pause** as needed
5. Tap **Stop** to end early

### Settings
- **Sounds:** Enable/disable audio chimes
- **Voice:** Enable/disable voice announcements
- **Haptics:** Enable/disable vibration feedback
- **Speech Rate:** Adjust voice speed
- **Count-In:** Optional 3-2-1 countdown before first interval
- **Keep Screen Awake:** Prevent auto-lock during sessions

## Testing

### Unit Tests
Run tests via `⌘U` in Xcode:
- `IntervalEngineTests.swift`: Validates timeline calculation, pause/resume, skip logic, drift handling

### Manual Testing Checklist
- [ ] Start preset with 2 intervals × 3 cycles → verify 6 transitions
- [ ] Lock screen mid-session → verify alerts continue
- [ ] Background for 5 minutes → verify time accuracy on foreground
- [ ] Skip forward/backward → verify correct interval and timing
- [ ] Pause → wait 10s → resume → verify no lost time
- [ ] Toggle voice/sound/haptics in settings → verify changes take effect
- [ ] Enable VoiceOver → verify all controls are accessible
- [ ] Test with silent mode on → verify haptics still work

## Known Limitations
- **Audio Interruptions:** Phone calls or Siri will pause audio. The app auto-pauses the session and can be resumed manually.
- **Background Restrictions:** iOS may suspend the app if battery is critically low or Low Power Mode is enabled. Scheduled notifications will still fire.
- **Notification Limit:** iOS allows 64 pending local notifications. Long infinite-repeat sessions may exceed this; the app schedules the next ~50 intervals dynamically.

## Troubleshooting

### Alerts Don't Fire in Background
1. Verify **Background Modes > Audio** is enabled
2. Check notification permissions: Settings > RunLoop > Notifications
3. Ensure audio file `chime.wav` is in bundle
4. Test with device volume up and not on silent (for audio)

### Timer Drifts Over Time
- Ensure app is built in Release mode for testing (Debug mode has more overhead)
- Check for other apps consuming significant CPU/audio resources
- Expected drift: < 0.5s per 10 minutes

### Voice Cues Don't Play
- Verify Voice toggle is ON in Settings
- Check `AVSpeechSynthesizer` is not interrupted by other audio
- Ensure device is not in Low Power Mode (may throttle speech)

## Accessibility
- Dynamic Type support for all text
- VoiceOver labels on all interactive elements
- High-contrast colour options
- Large tap targets (minimum 44pt)

## Future Enhancements
- Apple Watch companion app
- Custom haptic patterns per interval
- Workout history and statistics
- Export sessions to Health app
- Configurable alert sounds per interval
- Integration with music apps (auto-duck)

## License
This is example code for educational purposes. Adapt as needed for your project.

---

**Built with SwiftUI for iOS 17+**
Apple frameworks: AVFoundation, UserNotifications, CoreHaptics, AVKit