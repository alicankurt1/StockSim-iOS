---
name: verify
description: Run all StockSim tests (MarketKit package on macOS, app unit + UI tests in the simulator) and launch the app in the iOS Simulator for a screenshot. Use after any code change, before committing, or when the user says "verify", "test et", "doğrula".
---

# Verify

Run the steps in order and stop at the first failure. Report failures with the relevant output; never hide or skip a failing step.

## 1. Package tests (no simulator)

```bash
swift test --package-path MarketKit
```

Optional argument `quick`: run only this step and stop.

## 2. App tests (simulator)

```bash
xcodebuild test -project StockSim/StockSim.xcodeproj -scheme StockSim -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

- Report the list of passed/failed test cases.
- Also check for compiler warnings in our own code (ignore tool noise such as `appintentsmetadataprocessor`). Treat new warnings as something to fix.

## 3. Visual check (only if UI changed in this phase)

1. Open the simulator panel first: `mcp__Claude_Code_iOS_Simulator__control` with `action: attach`, `device: iPhone 17` (boot it with `xcrun simctl boot "iPhone 17"` if needed).
2. Find the built app:
   ```bash
   xcodebuild -project StockSim/StockSim.xcodeproj -scheme StockSim -destination 'platform=iOS Simulator,name=iPhone 17' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3"/StockSim.app"}'
   ```
3. `action: launch` with that `app_path`, then `action: screenshot`.
4. Navigate to the screen that changed (tap / swipe) and screenshot it. Check dark mode too when colors or drawing changed (`xcrun simctl ui booted appearance dark`, then reset to `light`).

## 4. Summary

Reply in Turkish with:

- Package tests: passed / failed (count)
- App tests: passed / failed (count), new warnings
- What the screenshot shows, and whether it matches the expected behavior
