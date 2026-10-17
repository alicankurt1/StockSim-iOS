# Performance

How the watchlist stays smooth under heavy price traffic, and how to measure it.

## Load scenario

Launch arguments (Xcode → Product → Scheme → Edit Scheme → Run/Profile → Arguments):

| Argument | Effect |
|---|---|
| `-stressTest` | 120 generated tickers, one tick every 100 ms → **1,200 price updates/second**. Account and lists stay in memory (saved data is not touched). |
| `-noBatching` | Watchlist applies every price update separately (the "before" state). |

## What changed

| Change | Why |
|---|---|
| **Frame-based batching** (`UpdateCoalescer` + `FrameScheduler`) | Each price update used to trigger its own diffable `apply`. Updates are now collected and applied once per frame (capped at 30 fps for the list); only the latest value per symbol is kept. 1,200 updates/s become at most 30 applies/s. |
| **`reconfigureItems` with stable identifiers** (Phase 3) | Price changes update the existing cell instead of deleting and inserting rows. |
| **Rounded labels without masking** | `clipsToBounds` + `cornerRadius` on a label with content forces an extra off-screen render pass. The background is now drawn by the layer itself (`layer.backgroundColor`), which rounds without a mask. |
| **Layers built once, paths updated** (Phase 4) | Sparklines reuse their `CAShapeLayer`s; only the path changes on reuse and on updates. |

## How to measure

1. Select an **iOS Simulator or device**, then **Product → Profile** (⌘I) with `-stressTest`.
2. **Time Profiler** + **os_signpost** (or the *Points of Interest* track):
   - The `Watchlist apply` interval shows how often a batch is applied and how many rows it carries.
   - Record 20 seconds with the watchlist on screen, then compare the main-thread CPU %.
3. **Animation Hitches** (device recommended): scroll the list while prices stream; compare the hitch time ratio.
4. **Color Off-screen Rendered** (Simulator → Debug menu): rounded pills should no longer be tinted yellow.
5. Repeat with `-stressTest -noBatching` for the "before" numbers.

## Results

Measured on: iPhone 17 Pro Simulator (iOS 26.1) on an Apple M4 Mac, Release build, `-stressTest`, 20-second Time Profiler recordings (`xctrace`) taken 5 seconds after launch with the watchlist on screen.

| Metric (20 s, `-stressTest`) | `-noBatching` (before) | Batched (after) |
|---|---|---|
| `Watchlist apply` intervals / second | 1,160 | 10.9 |
| Rows per apply (average) | 1.0 | 105.9 |
| Main thread CPU | 57.9 % | 11.3 % |
| App CPU (all threads) | 59.2 % | 13.3 % |

**Reading the numbers**

- Before: every price update became its own diffable apply (~1,160/s) and the main thread was busy more than half of the time.
- After: updates arrive in bursts (one tick = 120 prices every 100 ms), and each burst collapses into a single apply. That is why the rate is ~11/s rather than the 30 fps cap: there is simply nothing new to apply between ticks. Main-thread CPU drops about 5×.
- Simulator numbers are not device numbers; the before/after ratio is what matters. Hitch measurements (Animation Hitches) and off-screen rendering checks are best done on a device / with the Simulator debug overlays and are not included here.
