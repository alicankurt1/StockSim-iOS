import Foundation
import Domain

@MainActor
protocol WhatIfBuilderPresentationLogic {
    func presentBuilder(response: WhatIfBuilder.Response)
    func presentTracked(response: WhatIfBuilder.Track.Response)
}

@MainActor
final class WhatIfBuilderPresenter: WhatIfBuilderPresentationLogic {

    weak var viewController: WhatIfBuilderDisplayLogic?

    func presentBuilder(response: WhatIfBuilder.Response) {
        var result: WhatIfBuilder.Result?
        var message: String?
        switch response.outcome {
        case .calculating:
            break
        case let .result(scenario, currentPrice, candles):
            result = makeResult(scenario, currentPrice: currentPrice, candles: candles)
        case .invalidAmount:
            message = "Enter an amount to invest."
        case .unavailable:
            message = "No price data for this date."
        }

        viewController?.displayBuilder(viewModel: WhatIfBuilder.ViewModel(
            title: response.isEditing ? "Edit Scenario" : "What If",
            trackTitle: response.isEditing ? "Save changes" : "Track this",
            amountText: response.amount.map(Self.amountText) ?? "",
            stockTitle: response.instrument.map { "\($0.symbol.rawValue) · \($0.name)" } ?? "Choose a stock",
            stockOptions: response.instruments.map {
                .init(instrument: $0, title: "\($0.symbol.rawValue) · \($0.name)", isSelected: $0.symbol == response.instrument?.symbol)
            },
            date: response.date,
            dateRange: response.dateRange,
            result: result,
            message: message,
            isCalculating: { if case .calculating = response.outcome { true } else { false } }(),
            isTrackEnabled: result != nil
        ))
    }

    func presentTracked(response: WhatIfBuilder.Track.Response) {
        viewController?.displayTracked()
    }

    private func makeResult(_ scenario: WhatIfScenario, currentPrice: Money, candles: [Candle]) -> WhatIfBuilder.Result {
        let profitLoss = scenario.profitLoss(at: currentPrice)
        let percent = scenario.returnPercent(at: currentPrice)
        // Grafik: alımdan bugüne kapanışlar; son nokta canlı fiyat.
        var chart = candles.map { PriceFormatting.chartValue($0.close) }
        if !chart.isEmpty { chart[chart.count - 1] = PriceFormatting.chartValue(currentPrice) }

        return WhatIfBuilder.Result(
            entry: "Bought \(Self.shares(scenario.shares)) shares at \(PriceFormatting.price(scenario.entryPrice)) on \(Self.dateFormatter.string(from: candles.first?.date ?? scenario.startDate))",
            value: PriceFormatting.price(scenario.value(at: currentPrice)),
            profitLoss: "\(PriceFormatting.signedPrice(profitLoss)) (\(PriceFormatting.changePercent(percent)))",
            trend: PriceTrend(changePercent: percent),
            chart: chart,
            baseline: PriceFormatting.chartValue(scenario.entryPrice)
        )
    }

    /// Tutar alanı için ₺ işaretsiz Türkçe biçim: "100.000", "1.250,5".
    static func amountText(_ money: Money) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: money.amount as NSDecimalNumber) ?? ""
    }

    /// Kesirli adet, 2 hane: "347,83".
    static func shares(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}
