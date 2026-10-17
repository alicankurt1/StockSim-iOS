import Foundation
import Testing
import Domain
@testable import StockSim

/// Display casusu: VC yerine geçer, kendisine gelen ViewModel'i saklar.
@MainActor
private final class DisplaySpy: WatchlistDisplayLogic {
    private(set) var viewModels: [Watchlist.Load.ViewModel] = []
    private(set) var errorMessages: [String] = []

    func displayWatchlist(viewModel: Watchlist.Load.ViewModel) {
        viewModels.append(viewModel)
    }

    func displayLoadError(message: String) {
        errorMessages.append(message)
    }

    private(set) var feedMessages: [String?] = []

    func displayFeedStatus(viewModel: Watchlist.FeedStatus.ViewModel) {
        feedMessages.append(viewModel.message)
    }

    private(set) var updatedRows: [Watchlist.Row] = []

    func displayQuoteUpdate(viewModel: Watchlist.Update.ViewModel) {
        updatedRows.append(viewModel.row)
    }
}

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let asels = Instrument(symbol: Symbol("ASELS"), name: "Aselsan")

private func quote(_ price: String, previousClose: String) -> Quote {
    Quote(
        symbol: thyao.symbol,
        price: Money(Decimal(string: price)!),
        previousClose: Money(Decimal(string: previousClose)!),
        timestamp: Date(timeIntervalSince1970: 0)
    )
}

/// Presenter'ı UI olmadan test ediyoruz: gerçek VC yerine DisplaySpy veriyoruz.
@MainActor
struct WatchlistPresenterTests {

    private func makePresenter() -> (WatchlistPresenter, DisplaySpy) {
        let presenter = WatchlistPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        return (presenter, display)
    }

    // MARK: - Satır formatı (Adım 2)

    /// (fiyat, önceki kapanış, beklenen fiyat metni, beklenen değişim metni, beklenen yön)
    @Test(arguments: [
        ("287.50", "284.25", "₺287,50", "+%1,14", PriceTrend.up),
        ("90", "100", "₺90,00", "-%10,00", .down),
        ("50", "50", "₺50,00", "%0,00", .flat),
        ("1234.5", "1000", "₺1.234,50", "+%23,45", .up),
    ])
    func rowFormatsPriceChangeAndTrend(
        price: String, previousClose: String,
        expectedPrice: String, expectedChange: String, expectedTrend: PriceTrend
    ) {
        let row = WatchlistPresenter().makeRow(instrument: thyao, quote: quote(price, previousClose: previousClose))

        #expect(row.price == expectedPrice)
        #expect(row.change == expectedChange)
        #expect(row.trend == expectedTrend)
    }

    @Test func rowWithoutQuoteShowsPlaceholder() {
        let row = WatchlistPresenter().makeRow(instrument: thyao, quote: nil)

        #expect(row.price == "—")
        #expect(row.change == "")
        #expect(row.trend == .flat)
    }

    @Test func rowKeepsSymbolAndName() {
        let row = WatchlistPresenter().makeRow(instrument: thyao, quote: quote("100", previousClose: "100"))

        #expect(row.id == thyao.symbol)
        #expect(row.symbol == "THYAO")
        #expect(row.monogram == "TH")
        #expect(row.name == "Türk Hava Yolları")
    }

    // MARK: - VIP: Presenter → Display

    @Test func presentWatchlistSendsOneRowPerInstrumentInOrder() {
        let (presenter, display) = makePresenter()

        presenter.presentWatchlist(response: .init(instruments: [thyao, asels], quotes: [thyao.symbol: quote("100", previousClose: "90")]))

        let rows = display.viewModels.first?.rows ?? []
        #expect(display.viewModels.count == 1)
        #expect(rows.map(\.symbol) == ["THYAO", "ASELS"])
    }

    @Test func presentLoadingSendsOnlyPlaceholders() {
        let (presenter, display) = makePresenter()

        presenter.presentLoading()

        let items = display.viewModels.first?.items ?? []
        #expect(items.count == WatchlistPresenter.placeholderCount)
        #expect(display.viewModels.first?.rows.isEmpty == true)
    }

    @Test func presentLoadErrorSendsMessage() {
        let (presenter, display) = makePresenter()

        presenter.presentLoadError()

        #expect(display.errorMessages.count == 1)
        #expect(display.viewModels.isEmpty)
    }

    @Test func presentQuoteUpdateSendsFormattedRow() {
        let (presenter, display) = makePresenter()

        presenter.presentQuoteUpdate(response: .init(instrument: thyao, quote: quote("287.50", previousClose: "284.25")))

        #expect(display.updatedRows.map(\.price) == ["₺287,50"])
        #expect(display.updatedRows.first?.trend == .up)
        #expect(display.viewModels.isEmpty)
    }

    @Test func rowCarriesSparklineAsNumbers() {
        let row = WatchlistPresenter().makeRow(
            instrument: thyao,
            quote: quote("100", previousClose: "100"),
            sparkline: [Money(Decimal(string: "99.5")!), Money(100)]
        )

        #expect(row.sparkline == [99.5, 100])
    }

    /// Durdurulmuş hisse: yüzde yerine "HALTED".
    @Test func haltedRowShowsStatusInsteadOfChange() {
        let row = WatchlistPresenter().makeRow(instrument: thyao, quote: quote("100", previousClose: "90"), isHalted: true)
        #expect(row.change == "HALTED")
        #expect(row.isHalted)
        #expect(row.price == "₺100,00")
    }

    @Test func feedStatusMessage() {
        let (presenter, display) = makePresenter()

        presenter.presentFeedStatus(response: .init(isInterrupted: true))
        presenter.presentFeedStatus(response: .init(isInterrupted: false))

        #expect(display.feedMessages.first??.contains("Reconnecting") == true)
        #expect(display.feedMessages.last == .some(nil))
    }
}
