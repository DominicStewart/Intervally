# Apple Watch Setup Instructions with WorkoutKit

This setup enables **always-on display** for your workout using HealthKit workout sessions. When you start a workout on iPhone, your Watch will automatically show the timer when you raise your wrist - no need to open any app!

## Step 1: Add Watch Target in Xcode

1. In Xcode, select File → New → Target
2. Choose "Watch App" (not "Watch App for iOS App")
3. Name it "Intervally Watch"
4. Set Product Name: "Intervally Watch"
5. Set Bundle Identifier: `com.example.runloop.watchkitapp`
6. Click Finish
7. When prompted "Activate scheme?", click Activate

## Step 2: Configure Xcode Project Settings

### A. Add HealthKit Capability to Watch App

1. Select **Intervally Watch Watch App** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Search for and add **HealthKit**
5. This will automatically create the entitlements file

### B. Assign Entitlements File

1. Still in **Intervally Watch Watch App** target
2. Go to **Build Settings** tab
3. Search for "Code Signing Entitlements"
4. Set value to: `Intervally Watch Watch App/Intervally_Watch.entitlements`

### C. Configure Info.plist

The Watch app's Info.plist should already have these keys (they were added via code):
- `NSHealthShareUsageDescription`: "Intervally needs access to read workout data to provide accurate interval training metrics."
- `NSHealthUpdateUsageDescription`: "Intervally needs access to save workout data to track your interval training sessions in the Health app."

### D. Add WatchConnectivity Configuration

#### For iOS App (RunLoop target):
1. Select RunLoop target → Info tab
2. Add a new row:
   - Key: `WKCompanionAppBundleIdentifier`
   - Type: String
   - Value: `com.example.runloop`

#### For Watch App target:
1. Select Intervally Watch target → Info tab
2. Add a new row:
   - Key: `WKAppBundleIdentifier`
   - Type: String
   - Value: `com.example.runloop.watchkitapp`

## Step 3: Verify Watch App Files

These files have been created for you with WorkoutKit support:

### File 1: `Intervally_WatchApp.swift`
Main app entry point - sets up WatchConnectivityManager

### File 2: `ContentView.swift`
Main UI with enhanced workout display showing:
- Live indicator when workout session is active
- Color-coded interval name
- Large timer display
- Pause status

### File 3: `WatchConnectivityManager.swift`
Manages iPhone ↔ Watch communication and integrates WorkoutManager for always-on display

### File 4: `WorkoutManager.swift` (NEW - WorkoutKit Integration)
Manages HealthKit workout session:
- **Always-on display** - Screen stays visible when you raise your wrist
- **Background execution** - Continues running even when screen is off
- **Health app integration** - Saves workout to Apple Health
- **Automatic raise-to-wake** - Shows your app when you lift your wrist

## Step 4: Build and Test

### First Time Setup:
1. Build and install **both** the iPhone app AND Watch app on your devices
2. On your iPhone, open the Watch app and ensure your custom app appears in "My Watch"
3. Make sure the Intervally Watch app is installed on the Watch

### Testing the Always-On Workout:
1. **Start workout on iPhone** - Open the Intervally app and start any workout
2. **Put iPhone in pocket** - Lock it, put it away
3. **Raise your wrist** - The Watch should automatically show your app with:
   - Current interval (Walk, Run, etc.)
   - Remaining time counting down
   - Color-coded display
   - "LIVE" indicator showing workout session is active
4. **Lower your wrist** - Screen turns off to save battery
5. **Raise again anytime** - Instantly see current workout state
6. **Feel haptics** - Strong vibration on interval transitions

### What You Should See:

**On iPhone:**
- Console logs: "📲 Workout started: [Preset Name]"
- Console logs: "📲 Interval transition: [Interval Name]"

**On Watch:**
- Console logs: "⌚️ Workout started: [Preset Name]"
- Console logs: "✅ Workout session started"
- Console logs: "⌚️ Workout state: Running"
- UI shows "LIVE" indicator with green dot
- **Automatic display when raising wrist** - This is the key feature!

## Step 5: Grant HealthKit Permissions (First Launch)

When you first start a workout after installing the Watch app:

1. Watch will prompt: "Intervally would like to access your Health data"
2. Tap **Allow**
3. The workout session will start
4. Raise-to-wake should now work automatically

## How It Works

### The Magic of WorkoutKit:
- When iPhone starts a workout, it sends a message to Watch
- Watch starts a **HealthKit workout session** (like Fitness+, Nike Run Club, etc.)
- iOS automatically treats this as a workout and:
  - Keeps your app visible when you raise your wrist
  - Allows background execution
  - Saves workout data to Health app
  - Enables water lock (prevents accidental taps)

### Communication Flow:
1. **iPhone** → WatchConnectivity → **Watch**: "Workout started"
2. **Watch** starts HealthKit workout session
3. **iPhone** continuously sends timer updates
4. **Watch** displays updates and stays ready for raise-to-wake
5. **iPhone** → **Watch**: "Workout stopped"
6. **Watch** ends workout session, saves to Health app

## Troubleshooting

### Watch doesn't show workout when raising wrist:
- Ensure HealthKit permission was granted (check Watch Settings → Privacy → Health)
- Verify you see "LIVE" indicator with green dot in the app
- Make sure you're testing on a **physical Watch** (simulators don't support raise-to-wake)
- Check Xcode console for "✅ Workout session started"

### "WCSession counterpart app not installed" errors:
- Install the Watch app from your iPhone's Watch app
- Wait for installation to complete
- Restart both devices if needed

### Workout session doesn't start:
- Check for HealthKit authorization errors in console
- Ensure the entitlements file is properly configured
- Verify HealthKit capability is added in Xcode

### Display turns off too quickly:
- This is normal battery-saving behavior
- Just raise your wrist again to see the current state
- The workout continues running in background

## Notes

- **Always-on works ONLY on physical Watch** (not simulator)
- First workout requires HealthKit permission prompt
- Workout data is automatically saved to Apple Health
- Battery usage is optimized by iOS (screen dims when wrist is lowered)
- Water lock is automatically enabled (prevents accidental taps during workout)
