# RunLoop - Quick Start Guide

Get RunLoop running in under 5 minutes.

## Prerequisites

- macOS with Xcode 15+ installed
- iOS 17+ device (Simulator won't work for background testing)
- Apple Developer account (free tier is fine for device testing)

## Step-by-Step Setup

### 1. Create Xcode Project (2 minutes)

```bash
# Open Xcode
# File > New > Project > iOS > App
```

**Settings:**
- Product Name: `RunLoop`
- Team: Select your team
- Organization Identifier: `com.yourname` (change from example)
- Bundle Identifier: `com.yourname.runloop`
- Interface: **SwiftUI**
- Language: **Swift**
- Minimum iOS: **17.0**

Click **Next** > Choose location > **Create**

### 2. Add Source Files (1 minute)

Copy all files from this repository to your project:

```bash
# In Terminal, from this directory:
cp -r RunLoop/* /path/to/your/Xcode/RunLoop/RunLoop/
```

Or manually:
1. Open Finder to this `RunLoop/` folder
2. Drag `RunLoop/` folder into Xcode project navigator
3. Select: ✓ Copy items, ✓ Create groups, ✓ Add to target: RunLoop

### 3. Configure Capabilities (1 minute)

1. Select project in navigator
2. Select **RunLoop** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Background Modes**
6. Enable: ☑️ **Audio, AirPlay, and Picture in Picture**

### 4. Add Audio File (30 seconds)

**Option A - Use System Sound (Quick):**
- Skip this step! The app has a fallback to system sound.

**Option B - Add Custom Chime:**
1. Find or create a short audio file (1-2 sec, .wav format)
2. Name it `chime.wav`
3. Drag into Xcode project
4. Check: ✓ Copy items, ✓ Add to target: RunLoop

**Where to get sounds:**
- macOS: `/System/Library/Sounds/` (copy and convert)
- GarageBand: Create a simple bell/chime
- Online: freesound.org (check licenses)

### 5. Build & Run (30 seconds)

1. Connect your iPhone via USB
2. Select your device in Xcode toolbar
3. Press **⌘R** (or click Run button)
4. First time: Trust developer on device (Settings > General > VPN & Device Management)

**App should launch!**

## First Use

### Grant Permissions

On first launch, the app will request:

1. **"RunLoop Would Like to Send You Notifications"**
   - Tap **Allow**
   - Required for background alerts

### Start Your First Workout

1. Select a preset (default: "Run/Walk 4–1")
2. Tap **Start**
3. Lock your screen
4. Wait ~4 minutes
5. You'll hear a chime and feel haptic at the interval boundary!

### Test Background Reliability

1. Start a short preset (e.g., Run 0:30 / Walk 0:15)
2. Lock screen
3. Put phone down
4. Alerts should fire every 30/15 seconds even when locked

## Troubleshooting

### "No alerts when screen locked"

**Check:**
- Settings > RunLoop > Notifications > **Allow Notifications** ✓
- Xcode project > Capabilities > Background Modes > **Audio** ✓
- Device volume is up (not muted)
- Testing on **real device**, not Simulator

### "Build failed"

**Common fixes:**
- Clean build folder: **⌘⇧K** (Shift-Command-K)
- Restart Xcode
- Ensure all files are added to target (check Target Membership)
- Minimum iOS version set to 17.0

### "App crashes on launch"

**Check:**
- All Swift files are in the target
- No duplicate files
- Info.plist is correct
- Run tests: **⌘U** to validate core logic

## What's Next?

### Customize the App

**Easy changes:**
- **App Name:** Xcode > Target > General > Display Name
- **Bundle ID:** Xcode > Target > General > Bundle Identifier
- **Default Presets:** Edit `Preset.defaults` in `Preset.swift`
- **Colors:** Edit hex values in `Interval.swift` samples

### Add Your Own Presets

1. Open app > Tap **+** (top left)
2. Name your workout
3. Add intervals with **+ Add Interval**
4. Set durations, colours, voice cues
5. Choose cycle count or infinite
6. Tap **Save**

### Configure Settings

Tap **⚙️** (gear icon) to adjust:
- **Sounds:** Enable/disable chimes
- **Voice:** Enable/disable announcements
- **Haptics:** Enable/disable vibrations
- **Speech Rate:** Slow ←→ Fast
- **Count-In:** 3-2-1 before first interval
- **Keep Screen Awake:** Prevent auto-lock

## Testing Checklist

- [ ] App launches without errors
- [ ] Can create a new preset
- [ ] Can start a workout
- [ ] Timer counts down correctly
- [ ] Lock screen → alerts still fire
- [ ] Pause/resume works
- [ ] Skip forward/back works
- [ ] Stop ends session
- [ ] Settings changes take effect
- [ ] Background audio continues when screen locked

## Advanced Setup (Optional)

### Enable Live Activity (Dynamic Island)

1. Add capability: **Push Notifications**
2. Edit Info.plist: Add key `NSSupportsLiveActivities` = `YES`
3. Integrate `LiveActivityManager` in `IntervalViewModel` (see CONFIGURATION.md)

### Run Unit Tests

Press **⌘U** or Product > Test

Should see 15+ tests pass.

### Profile Performance

1. Product > Profile (⌘I)
2. Select **Time Profiler**
3. Start workout
4. Verify low CPU usage (< 5%)

## Complete Documentation

For full details, see:
- **README.md** - Architecture, features, troubleshooting
- **CONFIGURATION.md** - Xcode setup, capabilities, entitlements
- **PROJECT_SUMMARY.md** - File structure, testing, statistics

## Getting Help

**Common Issues:**
1. Simulator: Background audio doesn't work → Use real device
2. No sound: Check volume, add `chime.wav`, verify in bundle
3. Drift: Expected < 0.5s per 10 min; test in Release mode
4. Crashes: Run unit tests (⌘U) to validate logic

**Still stuck?**
- Check Xcode console for error messages
- Review Info.plist keys
- Verify all files are in target membership
- Clean build and restart Xcode

---

## That's It!

You now have a fully functional interval timer app with background reliability.

**Total setup time: ~5 minutes**

Happy running! 🏃‍♂️⏱️
