import Foundation
import Testing
import Domain
@testable import StockSim

@MainActor
private final class DisplaySpy: StockDetailDisplayLogic {
    private(set) var details: [StockDetail.Load.ViewModel] = []
    private(set) var updates: [StockDetail.Update.ViewModel] = []
    private(set) var errors: [String] = []

    func displayDetail(viewModel: StockDetail.Load.ViewModel) { details.append(viewModel) }
    func displayQuoteUpdate(viewModel: StockDetail.Update.ViewModel) { updates.append(viewModel) }
    func displayLoadError(message: String) { errors.append(message) }

    private(set) var selections: [StockDetail.Select.ViewModel] = []
    func displaySelection(viewModel: StockDetail.Select.ViewModel) { selections.append(viewModel) }

    private(set) var initials: [StockDetail.Initial.ViewModel] = []
    func displayInitial(viewModel: StockDetail.Initial.ViewModel) { initials.append(viewModel) }

    private(set) var holdings: [StockDetail.Holding.ViewModel] = []
    func displayHolding(viewModel: StockDetail.Holding.ViewModel) { holdings.append(viewModel) }
}

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")
private let date = Date(timeIntervalSince1970: 0)

private func money(_ value: String) -> Money { Money(Decimal(string: value)!) }

private func candle(_ open: String, _ high: String, _ low: String, _ close: String) -> Candle {
    Candle(date: date, open: money(open), high: money(high), low: money(low), close: money(close))
}

@MainActor
struct StockDetailPresenterTests {

    private let quote = Quote(symbol: thyao.symbol, price: money("110"), previousClose: money("100"), timestamp: date)
    private let candles = [candle("100", "104", "98", "102"), candle("102", "112", "101", "110")]

    private func present(range: ChartRange) -> StockDetail.Load.ViewModel? {
        let presenter = StockDetailPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        presenter.presentDetail(response: .init(instrument: thyao, quote: quote, candles: candles, range: range))
        return display.details.first
    }

    @Test func headerShowsPriceAndDailyChange() throws {
        let viewModel = try #require(present(range: .day))

        #expect(viewModel.title == "THYAO")
        #expect(viewModel.header.name == "Türk Hava Yolları")
        #expect(viewModel.header.price == "₺110,00")
        #expect(viewModel.header.dayChange == "+%10,00")
        #expect(viewModel.header.dayTrend == .up)
    }

    /// Aralık değişimi: ilk açılış (100) → son kapanış (110) = +%10.
    @Test func rangeChangeUsesFirstOpenAndLastClose() throws {
        let viewModel = try #require(present(range: .month))

        #expect(viewModel.rangeChange == "+%10,00 · Past month")
        #expect(viewModel.rangeTrend == .up)
        #expect(viewModel.high == "₺112,00")
        #expect(viewModel.low == "₺98,00")
    }

    /// 1D'de "Today" yüzdesi önceki kapanışa göre: başlıktaki günlük değişimle aynı (+%10),
    /// gün içi grafiğin ilk mumu (108) farklı olsa bile.
    @Test func dayRangeChangeMatchesDailyChange() {
        let presenter = StockDetailPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        let intraday = [candle("108", "111", "107", "109"), candle("109", "112", "108", "110")]

        presenter.presentDetail(response: .init(instrument: thyao, quote: quote, candles: intraday, range: .day))

        #expect(display.details.first?.rangeChange == "+%10,00 · Today")
        #expect(display.details.first?.header.dayChange == "+%10,00")
    }

    @Test func chartPointsCarryOHLC() throws {
        let points = try #require(present(range: .week)).chart.points
        #expect(points.map(\.close) == [102, 110])
        #expect(points.first == StockDetail.Chart.Point(open: 100, high: 104, low: 98, close: 102))
    }

    // MARK: - Crosshair seçimi

    private func select(_ response: StockDetail.Select.Response) -> StockDetail.Header? {
        let presenter = StockDetailPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        presenter.presentSelection(response: response)
        return display.selections.first?.header
    }

    /// Seçili nokta: fiyatı, aralık başından değişim (100 → 110 = +%10), başlıkta tarih.
    @Test func selectedPointShowsItsPriceChangeAndDate() throws {
        let header = try #require(select(.point(candles[1], rangeStart: money("100"), range: .month)))

        #expect(header.price == "₺110,00")
        #expect(header.dayChange == "+%10,00")
        #expect(header.dayTrend == .up)
        #expect(header.name == StockDetailPresenter.dateCaption(date, range: .month))
    }

    @Test func clearedSelectionRestoresLiveHeader() throws {
        let header = try #require(select(.cleared(name: "Türk Hava Yolları", quote: quote)))

        #expect(header.name == "Türk Hava Yolları")
        #expect(header.price == "₺110,00")
    }

    /// 1_800_000_000 = 15 Ocak 2027 08:00 UTC = 11:00 İstanbul (Cuma).
    @Test(arguments: [
        (ChartRange.day, "11:00"), (.week, "Fri 11:00"), (.month, "15 Jan"), (.year, "15 Jan 2027"),
    ])
    func dateCaptionPerRange(range: ChartRange, expected: String) {
        #expect(StockDetailPresenter.dateCaption(Date(timeIntervalSince1970: 1_800_000_000), range: range) == expected)
    }

    /// Önceki kapanış çizgisi sadece gün içi grafikte.
    @Test(arguments: [(ChartRange.day, Optional(100.0)), (.week, nil), (.month, nil), (.year, nil)])
    func baselineOnlyForDay(range: ChartRange, expected: Double?) throws {
        #expect(try #require(present(range: range)).chart.baseline == expected)
    }

    @Test(arguments: zip(ChartRange.allCases, ChartRange.allCases.indices))
    func selectedRangeIndexMatchesTitles(range: ChartRange, index: Int) throws {
        let viewModel = try #require(present(range: range))
        #expect(viewModel.rangeTitles == ["1D", "1W", "1M", "1Y"])
        #expect(viewModel.selectedRangeIndex == index)
    }

    // MARK: - Pozisyon kartı

    private func holding(_ position: Position?, price: String = "110") -> StockDetail.Holding.ViewModel? {
        let presenter = StockDetailPresenter()
        let display = DisplaySpy()
        presenter.viewController = display
        let live = Quote(symbol: thyao.symbol, price: money(price), previousClose: money("100"), timestamp: date)
        presenter.presentHolding(response: .init(position: position, quote: live))
        return display.holdings.first
    }

    @Test func noPositionHidesCardAndSell() throws {
        let viewModel = try #require(holding(nil))
        #expect(viewModel.card == nil)
        #expect(!viewModel.canSell)
    }

    /// 4 adet ort. 100, fiyat 110 → değer 440, K/Z +40 (+%10).
    @Test func positionCardShowsValueAndProfit() throws {
        var position = Position(symbol: thyao.symbol)
        try position.buy(quantity: 4, price: money("100"))

        let viewModel = try #require(holding(position))

        #expect(viewModel.canSell)
        #expect(viewModel.card?.summary == "4 shares · Avg ₺100,00")
        #expect(viewModel.card?.value == "₺440,00")
        #expect(viewModel.card?.profitLoss == "+₺40,00 (+%10,00)")
        #expect(viewModel.card?.trend == .up)
    }

    @Test func initialHeaderUsesPassedQuote() {
        let presenter = StockDetailPresenter()
        let display = DisplaySpy()
        presenter.viewController = display

        presenter.presentInitial(response: .init(instrument: thyao, quote: quote))

        #expect(display.initials.first?.title == "THYAO")
        #expect(display.initials.first?.header?.price == "₺110,00")
    }
}
