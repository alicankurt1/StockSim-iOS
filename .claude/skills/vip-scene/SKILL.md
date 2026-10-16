---
name: vip-scene
description: Scaffold a new Clean Swift (VIP) scene in StockSim following the Watchlist scene - models, interactor, presenter, view controller, router, worker, spies/tests and AppAssembler wiring. Use when adding a new screen, or when the user says "/vip-scene <Name>" or "yeni sahne".
---

# New VIP scene

The reference implementation is `StockSim/StockSim/Scenes/Watchlist/`. Read it first and mirror its structure, naming, comment style (Turkish comments) and isolation rules.

## Files (in `StockSim/StockSim/Scenes/<Name>/`)

| File | Contains |
|---|---|
| `<Name>Models.swift` | `enum <Name> { enum <UseCase> { struct Request, Response, ViewModel } }`, plus row/item types. ViewModels hold only strings and enums. |
| `<Name>Interactor.swift` | `@MainActor protocol <Name>BusinessLogic`, `@MainActor protocol <Name>DataStore`, `final class <Name>Interactor`. Calls the worker, passes raw Domain data to the presenter; no formatting, no UIKit. |
| `<Name>Presenter.swift` | `@MainActor protocol <Name>PresentationLogic`, `final class <Name>Presenter` with `weak var viewController`. Formats into ViewModels. **Never imports UIKit.** |
| `<Name>ViewController.swift` | `@MainActor protocol <Name>DisplayLogic: AnyObject`, the VC (programmatic UIKit, `Theme` colors/fonts, compositional layout + diffable with stable IDs when it is a list). |
| `<Name>Router.swift` | `@MainActor protocol <Name>RoutingLogic`, router with `weak var viewController` and `dataStore`. |
| `<Name>Worker.swift` | `protocol <Name>Working: Sendable` + concrete worker depending only on Domain protocols. |

## Wiring

- Build the scene in `AppAssembler.make<Name>()` (composition root). Back references are weak: presenter → VC, router → VC.
- Data from another scene arrives through the source router writing into this scene's `DataStore`.

## Tests (in `StockSim/StockSimTests/<Name>/`)

- Interactor: `PresenterSpy` (records calls in order) + `WorkerStub` (returns a `Result`; finite `AsyncStream` for live data).
- Presenter: `DisplaySpy`; table tests for formatting.
- Router: data passing into the destination data store.
- Compile with `xcodebuild build-for-testing -destination 'generic/platform=iOS Simulator'`; the user runs the app and ⌘U.

## After scaffolding

Explain in 3–5 bullets (Turkish) what was created and which SOLID / VIP concept each piece shows.
