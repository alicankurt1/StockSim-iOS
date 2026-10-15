import Testing
@testable import Domain

struct PositionTests {

    private let thyao = Symbol("THYAO")

    /// Sırayla alımlar yapılmış bir pozisyon kurar: [(adet, fiyat)].
    private func position(buys: [(Int, String)]) throws -> Position {
        var position = Position(symbol: thyao)
        for (quantity, price) in buys {
            try position.buy(quantity: quantity, price: money(price))
        }
        return position
    }

    // MARK: - Boş pozisyon

    @Test func startsEmpty() {
        let position = Position(symbol: thyao)
        #expect(position.quantity == 0)
        #expect(position.averageCost == .zero)
        #expect(position.realizedPnL == .zero)
        #expect(position.unrealizedPnL(at: money("100")) == .zero)
    }

    // MARK: - Alım: ortalama maliyet

    /// (alımlar, beklenen adet, beklenen ortalama maliyet)
    @Test(arguments: [
        ([(10, "100")], 10, "100"),
        ([(10, "100"), (10, "120")], 20, "110"),
        ([(10, "100"), (30, "120")], 40, "115"),        // (1000 + 3600) / 40
        ([(1, "50"), (1, "60"), (2, "75")], 4, "65"),  // (50 + 60 + 150) / 4
    ])
    func buyUpdatesAverageCost(buys: [(Int, String)], expectedQuantity: Int, expectedAverage: String) throws {
        let position = try position(buys: buys)
        #expect(position.quantity == expectedQuantity)
        #expect(position.averageCost == money(expectedAverage))
    }

    @Test func costBasisIsAverageTimesQuantity() throws {
        let position = try position(buys: [(10, "100"), (30, "120")])
        #expect(position.costBasis == money("4600"))
    }

    // MARK: - Satış: gerçekleşen K/Z

    /// 10 adet @100 alındıktan sonra satış: (satış adedi, satış fiyatı, kalan adet, gerçekleşen K/Z)
    @Test(arguments: [
        (4, "130", 6, "120"),     // kârla kısmi satış
        (4, "90", 6, "-40"),      // zararla kısmi satış
        (10, "100", 0, "0"),      // başa baş, hepsi satıldı
    ])
    func sellRealizesPnL(quantity: Int, price: String, expectedQuantity: Int, expectedRealized: String) throws {
        var position = try position(buys: [(10, "100")])
        try position.sell(quantity: quantity, price: money(price))
        #expect(position.quantity == expectedQuantity)
        #expect(position.realizedPnL == money(expectedRealized))
    }

    @Test func partialSellKeepsAverageCost() throws {
        var position = try position(buys: [(10, "100"), (10, "120")])
        try position.sell(quantity: 5, price: money("150"))
        #expect(position.averageCost == money("110"))
    }

    @Test func sellingEverythingResetsAverageCostButKeepsRealizedPnL() throws {
        var position = try position(buys: [(10, "100")])
        try position.sell(quantity: 10, price: money("125"))
        #expect(position.quantity == 0)
        #expect(position.averageCost == .zero)
        #expect(position.realizedPnL == money("250"))
    }

    /// Satışlar birikir: iki ayrı satışın K/Z'si toplanır.
    @Test func realizedPnLAccumulates() throws {
        var position = try position(buys: [(10, "100")])
        try position.sell(quantity: 2, price: money("110"))  // +20
        try position.sell(quantity: 3, price: money("90"))   // -30
        #expect(position.realizedPnL == money("-10"))
    }

    // MARK: - Gerçekleşmemiş K/Z ve piyasa değeri

    /// 10 adet @100 için: (güncel fiyat, piyasa değeri, gerçekleşmemiş K/Z)
    @Test(arguments: [
        ("120", "1200", "200"),
        ("90", "900", "-100"),
        ("100", "1000", "0"),
    ])
    func unrealizedPnL(price: String, expectedValue: String, expectedPnL: String) throws {
        let position = try position(buys: [(10, "100")])
        #expect(position.marketValue(at: money(price)) == money(expectedValue))
        #expect(position.unrealizedPnL(at: money(price)) == money(expectedPnL))
    }

    @Test func unrealizedPnLAfterPartialSellUsesRemainingQuantity() throws {
        var position = try position(buys: [(10, "100")])
        try position.sell(quantity: 4, price: money("130"))
        // Kalan 6 adet, ortalama 100, fiyat 130 → +180
        #expect(position.unrealizedPnL(at: money("130")) == money("180"))
    }

    // MARK: - Hatalar

    @Test(arguments: [0, -1])
    func buyRejectsInvalidQuantity(quantity: Int) {
        var position = Position(symbol: thyao)
        #expect(throws: TradingError.invalidQuantity) {
            try position.buy(quantity: quantity, price: money("100"))
        }
        #expect(position.quantity == 0)
    }

    @Test(arguments: [0, -3])
    func sellRejectsInvalidQuantity(quantity: Int) throws {
        var position = try position(buys: [(10, "100")])
        #expect(throws: TradingError.invalidQuantity) {
            try position.sell(quantity: quantity, price: money("100"))
        }
        #expect(position.quantity == 10)
    }

    @Test func sellRejectsMoreThanHeldAndLeavesPositionUnchanged() throws {
        var position = try position(buys: [(10, "100")])
        let before = position

        #expect(throws: TradingError.insufficientQuantity(available: 10, requested: 11)) {
            try position.sell(quantity: 11, price: money("120"))
        }
        #expect(position == before)
    }
}
