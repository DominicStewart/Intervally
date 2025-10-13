# RunLoop Configuration Guide

This guide covers the complete Xcode project setup for RunLoop.

## Project Structure

```
RunLoop/
├── RunLoop/
│   ├── RunLoopApp.swift                    # App entry point
│   ├── Models/
│   │   ├── Interval.swift                  # Interval model
│   │   └── Preset.swift                    # Preset model
│   ├── Engine/
│   │   ├── IntervalEngine.swift            # Core timer engine
│   │   └── IntervalViewModel.swift         # Observable view model
│   ├── Services/
│   │   ├── AudioService.swift              # Audio session & chimes
│   │   ├── SpeechService.swift             # Voice announcements
│   │   ├── HapticsService.swift            # Haptic feedback
│   │   └── NotificationService.swift       # Local notifications
│   ├── Persistence/
│   │   └── PresetStore.swift               # Preset storage
│   ├── Views/
│   │   ├── HomeView.swift                  # Main timer UI
│   │   ├── PresetEditorView.swift          # Preset editor
│   │   ├── SettingsView.swift              # Settings UI
│   │   └── Components/
│   │       └── ProgressRing.swift          # Progress indicator
│   ├── Activity/
│   │   └── RunLoopActivityAttributes.swift # Live Activity (optional)
│   ├── Resources/
│   │   └── chime.wav                       # Alert sound (add manually)
│   └── Info.plist                          # Configuration
└── RunLoopTests/
    └── IntervalEngineTests.swift           # Unit tests
```

## Xcode Setup Steps

### 1. Create New Project

1. Open Xcode
2. File > New > Project
3. Choose **iOS** > **App**
4. Fill in:
   - **Product Name:** RunLoop
   - **Team:** Your team
   - **Organization Identifier:** com.example
   - **Bundle Identifier:** com.example.runloop
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum iOS Version:** iOS 17.0

### 2. Add Source Files

Copy all `.swift` files to the project:

1. Drag the `RunLoop/` source folder into Xcode
2. Select **Create groups**
3. Ensure **Copy items if needed** is checked
4. Add to target: **RunLoop**

### 3. Configure Target Settings

#### General Tab

- **Display Name:** RunLoop
- **Bundle Identifier:** com.example.runloop
- **Version:** 1.0.0
- **Build:** 1
- **Minimum Deployments:** iOS 17.0

#### Signing & Capabilities Tab

Add the following capabilities:

**Required:**

1. **Background Modes**
   - Click **+ Capability** > **Background Modes**
   - Enable: ☑️ **Audio, AirPlay, and Picture in Picture**
   - This allows background audio for timer accuracy

**Optional (for Live Activity):**

2. **Push Notifications**
   - Click **+ Capability** > **Push Notifications**
   - Required only if implementing Live Activity
   - Ensure you have a provisioning profile with push enabled

### 4. Info.plist Configuration

Use the provided `Info.plist` or manually add these keys:

#### Required Keys

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

This enables background audio, keeping the timer running when the screen is locked.

#### Privacy Keys

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>RunLoop uses speech synthesis to announce interval transitions during your workout.</string>
```

Required for voice announcements (even though we only use synthesis, not recognition).

#### Live Activity (Optional)

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

Enables Live Activity support for Dynamic Island.

### 5. Add Audio Asset (chime.wav)

You need to add an audio file for interval alerts:

1. Find or create a short chime sound (1-2 seconds, .wav format)
2. Drag `chime.wav` into the `Resources/` folder in Xcode
3. In the dialog:
   - ☑️ **Copy items if needed**
   - ☑️ Add to target: **RunLoop**
4. Verify in **Build Phases** > **Copy Bundle Resources**

**Sound Requirements:**
- Format: `.wav`, `.aif`, or `.m4a`
- Duration: 1-2 seconds (under 30s for notifications)
- Sample rate: 44.1 kHz recommended
- Channels: Mono or stereo

**Where to find sounds:**
- Create using GarageBand or Audacity
- Use Apple's system sounds (with attribution)
- Download from freesound.org (check licenses)

**Fallback:** If `chime.wav` is missing, the app uses system sound ID 1007 as fallback.

### 6. Build Settings

Verify these settings in **Build Settings**:

- **Swift Language Version:** Swift 5
- **iOS Deployment Target:** 17.0
- **Supported Platforms:** iOS
- **Enable Bitcode:** No (deprecated)

### 7. Unit Test Setup

1. Create test target (should exist by default: **RunLoopTests**)
2. Add `IntervalEngineTests.swift` to test target
3. In test file's **Target Membership**, ensure **RunLoopTests** is checked
4. Add `@testable import RunLoop` at the top

Run tests: **⌘U** or Product > Test

## Entitlements File (Optional)

If you add Push Notifications, Xcode will create `RunLoop.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.pushkit.unrestricted-voip</key>
    <false/>
