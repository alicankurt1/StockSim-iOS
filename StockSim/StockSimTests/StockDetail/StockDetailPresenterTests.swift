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

    @Test func chartValuesAreCloses() throws {
        #expect(try #require(present(range: .week)).chart.values == [102, 110])
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
}
