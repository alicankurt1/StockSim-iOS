# StockSim — Plan

A paper-trading stock app built to practice **Clean Swift (VIP)**, **SOLID**, **test-driven development**, **custom UIKit drawing** and **performance work**. No real money is involved. Prices come either from a deterministic in-app market simulator or from delayed real end-of-day data.

## Legend

- ✍️ — written by me; Claude explains the concept, provides the skeleton (types, signatures, `// TODO`) and reviews.
- 🤖 — written by Claude (boilerplate, VIP templates, project settings) and explained in 3–5 bullets.
- Every phase lives on its own branch `phase-N/<topic>` and ends with 2–3 review questions (answers go to `NOTES.md`).

## Tech decisions

| Topic | Decision | Why |
|---|---|---|
| Language | Swift 6 language mode, strict concurrency | Data-race safety is checked at compile time |
| Isolation | Default actor isolation **off**; `@MainActor` written explicitly | Isolation is a conscious choice per type; app and package follow the same rule |
| Deployment target | iOS 16 | Wide device coverage; newer APIs (e.g. `registerForTraitChanges`, UIKit `#Preview`) are used behind `@available` |
| UI | Programmatic UIKit, compositional layout + diffable data source | No storyboards |
| Charts | Hand-drawn with Core Graphics / `CAShapeLayer` | Learning UIKit drawing is the goal; Swift Charts is not used |
| Networking | `URLSession` + async/await behind a small `HTTPClient` protocol | One GET endpoint does not justify a dependency; the protocol makes it testable |
| Dependencies | None (no third-party packages) | |
| Tests | Swift Testing (`@Test`, `#expect`, parameterized tests) | |

## Architecture

### Clean Swift (VIP)

```
 ┌──────────────┐  request   ┌──────────────┐  response  ┌──────────────┐
 │ ViewController│──────────▶│  Interactor  │───────────▶│  Presenter   │
 │ (Display)     │◀──────────│ (Business)   │            │ (Presentation)│
 └──────────────┘ viewModel  └──────────────┘            └──────┬───────┘
        ▲                         │  uses                       │
        │                         ▼                             │
        │                     Worker(s)                         │
        └───────────────────────────────────────────────────────┘
 Router (+ DataStore / DataPassing) handles navigation and data hand-off.
```

- Each scene has: `ViewController`, `Interactor`, `Presenter`, `Router`, `Worker`(s), `Models` (`Request` / `Response` / `ViewModel`).
- Protocols are small and split: `<Scene>BusinessLogic`, `<Scene>PresentationLogic`, `<Scene>DisplayLogic`, `<Scene>RoutingLogic`, `<Scene>DataStore`.
- **Presenter does not import UIKit.** Colors and formats are expressed as strings / enums (e.g. `PriceTrend.up`) in the ViewModel; the view maps them to `UIColor`.
- **Interactor** knows business rules, never UI.
- Concrete types are built only in the **composition root** (`SceneDelegate` → `AppAssembler`).

### Modules (local Swift package `MarketKit`)

```
            ┌──────────┐
            │  Domain  │  models, order & portfolio rules (pure Swift)
            └────▲─────┘
   ┌─────────────┼───────────────┬──────────────┐
┌──┴────────────┐ ┌──────────────┴┐ ┌───────────┴──┐ ┌──────────┴─┐
│MarketSimulator│ │  MarketData   │ │ Persistence  │ │   Charts   │
│ (actor, GBM)  │ │ (real, HTTP)  │ │ (JSON store) │ │ (UIKit)    │
└───────────────┘ └───────────────┘ └──────────────┘ └────────────┘
                 ▲ all used by the StockSim app (VIP scenes)
```

- Dependencies point one way, towards `Domain`.
- `swift test` runs on macOS without a simulator. `Charts` wraps UIKit code in `#if canImport(UIKit)`; pure geometry (scales, hit-testing) is tested on macOS.
- VIP scene tests live in the app's test target and run with `xcodebuild test` (headless simulator).
- `MarketData` is added in Phase 9.

### SOLID map