</dict>
</plist>
```

## App Icon

Add an app icon:

1. Create icon set (1024×1024 for App Store, plus various sizes)
2. In Xcode, select **Assets.xcassets** > **AppIcon**
3. Drag icon images into appropriate slots
4. Or use a tool like [AppIconGenerator](https://appicon.co/)

## Permissions & First Launch

### Notification Permission

The app requests notification permission on first launch via `NotificationService.requestPermission()`.

**User sees:**
> "RunLoop" Would Like to Send You Notifications

**Grant permission** to receive alerts when the app is backgrounded.

### Background Audio

No explicit permission required. The app automatically configures `AVAudioSession` when a session starts.

## Testing Background Behavior

### Simulator Testing

Background audio **does not work reliably in Simulator**. You must test on a real device.

### Device Testing

1. Build and run on a physical iPhone (iOS 17+)
2. Start a workout with a short interval (e.g., 30 seconds)
3. Lock the screen (power button)
4. Wait for interval boundary
5. You should hear the chime and feel haptic feedback
6. Unlock to verify timer accuracy

### Debugging Tips

- Use `print()` statements to log events (visible in Xcode console)
- Check **Console** app on Mac to view device logs
- Test with device plugged in to see real-time logs
- Verify audio file is in bundle: `Bundle.main.url(forResource: "chime", withExtension: "wav")`

## Common Issues & Solutions

### Issue: Alerts don't fire in background

**Causes:**
- Background Modes > Audio not enabled
- Notification permission not granted
- Audio session not configured
- Silent mode on (for audio only; haptics should still work)

**Solutions:**
1. Check **Signing & Capabilities** > **Background Modes** > Audio ✓
2. Settings > RunLoop > Notifications > Allow Notifications ✓
3. Ensure `AudioService.configureSession()` is called
4. Test with device volume up

### Issue: Timer drifts over time

**Causes:**
- Using `Timer` alone without absolute dates
- Heavy CPU usage from other apps
- Low Power Mode throttling

**Solutions:**
- The `IntervalEngine` uses absolute `Date` calculations to avoid drift
- Test in Release mode, not Debug (less overhead)
- Expected accuracy: ≤ 0.5s drift per 10 minutes

### Issue: Voice announcements don't play

**Causes:**
- Voice toggle disabled in Settings
- `AVSpeechSynthesizer` interrupted by other audio
- Low Power Mode may throttle speech

**Solutions:**
1. Open app Settings > Voice > ON
2. Close other audio apps (music, podcasts)
3. Disable Low Power Mode
4. Check device volume

### Issue: App terminates in background

**Causes:**
- iOS suspends app due to low memory or battery
- Background task takes too long
- App enters background without audio session active

**Solutions:**
- Keep audio session active during workout
- Scheduled notifications will still fire even if app is terminated
- Use "Keep Screen Awake" setting for long workouts

## Release Build Configuration

For production release:

1. **Set Bundle ID to your actual ID:**
   - Target > General > Bundle Identifier
   - Change from `com.example.runloop` to your registered ID

2. **Configure Signing:**
   - Target > Signing & Capabilities
   - Select your **Team** and provisioning profile
   - Ensure **Automatically manage signing** is enabled

3. **Set Version Numbers:**
   - Version: User-visible version (e.g., 1.0.0)
   - Build: Increment for each upload (1, 2, 3...)

4. **Archive for Distribution:**
   - Product > Archive
   - Xcode > Organizer > Archives
   - Distribute App > App Store Connect

## Advanced Configuration

### Live Activity Setup

If using Live Activity (Dynamic Island):

1. Add **Push Notifications** capability
2. Add `NSSupportsLiveActivities` to Info.plist
3. Create widget extension (if custom widget UI needed)
4. Integrate `LiveActivityManager` in `IntervalViewModel`:

```swift
private let liveActivityManager = LiveActivityManager()

// In start():
await liveActivityManager.start(
    presetName: preset.name,
    initialState: RunLoopActivityAttributes.ContentState(
        currentIntervalTitle: preset.intervals[0].title,
        remainingTime: preset.intervals[0].duration,
        intervalColorHex: preset.intervals[0].colorHex,
        isPaused: false,
        currentCycle: 1,
        totalCycles: preset.cycleCount,
        nextIntervalTitle: preset.intervals[safe: 1]?.title
    )
)

// Update on transitions:
await liveActivityManager.update(state: ...)

// End on finish:
await liveActivityManager.end()
```

### Custom Notification Sounds

To use a custom sound for notifications:

1. Add sound file to bundle (e.g., `custom_chime.aif`)
2. Update `NotificationService.swift`:

```swift
content.sound = UNNotificationSound(named: UNNotificationSoundName("custom_chime.aif"))
```

### Analytics Integration (Future)

To add analytics (e.g., tracking workout completions):

1. Add analytics framework (e.g., TelemetryDeck, Firebase)
2. Track events in engine callbacks:
   - `onIntervalTransition`: Log interval completions
   - `onSessionFinish`: Log full workout completions

## Performance Optimization

### Battery Usage

The app is designed for minimal battery impact:
- High-frequency timer (50ms) for UI updates only
- Audio session kept alive (low power)
- Scheduled notifications as fallback
- No background fetch or location services

Expected battery usage: **< 5% per hour** during active workout.

### Memory Usage

- Models are lightweight value types (structs)
- Timeline pre-computed at start (tradeoff: memory for accuracy)
- Infinite presets capped at 1000 cycles (2000 boundaries) to prevent memory issues

Expected memory: **< 50 MB** during workout.

## App Store Submission Checklist

Before submitting to App Store:

- [ ] Bundle ID registered in Apple Developer Portal
- [ ] App icon added (all sizes)
- [ ] Screenshots prepared (6.5", 5.5" displays)
- [ ] Privacy policy URL (if collecting data)
- [ ] App description and keywords
- [ ] Support URL or email
- [ ] Test on multiple devices (iPhone SE, iPhone 15 Pro Max)
- [ ] Verify background audio works on real device
- [ ] Run unit tests (⌘U)
- [ ] Check for compiler warnings
- [ ] Review accessibility (VoiceOver support)
- [ ] Set version to 1.0.0, build to 1
- [ ] Archive and validate with Xcode

## Additional Resources

- [Apple: Playing Audio in the Background](https://developer.apple.com/documentation/avfoundation/media_playback/creating_a_basic_video_player_macos)
- [Apple: ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Apple: User Notifications](https://developer.apple.com/documentation/usernotifications)
- [Apple: Core Haptics](https://developer.apple.com/documentation/corehaptics)

---

**Questions or issues?** Check the main [README.md](README.md) for troubleshooting tips.
