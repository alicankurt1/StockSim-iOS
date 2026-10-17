import Foundation
import Domain

@MainActor
protocol StockDetailPresentationLogic {
    func presentInitial(response: StockDetail.Initial.Response)
    func presentMarketStatus(response: StockDetail.MarketStatus.Response)
    func presentHolding(response: StockDetail.Holding.Response)
    func presentDetail(response: StockDetail.Load.Response)
    func presentQuoteUpdate(response: StockDetail.Update.Response)
    func presentLoadError()
    func presentSelection(response: StockDetail.Select.Response)
}

/// Detay ekranının formatlaması. UIKit bilmez.
@MainActor
final class StockDetailPresenter: StockDetailPresentationLogic {

    weak var viewController: StockDetailDisplayLogic?

    /// Aralık seçicinin sırası; VC seçilen indeksi bu sıraya göre Interactor'a geri yollar.
    static let ranges = ChartRange.allCases

    func presentInitial(response: StockDetail.Initial.Response) {
        viewController?.displayInitial(viewModel: StockDetail.Initial.ViewModel(
            title: response.instrument.symbol.rawValue,
            header: response.quote.map { makeHeader(name: response.instrument.name, quote: $0) }
                ?? StockDetail.Header(name: response.instrument.name, price: "—", dayChange: "", dayTrend: .flat)
        ))
    }

    func presentMarketStatus(response: StockDetail.MarketStatus.Response) {
        // İkisi birden olursa daha önemlisi: işlem durdurma.
        let message: String? = if response.isHalted {
            "Trading halted. Buying and selling are paused."
        } else if response.isFeedInterrupted {
            "Reconnecting… prices may be delayed"
        } else {
            nil
        }
        viewController?.displayMarketStatus(viewModel: .init(bannerMessage: message, isTradingEnabled: !response.isHalted))
    }

    func presentHolding(response: StockDetail.Holding.Response) {
        guard let position = response.position, position.quantity > 0 else {
            viewController?.displayHolding(viewModel: .init(card: nil, canSell: false))
            return
        }
        // Fiyat henüz yoksa maliyetten değerle (K/Z sıfır görünür).
        let price = response.quote?.price ?? position.averageCost
        let profitLoss = position.unrealizedPnL(at: price)
        let percent = position.costBasis.amount > 0 ? profitLoss.amount / position.costBasis.amount * 100 : 0

        viewController?.displayHolding(viewModel: .init(
            card: .init(
                summary: "\(PriceFormatting.shares(position.quantity)) · Avg \(PriceFormatting.price(position.averageCost))",
                value: PriceFormatting.price(position.marketValue(at: price)),
                profitLoss: "\(PriceFormatting.signedPrice(profitLoss)) (\(PriceFormatting.changePercent(percent)))",
                trend: PriceTrend(changePercent: percent)
            ),
            canSell: true
        ))
    }

    func presentDetail(response: StockDetail.Load.Response) {
        let candles = response.candles
        let rangePercent = Self.rangeChangePercent(candles, quote: response.quote, range: response.range)

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
        let rangePercent = Self.rangeChangePercent(response.candles, quote: response.quote, range: response.range)
        viewController?.displayQuoteUpdate(viewModel: StockDetail.Update.ViewModel(
            header: makeHeader(name: nil, quote: response.quote),
            chart: makeChart(candles: response.candles, quote: response.quote, range: response.range),
            rangeChange: "\(PriceFormatting.changePercent(rangePercent)) · \(Self.caption(for: response.range))",
            rangeTrend: PriceTrend(changePercent: rangePercent)
        ))
    }

    func presentLoadError() {
        viewController?.displayLoadError(message: "Couldn't load this stock.")
    }

    func presentSelection(response: StockDetail.Select.Response) {
        let header: StockDetail.Header
        switch response {
        case let .point(candle, rangeStart, range):
            // Seçili noktada: o anki fiyat, aralık başından o ana değişim, başlık yerine tarih.
            let percent = rangeStart.amount > 0 ? (candle.close.amount - rangeStart.amount) / rangeStart.amount * 100 : 0
            header = StockDetail.Header(
                name: Self.dateCaption(candle.date, range: range),
                price: PriceFormatting.price(candle.close),
                dayChange: PriceFormatting.changePercent(percent),
                dayTrend: PriceTrend(changePercent: percent)
            )
        case let .cleared(name, quote):
            header = makeHeader(name: name, quote: quote)
        }
        viewController?.displaySelection(viewModel: StockDetail.Select.ViewModel(header: header))
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
            points: candles.map {
                StockDetail.Chart.Point(
                    open: PriceFormatting.chartValue($0.open),
                    high: PriceFormatting.chartValue($0.high),
                    low: PriceFormatting.chartValue($0.low),
                    close: PriceFormatting.chartValue($0.close)
                )
            },
            // Önceki kapanış sadece gün içi grafikte anlamlı.
            baseline: range == .day ? PriceFormatting.chartValue(quote.previousClose) : nil,
            trend: PriceTrend(changePercent: Self.rangeChangePercent(candles, quote: quote, range: range))
        )
    }

    /// Aralık boyunca değişim.
    /// - Gün içi (1D): önceki kapanışa göre, yani başlıktaki günlük değişimle AYNI sayı.
    ///   (Gün içi grafiğin ilk mumu önceki kapanış değildir; ona göre hesaplamak iki farklı
    ///   "bugün" yüzdesi gösteriyordu.)
    /// - Diğer aralıklar: aralığın ilk açılışından son (canlı) kapanışa.
    static func rangeChangePercent(_ candles: [Candle], quote: Quote, range: ChartRange) -> Decimal {
        if range == .day { return quote.changePercent }
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

    /// Crosshair tarihi: kısa aralıkta saat, uzun aralıkta gün. Borsa saatiyle (İstanbul).
    static func dateCaption(_ date: Date, range: ChartRange) -> String {
        let formatter = dateFormatters[range]!
        return formatter.string(from: date)
    }

    private static let dateFormatters: [ChartRange: DateFormatter] = {
        let templates: [ChartRange: String] = [.day: "HH:mm", .week: "EEE HH:mm", .month: "d MMM", .year: "d MMM yyyy"]
        return templates.mapValues { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func caption(for range: ChartRange) -> String {
        switch range {
        case .day: "Today"
        case .week: "Past week"
        case .month: "Past month"
        case .year: "Past year"
        }
    }
}