| Principle | Where |
|---|---|
| SRP | VIP layers; one worker per job (pricing, trading, persistence) |
| OCP | `OrderType` (market now, limit later); `ChartRenderer` (line, candle, …); new market data providers |
| LSP | `MarketDataProviding`: simulated, real and test providers are interchangeable |
| ISP | Business / Presentation / Display logic protocols; `MarketDataProviding` vs `MarketControlling` |
| DIP | Scenes depend on protocols; `AppAssembler` wires concrete types |

## Market simulator contract

```swift
public protocol MarketDataProviding: Sendable {
    func instruments() async throws -> [Instrument]
    func updates(for symbols: [Symbol]) -> AsyncStream<MarketUpdate>
    func history(for symbol: Symbol, range: ChartRange) async throws -> [Candle]
}

public protocol MarketControlling: Sendable {   // simulator only
    func trigger(_ event: MarketEvent) async
}

public enum MarketUpdate: Sendable {
    case quote(Quote)          // new price
    case halted(Symbol)        // trading stopped
    case resumed(Symbol)
    case feedInterrupted       // stream is stale
    case feedRestored
}

public enum ChartRange: CaseIterable { case day, week, month, year }  // 1G / 1H / 1A / 1Y
```

- **Price model:** geometric Brownian motion per tick: `S(t+Δt) = S(t) · exp((μ − σ²/2)·Δt + σ·√Δt·Z)`, `Z ~ N(0, 1)`.
- **Determinism:** a seeded RNG (SplitMix64) + an injected clock. Same seed ⇒ same price path, so tests are repeatable and never sleep.
- **History:** generated from the same seed; ticks are aggregated into OHLC candles per range (day: 5 min, week: 1 h, month: 1 d, year: 1 w).
- **Instruments:** real BIST tickers (e.g. THYAO, ASELS) with simulated prices; the UI shows a `SIMULATED` badge in simulator mode.

### Edge-case triggers

| Event | Effect | What it tests |
|---|---|---|
| `crash(symbol?, percent)` | Instant drop on one/all symbols | Large % changes, red states, chart rescaling |
| `volatilitySpike(multiplier, duration)` | σ multiplied for a while | Rapid updates, UI performance |
| `halt(symbol)` / `resume(symbol)` | No quotes; trading rejected | Disabled trade button, halt banner, order errors |
| `dropFeed(duration)` | Stream goes silent, then restores | Stale-data indicator, reconnection |

## Phases

### Phase 0 — Foundation (~2–3 h) 🤖
- [x] Remove storyboard; programmatic window in `SceneDelegate`
- [x] `AppAssembler` as composition root
- [x] `MarketKit` local package with `Domain`, `MarketSimulator`, `Persistence`, `Charts` + test targets
- [x] Swift 6, strict concurrency, default isolation off, iOS 16
- [x] Smoke tests pass with `swift test` and `xcodebuild test`

**Learns:** DIP, composition root, module dependency direction.

### Phase 1 — Domain, TDD (~4–6 h) ✍️
- [ ] `Money` (Decimal), `Symbol`, `Instrument`, `Quote`, `Candle`
- [ ] `Order`, `OrderType` (market), `Trade`, `TradingError`
- [ ] `Position`, `Portfolio`: average cost, realized / unrealized P&L, total value
- [ ] Balance and quantity checks
- [ ] Table-driven tests written first

**Learns:** SRP, OCP (`OrderType`), why `Decimal` over `Double`, parameterized tests.

### Phase 2 — Market simulator (~5–6 h) ✍️ core / 🤖 plumbing
- [ ] Seeded RNG (SplitMix64) + normal distribution (Box–Muller)
- [ ] GBM step function (pure, tested)
- [ ] `actor MarketSimulator` with `AsyncStream<MarketUpdate>` and injected clock
- [ ] History generation + OHLC aggregation
- [ ] Edge-case triggers via `MarketControlling`

**Learns:** actors, AsyncStream, determinism, LSP & ISP.

