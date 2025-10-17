# Live Activity Setup Instructions

Live Activities automatically display the timer on iPhone lock screen, Dynamic Island, and Apple Watch without needing to open any apps.

## Step 1: Add Widget Extension Target in Xcode

1. In Xcode, select File → New → Target
2. Choose "Widget Extension"
3. Name it "IntervallyWidget"
4. Product Name: `IntervallyWidget`
5. Bundle Identifier: `com.example.runloop.IntervallyWidget`
6. **Important:** Uncheck "Include Configuration Intent" (we don't need it)
7. Click Finish
8. When prompted "Activate scheme?", click Activate

## Step 2: Enable Live Activities in Info.plist

### For iOS App (RunLoop target):
1. Select RunLoop target → Info tab
2. Add a new row:
   - Key: `NSSupportsLiveActivities`
   - Type: Boolean
   - Value: YES

## Step 3: Add Widget Extension Files

Delete the default widget files and create these files in the `IntervallyWidget` folder:

### File 1: `IntervallyWidgetBundle.swift`
```swift
import WidgetKit
import SwiftUI

@main
struct IntervallyWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntervallyLiveActivity()
    }
}
```

### File 2: `IntervallyLiveActivity.swift`
(Use the file already created at `/Users/dominicstewart/GitHub/Intervally/xcode/IntervallyWidget/IntervallyLiveActivity.swift`)

### File 3: Add `IntervalActivityAttributes.swift` to Widget Target
1. Select the existing `IntervalActivityAttributes.swift` file in the project navigator
2. In File Inspector (right panel), check the box for "IntervallyWidget" target membership
3. This allows the widget to access the activity attributes

## Step 4: Update App Group (Optional but Recommended)

If you want to share data between the app and widget:

1. Add App Groups capability to both targets:
   - Select RunLoop target → Signing & Capabilities
   - Click + Capability → App Groups
   - Add group: `group.com.example.runloop`
   - Repeat for IntervallyWidget target

## Step 5: Test Live Activity

1. Select the "RunLoop" scheme (not the widget scheme)
2. Build and run on a physical device (Live Activities don't work in simulator reliably)
3. Start a workout
4. You should see:
   - **Lock Screen**: Full timer display with interval name, time, and cycle info
   - **Dynamic Island** (iPhone 14 Pro+): Compact timer in the notch
   - **Apple Watch**: Timer appears in Smart Stack automatically

## Step 6: Update Version

Update HomeView.swift version to reflect Live Activity support (already done).

## How It Works

- **Automatic Display**: When you start a workout, the Live Activity automatically appears on:
  - iPhone lock screen
  - Dynamic Island (iPhone 14 Pro and later)
  - Apple Watch (appears in Smart Stack without opening the app)

- **Real-Time Updates**: The timer updates continuously as intervals change

- **No Manual Opening Required**: Unlike the standalone Watch app, Live Activities appear automatically

## Troubleshooting

### Live Activity doesn't appear:
- Ensure `NSSupportsLiveActivities` is set to YES in Info.plist
- Check that you're testing on a physical device (not simulator)
- Verify Focus modes aren't blocking Live Activities in Settings

### Build errors:
- Make sure `IntervalActivityAttributes.swift` is added to both RunLoop AND IntervallyWidget targets
- Check that all imports are correct (ActivityKit, WidgetKit)

### Watch doesn't show timer:
- Live Activities on Watch require iOS 16.1+ and watchOS 9+
- The Watch must be paired and unlocked
- Live Activities appear in the Smart Stack (swipe up from watch face)

## Notes

- Live Activities require iOS 16.1+ and watchOS 9+
- They work even when the phone is locked
- Battery usage is minimal (updates are batched by the system)
- Live Activities automatically dismiss when the workout ends
- Maximum 8 hours duration (system limitation)
