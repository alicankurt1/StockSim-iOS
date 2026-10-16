import Foundation
import Domain

@MainActor
protocol HoldingsPresentationLogic {
    func presentHoldings(response: Holdings.Load.Response)
}

/// Hesabı ekrana hazırlar. UIKit bilmez.
@MainActor
final class HoldingsPresenter: HoldingsPresentationLogic {

    weak var viewController: HoldingsDisplayLogic?

    func presentHoldings(response: Holdings.Load.Response) {
        let portfolio = response.portfolio
        // Fiyatı bilinmeyen hisse maliyetinden değerlenir (Domain kuralı).
        let prices = response.quotes.mapValues(\.price)

        viewController?.displayHoldings(viewModel: Holdings.Load.ViewModel(
            account: makeAccountCard(portfolio, prices: prices),
            positions: portfolio.openPositions.map { makePositionRow($0, price: prices[$0.symbol]) },
            // En yeni işlem en üstte.
            activity: portfolio.trades.reversed().map(makeActivityRow)
        ))
    }

    // MARK: - Parçalar

    private func makeAccountCard(_ portfolio: Portfolio, prices: [Symbol: Money]) -> Holdings.AccountCard {
        let profitLoss = portfolio.totalProfitLoss(prices: prices)
        let percent = Self.percent(profitLoss, of: portfolio.startingCash)
        return Holdings.AccountCard(
            totalValue: PriceFormatting.price(portfolio.totalValue(prices: prices)),
            totalProfitLoss: "\(PriceFormatting.signedPrice(profitLoss)) (\(PriceFormatting.changePercent(percent)))",
            trend: PriceTrend(changePercent: percent),
            cash: PriceFormatting.price(portfolio.cash),
            invested: PriceFormatting.price(portfolio.positionsValue(prices: prices))
        )
    }

    private func makePositionRow(_ position: Position, price: Money?) -> Holdings.PositionRow {
        let current = price ?? position.averageCost
        let profitLoss = position.unrealizedPnL(at: current)
        let percent = Self.percent(profitLoss, of: position.costBasis)
        return Holdings.PositionRow(
            id: position.symbol,
            symbol: position.symbol.rawValue,
            monogram: String(position.symbol.rawValue.prefix(2)),
            summary: "\(PriceFormatting.shares(position.quantity)) · Avg \(PriceFormatting.price(position.averageCost))",
            value: PriceFormatting.price(position.marketValue(at: current)),
            profitLoss: "\(PriceFormatting.signedPrice(profitLoss)) (\(PriceFormatting.changePercent(percent)))",
            trend: PriceTrend(changePercent: percent)
        )
    }

    private func makeActivityRow(_ trade: Trade) -> Holdings.ActivityRow {
        let isBuy = trade.side == .buy
        // Nakit açısından: alım parayı azaltır (-), satış artırır (+).
        let cashFlow = isBuy ? Money(-trade.total.amount) : trade.total
        return Holdings.ActivityRow(
            id: trade.id,
            title: "\(isBuy ? "Bought" : "Sold") \(trade.quantity) \(trade.symbol.rawValue)",
            subtitle: "\(Self.dateFormatter.string(from: trade.date)) · \(PriceFormatting.price(trade.price))",
            amount: PriceFormatting.signedPrice(cashFlow),
            side: trade.side
        )
    }

    private static func percent(_ part: Money, of whole: Money) -> Decimal {
        whole.amount > 0 ? part.amount / whole.amount * 100 : 0
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}
