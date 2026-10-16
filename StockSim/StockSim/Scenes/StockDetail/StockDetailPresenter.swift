import Foundation
import Domain

@MainActor
protocol StockDetailPresentationLogic {
    func presentDetail(response: StockDetail.Load.Response)
    func presentQuoteUpdate(response: StockDetail.Update.Response)
    func presentLoadError()
}

/// Detay ekranının formatlaması. UIKit bilmez.
@MainActor
final class StockDetailPresenter: StockDetailPresentationLogic {

    weak var viewController: StockDetailDisplayLogic?

    /// Aralık seçicinin sırası; VC seçilen indeksi bu sıraya göre Interactor'a geri yollar.
    static let ranges = ChartRange.allCases

    func presentDetail(response: StockDetail.Load.Response) {
        let candles = response.candles
        let rangePercent = Self.rangeChangePercent(candles)

        let viewModel = StockDetail.Load.ViewModel(
            title: response.instrument.symbol.rawValue,
            header: makeHeader(name: response.instrument.name, quote: response.quote),
            chart: makeChart(candles: candles, quote: response.quote, range: response.range),
            rangeTitles: Self.ranges.map(Self.title(for:)),
            selectedRangeIndex: Self.ranges.firstIndex(of: response.range) ?? 0,
            rangeChange: "\(PriceFormatting.changePercent(rangePercent)) · \(Self.caption(for: response.range))",
            rangeTrend: PriceTrend(changePercent: rangePercent),
            high: candles.map(\.high).max().map(PriceFormatting.price) ?? "—",
            low: candles.map(\.low).min().map(PriceFormatting.price) ?? "—"
        )
        viewController?.displayDetail(viewModel: viewModel)
    }

    func presentQuoteUpdate(response: StockDetail.Update.Response) {
        viewController?.displayQuoteUpdate(viewModel: StockDetail.Update.ViewModel(
            header: makeHeader(name: nil, quote: response.quote),
            chart: makeChart(candles: response.candles, quote: response.quote, range: response.range)
        ))
    }

    func presentLoadError() {
        viewController?.displayLoadError(message: "Couldn't load this stock.")
    }

    // MARK: - Parçalar

    private func makeHeader(name: String?, quote: Quote) -> StockDetail.Header {
        StockDetail.Header(
            name: name ?? "",
            price: PriceFormatting.price(quote.price),
            dayChange: PriceFormatting.changePercent(quote.changePercent),
            dayTrend: PriceTrend(changePercent: quote.changePercent)
        )
    }

    private func makeChart(candles: [Candle], quote: Quote, range: ChartRange) -> StockDetail.Chart {
        StockDetail.Chart(
            values: candles.map { PriceFormatting.chartValue($0.close) },
            // Önceki kapanış sadece gün içi grafikte anlamlı.
            baseline: range == .day ? PriceFormatting.chartValue(quote.previousClose) : nil,
            trend: PriceTrend(changePercent: Self.rangeChangePercent(candles))
        )
    }

    /// Aralığın ilk açılışından son kapanışa yüzde değişim.
    static func rangeChangePercent(_ candles: [Candle]) -> Decimal {
        guard let first = candles.first?.open.amount, let last = candles.last?.close.amount, first > 0 else { return 0 }
        return (last - first) / first * 100
    }

    static func title(for range: ChartRange) -> String {
        switch range {
        case .day: "1D"
        case .week: "1W"
        case .month: "1M"
        case .year: "1Y"
        }
    }

    static func caption(for range: ChartRange) -> String {
        switch range {
        case .day: "Today"
        case .week: "Past week"
        case .month: "Past month"
        case .year: "Past year"
        }
    }
}
