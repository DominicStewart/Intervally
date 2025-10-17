# Apple Watch Setup Instructions

This setup enables **always-on display** for your workout using HealthKit workout sessions. When you start a workout on iPhone, your Watch will automatically show the timer when you raise your wrist with smooth, autonomous operation.

## Step 1: Add Watch Target in Xcode

1. In Xcode, select File → New → Target
2. Choose "Watch App" (not "Watch App for iOS App")
3. Name it "Intervally Watch"
4. Set Product Name: "Intervally Watch"
5. Set Bundle Identifier: `com.dominic.intervally.watchkitapp`
6. Click Finish
7. When prompted "Activate scheme?", click Activate

## Step 2: Configure Xcode Project Settings

### A. Add HealthKit Capability to Watch App

1. Select **Intervally Watch App** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Search for and add **HealthKit**
5. This will automatically create the entitlements file

### B. Assign Entitlements File

1. Still in **Intervally Watch App** target
2. Go to **Build Settings** tab
3. Search for "Code Signing Entitlements"
4. Set value to: `Intervally Watch App/Intervally_Watch.entitlements`

### C. Configure Info.plist

The Watch app's Info.plist should have these keys:
- `NSHealthShareUsageDescription`: "Intervally needs access to read workout data to provide accurate interval training metrics."
- `NSHealthUpdateUsageDescription`: "Intervally needs access to save workout data to track your interval training sessions in the Health app."

**Note:** No background modes are required in Info.plist - HealthKit workout sessions automatically provide background execution.

### D. Add WatchConnectivity Configuration

#### For iOS App (Intervally iOS App target):
1. Select "Intervally iOS App" target → Info tab
2. Add a new row:
   - Key: `WKCompanionAppBundleIdentifier`
   - Type: String
   - Value: `com.dominic.intervally`

#### For Watch App target:
1. Select "Intervally Watch App" target → Info tab
2. Add a new row:
   - Key: `WKAppBundleIdentifier`
   - Type: String
   - Value: `com.dominic.intervally.watchkitapp`

## Step 3: Verify Watch App Files

These files have been created with autonomous workout support:

### File 1: `Intervally_WatchApp.swift`
Main app entry point - sets up WatchConnectivityManager

### File 2: `ContentView.swift`
Main UI with enhanced workout display showing:
- **LIVE** indicator when HealthKit workout session is active
- Color-coded interval name
- Large timer display with second-by-second countdown
- Pause status indicator

### File 3: `WatchConnectivityManager.swift`
Manages iPhone ↔ Watch communication and autonomous timer:
- **Autonomous operation**: Runs independent countdown timer after receiving workout structure
- **Fast updates**: 0.5s when active, 2s when screen dimmed
- **Local interval transitions**: Handles transitions without iPhone
- **Intelligent sync**: Requests full workout structure on late-join
- **Type-safe messaging**: Distinguishes between timer updates and workout structure

### File 4: `WorkoutManager.swift`
Manages HealthKit workout session:
- **Always-on display**: Screen stays visible when you raise your wrist
- **Background execution**: Continues running even when screen is off
- **Conditional saving**: Saves workout to Health app only when enabled in preset
- **Automatic raise-to-wake**: Shows your app when you lift your wrist
- **Error recovery**: Handles HealthKit state machine errors gracefully

## Step 4: Build and Test

### First Time Setup:
1. Build and install **both** the iPhone app AND Watch app on your devices
2. On your iPhone, open the Watch app and ensure Intervally appears in "My Watch"
3. Make sure the Intervally Watch app is installed on the Watch

### Testing the Always-On Workout:
1. **Start workout on iPhone** - Open the Intervally app and start any workout
2. **Check Watch syncs** - Within 1-2 seconds, watch should show:
   - Current interval (Walk, Run, etc.)
   - Remaining time counting down every 0.5 seconds
   - Color-coded display matching iPhone
   - **LIVE** indicator with green dot (confirms HealthKit session active)
3. **Put iPhone in pocket** - Lock it, put it away
4. **Raise your wrist** - Watch continues showing timer autonomously
5. **Lower your wrist** - Screen dims but timer continues (updates every 2s)
6. **Raise again anytime** - Instantly see current workout state
7. **Feel haptics** - Strong vibration on interval transitions (if enabled in preset)

### Testing Late-Join (Opening Watch Mid-Workout):
1. **Start workout on iPhone** - Begin any preset
2. **Wait 30 seconds** - Let a few seconds pass
3. **Open Watch app** - Raise wrist to open Intervally
4. **Watch should**:
   - Show current interval and time (syncs from iPhone)
   - Display **LIVE** indicator within 2-3 seconds
   - Switch to fast 0.5s updates
   - Continue running autonomously

### What You Should See:

**On iPhone:**
- Console logs: "📲 Workout started: [Preset Name]"
- Console logs: "📲 Updated watch context (timer update)"
- Console logs: "📱 Sent full workout sync to Watch (late-join)" (if opened mid-workout)

**On Watch:**
- Console logs: "⌚️ Workout started: [Preset Name]"
- Console logs: "⌚️ Loaded X intervals, Y cycles"
- Console logs: "⌚️ Running in AUTONOMOUS mode - ignoring iPhone updates"
- Console logs: "✅ Workout session started"
- Console logs: "⌚️ Started autonomous countdown timer (interval: 0.5s)"
- Console logs: "⌚️ Always-On mode: OFF" (when active) or "ON" (when dimmed)
- UI shows **LIVE** indicator with green dot
- Timer updates smoothly every 0.5 seconds when active

