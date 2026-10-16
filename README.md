# StockSim

A paper-trading stock app for iOS, built with **UIKit** and **Clean Swift (VIP)**.

- Watchlist with live prices, daily change and sparklines
- Line and candlestick charts drawn by hand (Core Graphics / `CAShapeLayer`) with crosshair
- Buy / sell with virtual cash, portfolio with average cost and P&L, persistent history
- Deterministic market simulator (geometric Brownian motion) with edge-case triggers: crash, volatility spike, trading halt, feed drop
- Optional delayed real end-of-day data and a "what if I had bought" tracker

> **Disclaimer:** This is an educational project. No real money is involved, real-market data is delayed and may be inaccurate, and nothing here is investment advice.

## Tech

Swift 6 (strict concurrency) · iOS 16+ · UIKit (programmatic) · Clean Swift (VIP) · Swift Testing · local Swift package `MarketKit` · no third-party dependencies.

See [PLAN.md](PLAN.md) for architecture and phases.

## Progress

| Phase | Topic | Status |
|---|---|---|
| 0 | Foundation | ✅ Done |
| 1 | Domain (TDD) | ✅ Done |
| 2 | Market simulator | ✅ Done |
| 3 | Watchlist scene (VIP) | ✅ Done |
| 4 | Sparkline | ⏳ |
| 5 | Stock detail + line chart | ⏳ |
| 6 | Candlestick + crosshair | ⏳ |
| 7 | Trading | ⏳ |
| 8 | Portfolio, history, persistence | ⏳ |
| 9 | Real market data | ⏳ |
| 10 | What-if tracker | ⏳ |
| 11 | Edge cases in the app | ⏳ |
| 12 | Performance | ⏳ |
| 13 | Polish & publish | ⏳ |
| 14 | App Store release | ⏳ |

## Running tests

```bash
swift test --package-path MarketKit
```

```bash
xcodebuild test -project StockSim/StockSim.xcodeproj -scheme StockSim -destination 'platform=iOS Simulator,name=iPhone 17'
```
