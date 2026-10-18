# TestFlight public beta

How StockSim is shipped as a TestFlight public link. The App Store is not used.

## What the distribution build contains

Every **Release** build (Product → Archive) is the distribution build:

| | Developer build (Debug) | Distribution build (Release) |
|---|---|---|
| Market data | Simulator or delayed real data | Simulator only; the real-data module compiles to nothing (`REAL_DATA` is defined for Debug only in `MarketKit/Package.swift`) |
| Companies | Real BIST tickers, simulated prices | Fictional companies (`FictionalCatalog`) |
| Network | Real-data mode only | None |
| About sheet | From the badge menu | Also shown once on first launch |

Run the app with `-distribution` in a Debug build to try the distribution behavior (in memory, so saved developer data is not mixed in).

Already in the project:

- `PrivacyInfo.xcprivacy`: no tracking, no collected data; `UserDefaults` accessed with reason `CA92.1` (the app's own settings).
- `ITSAppUsesNonExemptEncryption = NO`: no export compliance question on upload.
- iPhone only, portrait.
- Privacy policy: [PRIVACY.md](../PRIVACY.md).

## Steps

1. **Apple Developer Program** membership (paid). A free personal team cannot upload to TestFlight.
2. **App Store Connect → Apps → + → New App**
   - Platform: iOS · Name: `StockSim` (must be unique on the App Store; if taken, e.g. `StockSim Paper Trading`)
   - Primary language: English · Bundle ID: `com.alicankurt.StockSim` · SKU: `stocksim`
3. **Xcode:** select **Any iOS Device (arm64)** → **Product → Archive**.
   Organizer → **Distribute App → App Store Connect → Upload**. Keep automatic signing.
4. Wait for processing (usually 10–30 minutes). The build appears under **TestFlight**.
5. **TestFlight → Test Information**
   - Beta App Description (below)
   - Feedback email
   - Privacy Policy URL: `https://github.com/alicankurt1/StockSim-iOS/blob/main/PRIVACY.md`
   - Beta App Review Information: contact details; **Sign-in required: No**; review notes (below)
6. **App Privacy** (left menu): **Data Not Collected**.
7. **TestFlight → External Testing → +** create a group (e.g. `Public`) → add the build → **Submit for Review**. The first build of a version goes through Beta App Review (often within a day).
8. After approval: in the group, **Enable Public Link**, optionally set a tester limit, and share the link.

For each new upload, increase **Build** (`CURRENT_PROJECT_VERSION`). TestFlight builds expire after 90 days.

### Beta App Description

> StockSim is an educational paper-trading simulator. Trade fictional companies with ₺100,000 of virtual cash on a simulated market, follow live-moving charts and try "what if I had invested" scenarios. No real money, no real market data, no account. Not investment advice. Open source (MIT).

### Review notes

> Educational, open-source app built to practise iOS development. All companies are fictional and all prices are generated on the device by a random simulator; the app makes no network requests and collects no data. No sign-in. Shake the device (or open the SIMULATED badge menu → Market controls) to trigger simulated market events such as a crash or a trading halt.