## Step 5: Grant HealthKit Permissions (First Launch)

When you first start a workout after installing the Watch app:

1. Watch will prompt: "Intervally would like to access your Health data"
2. Tap **Allow**
3. The workout session will start
4. Raise-to-wake should now work automatically

## How It Works

### Autonomous Watch Operation:
1. **iPhone** sends full workout structure (intervals, durations, colors, cycles) to **Watch**
2. **Watch** receives workout data and stores it locally
3. **Watch** starts HealthKit workout session (for always-on display)
4. **Watch** runs independent countdown timer:
   - 0.5 second updates when screen active
   - 2.0 second updates when screen dimmed (Always-On mode)
5. **Watch** handles interval transitions locally without iPhone
6. **iPhone** only sends pause/resume/stop commands
7. When workout ends:
   - If preset has "Track as HealthKit Workout" ON → Save to Health app
   - If preset has "Track as HealthKit Workout" OFF → Discard workout data

### Per-Preset HealthKit Control:
Each preset has a toggle "Track as HealthKit Workout":
- **Enabled** (default): Full HealthKit workout tracking, data saved to Health app
- **Disabled**: HealthKit session still runs (for always-on display) but workout is discarded on completion

This allows you to use the same app for fitness workouts AND productivity timers (Pomodoro, cooking, etc.) without cluttering your Health app data.

### Communication Flow:
1. **iPhone** → WatchConnectivity → **Watch**: "workoutStarted" message with full structure
2. **Watch** parses intervals, starts HealthKit session, starts autonomous timer
3. **Watch** runs independently, displaying intervals and handling transitions
4. **iPhone** sends periodic "timerUpdate" messages (every 10s, for late-join scenarios)
5. If **Watch** opened mid-workout:
   - Receives "timerUpdate" → Displays current time (slow 10s updates)
   - Requests "requestSync" → Receives full workout structure
   - Switches to autonomous mode with fast 0.5s updates
6. **iPhone** → **Watch**: "workoutStopped" message
7. **Watch** ends workout session, saves or discards based on preset setting

### Message Types:
- `workoutStarted`: Contains full workout structure, triggers autonomous mode
- `timerUpdate`: Simple state update (for late-join scenarios)
- `intervalTransition`: Ignored when watch is autonomous
- `workoutStopped`: Ends workout session
- `requestSync`: Watch requests full workout structure

## Troubleshooting

### Watch doesn't show workout when raising wrist:
- Ensure HealthKit permission was granted (check Watch Settings → Privacy → Health)
- Verify you see **LIVE** indicator with green dot in the app
- Make sure you're testing on a **physical Watch** (simulators don't support raise-to-wake)
- Check Xcode console for "✅ Workout session started"
- Look for "⌚️ Running in AUTONOMOUS mode" log

### Watch timer updates slowly (every 10 seconds):
- This means watch is NOT in autonomous mode
- Check logs for "⚠️ WARNING: Receiving simple updates without full workout structure"
- Watch should automatically request full sync - look for "⌚️ Requesting full workout structure"
- If sync fails, restart workout and open Watch immediately

### "WCSession counterpart app not installed" errors:
- Install the Watch app from your iPhone's Watch app
- Wait for installation to complete
- Restart both devices if needed

### Workout session doesn't start:
- Check for HealthKit authorization errors in console
- Ensure the entitlements file is properly configured
- Verify HealthKit capability is added in Xcode
- Look for "❌ Failed to start workout session" errors

### Display turns off too quickly:
- This is normal battery-saving behavior (Always-On mode)
- Timer still updates every 2 seconds when dimmed
- Just raise your wrist again to see full update rate (0.5s)
- The workout continues running in background

### App closes when wrist lowered (no LIVE indicator):
- HealthKit session didn't start - check permissions
- Look for errors in console about HealthKit
- Verify workout was started on iPhone first
- Try restarting both devices

### Workout not saved to Health app (when it should be):
- Check preset settings - "Track as HealthKit Workout" should be ON
- Verify HealthKit write permission granted
- Look for "✅ Workout saved to Health app" log on Watch
- If you see "⚠️ Discarding workout", the toggle was OFF

## Performance Notes

### Battery Usage:
- HealthKit workout sessions are optimized by watchOS
- Autonomous mode reduces iPhone-Watch communication
- Update intervals are adjusted for Always-On mode
- Expected battery usage: ~5-10% per hour during workout

### Update Intervals:
- **Active (screen on)**: 0.5 seconds - smooth countdown
- **Dimmed (Always-On)**: 2.0 seconds - battery efficient
- **Late-join fallback**: 10 seconds - until full sync completes

### Accuracy:
- Watch uses local timer for smooth updates
- No dependency on iPhone communication after initial sync
- Interval transitions happen on time, independent of iPhone
- Max 2s delay in dimmed mode is cosmetic only (transitions still fire on time)

## Notes

- **Always-on works ONLY on physical Watch** (not simulator)
- First workout requires HealthKit permission prompt
- Workout data saved to Health app only when preset toggle is ON
- Battery usage is optimized by watchOS (screen dims when wrist is lowered)
- Watch runs completely independently after receiving workout structure
- Late-join sync happens automatically within 1-2 seconds
- Haptics can be disabled per-preset in iPhone app settings
