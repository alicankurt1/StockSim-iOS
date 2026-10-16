# CLAUDE.md

Guidance for Claude when working in this repository.

## Project

StockSim is a paper-trading stock app for learning: Clean Swift (VIP), SOLID, test-driven development, custom UIKit drawing and performance.

The plan (phases, architecture, simulator contract) is loaded below and is the source of truth for what to build next:

@PLAN.md

## Language

- Talk to the user in **Turkish**.
- **Code comments in Turkish** (so the user can explain the code in their own words).
- Identifiers, commit messages, `README.md`, `PLAN.md`, `CLAUDE.md`: **English**.
- `NOTES.md`: **Turkish** (learning notes).

## Public repository

The repo is public from day one. Never write company names, interview references or personal notes anywhere. `NOTES.md` stays as learning notes.

## Architecture rules

- Clean Swift (VIP) per scene: ViewController → Interactor → Presenter → ViewController, plus Router (+ DataStore / DataPassing), Worker(s), Models (`Request` / `Response` / `ViewModel`).
- Presenter must not import UIKit; visual decisions are strings / enums in the ViewModel.
- Interactor owns business rules and knows nothing about UI.
- Small, focused protocols (Business / Presentation / Display / Routing logic separate).
- Concrete types are created only in the composition root (`SceneDelegate` → `AppAssembler`).
- Core logic lives in the local package `MarketKit` (`Domain`, `MarketSimulator`, `Persistence`, `Charts`, later `MarketData`). Dependencies point towards `Domain`. `swift test` must run without a simulator.
- Swift 6 language mode, strict concurrency. Default actor isolation is **off**; write `@MainActor` explicitly on UI and VIP display types. Use actors for shared mutable state.
- Programmatic UIKit only (no storyboards), compositional layout + diffable data source.
- No third-party dependencies. Charts are drawn by hand (no Swift Charts).
- Deployment target iOS 16; newer APIs behind `@available`.
- Keep it simple: the smallest solution that shows the concept. SOLID is about flexibility, not layer count.
- In every phase, state explicitly which SOLID principle is applied where.

## Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`, parameterized tests).
- VIP: interactor tested with presenter + worker spies; presenter with display spy (format tests); router for data passing.
- Domain rules as table-driven tests (P&L, average cost, balance checks).
- Simulator is seeded; price paths must be reproducible in tests.
- Tests first where possible (at least Domain and interactors).
- Tests never hit the network; use fixtures and fake clients.

## Workflow

- Each phase on its own branch `phase-N/<topic>`. No direct commits to `main`.
- Commit message format: `Phase N: <summary>`.
- When a phase is done: push; the user opens and merges the PR on GitHub (`gh` is not installed).
- Update the README Progress table and PLAN.md checkboxes in the same commit.
- The user verifies visual features in the Simulator; collect their screenshots / short demo clips under `docs/media/`.

## Working mode: speed mode

- **Claude writes the code** (production and tests) for every phase. After each step, explain it in **3–5 short bullets**: what was built, why, and which SOLID / Clean Swift / UIKit concept it shows.
- **Learning focus:** Clean Swift (VIP), UIKit and custom drawing. Finance rules and simulator math get only a one-line summary.
- The user runs the app in Xcode (⌘R) and reports errors or screenshots. **Do not launch the iOS Simulator or run UI tests**; build-check with `xcodebuild build -destination 'generic/platform=iOS Simulator'` and run package tests.
- Keep replies short and scannable; the user prefers short answers.
- At the end of each phase ask **one** short interview-style question. If the user asks, answer it yourself. Add the corrected answer to `NOTES.md`.
- `NOTES.md` doubles as raw material for a Medium article: per phase, 2–3 concepts worth explaining, in Turkish.

## Commands

```bash
# Package tests (macOS, no simulator)
swift test --package-path MarketKit

# App tests (simulator)
xcodebuild test -project StockSim/StockSim.xcodeproj -scheme StockSim -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Project skills

- `/verify` (`.claude/skills/verify`): package tests and build check (simulator steps only when the user asks).
- `/phase-wrap-up` (`.claude/skills/phase-wrap-up`): review questions, NOTES / PLAN / README updates, commit and push.
- `/vip-scene` is planned for Phase 3, extracted from the first hand-built scene.