### Phase 3 — Watchlist scene, first VIP cycle (~5 h) 🤖 template / ✍️ interactor + presenter
- [ ] VIP template files
- [ ] Compositional layout + diffable data source, `reconfigureItems` for live prices
- [ ] Presenter formatting (currency, %, `PriceTrend`)
- [ ] Interactor tests with presenter & worker spies; presenter tests with display spy

**Learns:** VIP data flow, ISP, SRP, spies.

### Phase 4 — Sparkline (~3 h) ✍️
- [ ] Normalization math (pure, tested on macOS)
- [ ] `SparklineView` with `CAShapeLayer` + `UIBezierPath`
- [ ] Cell reuse: update the path, never rebuild layers
- [ ] Dark mode color update (`@available` for `registerForTraitChanges`)

**Learns:** Core Animation basics, drawing vs layout, `@available`.

### Phase 5 — Stock detail + line chart (~5 h) ✍️
- [ ] Router + DataStore / DataPassing (router tests)
- [ ] `ChartScale` (data ↔ points), tested
- [ ] `LineChartView` with gradient fill; range selector 1G / 1H / 1A / 1Y
- [ ] Core Graphics (`draw(_:)`) vs `CAShapeLayer` comparison

**Learns:** VIP routing, drawing approaches.

### Phase 6 — Candlestick + crosshair (~5 h) ✍️
- [ ] `ChartRenderer` protocol; line and candle renderers
- [ ] Crosshair with pan / long-press, value label, haptics
- [ ] Nearest-point lookup with binary search (tested)

**Learns:** OCP, gestures, hit-testing.

### Phase 7 — Trading (~4 h) ✍️ interactor TDD
- [ ] Trade sheet scene (buy / sell, market order)
- [ ] `TradingWorker`, `actor PortfolioStore`
- [ ] Errors: insufficient cash, insufficient quantity, halted symbol

**Learns:** business rules in the interactor, mapping errors to view models.

### Phase 8 — Portfolio, history, persistence (~5 h)
- [ ] Portfolio scene: positions, average cost, unrealized P&L, total value
- [ ] Transaction history scene
- [ ] `Persistence`: Codable JSON file store (actor, atomic writes, schema version)
- [ ] Persistence tests in a temporary directory

**Learns:** DIP (in-memory vs file store), persistence testing.

### Phase 9 — Real market data (~4–5 h)
- [ ] `HTTPClient` protocol + `URLSession` implementation
- [ ] `YahooMarketProvider` (delayed quotes + daily candles for BIST tickers)
- [ ] Codable fixture tests (missing fields, `null` prices, holidays) — tests never hit the network
- [ ] On-device cache; provider switch (simulated / real) in `AppAssembler`

**Learns:** LSP & DIP in practice, Codable edge cases, testable networking.

### Phase 10 — What-if tracker (~4 h)
- [ ] Backward mode: symbol + date + amount → shares, today's value, P&L; buy point marked on chart
- [ ] Forward mode: paper position opened at last close, tracked daily, persisted
- [ ] Reuses Domain portfolio rules

**Learns:** reusing domain rules with a different price source.

### Phase 11 — Edge cases in the app (~3 h)
- [ ] Debug menu (shake) for all simulator triggers
- [ ] Halt banner + disabled trading; stale-data indicator; reconnection

**Learns:** state machines, error view models.

### Phase 12 — Performance (~3–4 h)
- [ ] Load test: 100+ symbols × 10 Hz
- [ ] Update batching / throttling; `os_signpost`
- [ ] Instruments: Time Profiler, Core Animation (offscreen rendering, blending)

**Learns:** measure → change → measure.

### Phase 13 — Polish & publish (~3 h)
- [ ] Dark mode pass, basic accessibility
- [ ] README GIFs, disclaimer, cleanup

**Total:** ~55–65 h. Demo clips are collected under `docs/media/` at the end of each visual phase.

## Cut list

Dropped first if time runs short:

- Pinch to zoom on charts
- Limit orders
- Volume bars
- TEFAS fund prices (a third `MarketDataProviding` implementation)
- Moving the simulator to a WebSocket server
- VoiceOver audio graphs
- iPad layout, localization
