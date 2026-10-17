import Foundation
import Testing
@testable import Domain

private let thyao = Instrument(symbol: Symbol("THYAO"), name: "Türk Hava Yolları")

private func day(_ value: Int) -> Date {
    // UTC takvimiyle sabit günler: testler cihazın saat dilimine bağlı olmasın.
    Date(timeIntervalSince1970: TimeInterval(value) * 86_400)
}

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func candle(_ dayIndex: Int, open: Decimal) -> Candle {
    Candle(date: day(dayIndex), open: Money(open), high: Money(open), low: Money(open), close: Money(open))
}

struct WhatIfScenarioTests {

    /// 100.000 ₺ / 250 ₺ = 400 adet; fiyat 300 → değer 120.000, K/Z +20.000, getiri %20.
    @Test func valueAndProfit() {
        let scenario = WhatIfScenario(instrument: thyao, amount: Money(100_000), startDate: day(0), entryPrice: Money(250))

        #expect(scenario.shares == 400)
        #expect(scenario.value(at: Money(300)) == Money(120_000))
        #expect(scenario.profitLoss(at: Money(300)) == Money(20_000))
        #expect(scenario.returnPercent(at: Money(300)) == 20)
    }

    /// Kesirli adet: 1.000 / 300 = 3,333…; fiyat değişmezse değer yine (neredeyse) 1.000.
    @Test func fractionalSharesKeepValue() {
        let scenario = WhatIfScenario(instrument: thyao, amount: Money(1_000), startDate: day(0), entryPrice: Money(300))
        let difference = scenario.value(at: Money(300)).amount - 1_000
        #expect(abs(NSDecimalNumber(decimal: difference).doubleValue) < 0.000001)
    }

    @Test func zeroEntryPriceIsSafe() {
        let scenario = WhatIfScenario(instrument: thyao, amount: Money(1_000), startDate: day(0), entryPrice: .zero)
        #expect(scenario.shares == 0)
        #expect(scenario.returnPercent(at: Money(10)) == 0)
    }
}

struct WhatIfCalculatorTests {

    private let candles = [candle(10, open: 100), candle(11, open: 101), candle(14, open: 104)]   // 12–13: hafta sonu

    /// Seçilen günün mumu; o gün işlem yoksa sonraki ilk işlem günü; mumlardan sonrası → son mum.
    @Test(arguments: [(10, 0), (11, 1), (12, 2), (13, 2), (14, 2), (30, 2), (2, 0)])
    func entryIndex(selectedDay: Int, expected: Int) {
        #expect(WhatIfCalculator.entryIndex(in: candles, on: day(selectedDay), calendar: utc) == expected)
    }

    @Test func noCandlesNoEntry() {
        #expect(WhatIfCalculator.entryIndex(in: [], on: day(1)) == nil)
    }

    /// Son ~1 ay günlük mumlarla, daha eskisi haftalık mumlarla.
    @Test(arguments: [(5, ChartRange.month), (31, .month), (32, .year), (300, .year)])
    func rangeForDate(daysAgo: Int, expected: ChartRange) {
        let now = day(1_000)
        #expect(WhatIfCalculator.range(for: day(1_000 - daysAgo), now: now) == expected)
    }
}

struct WhatIfStoreTests {

    @Test func addPutsNewestFirstAndRemoveDeletes() async {
        let store = WhatIfStore()
        let first = WhatIfScenario(instrument: thyao, amount: Money(1), startDate: day(0), entryPrice: Money(1))
        let second = WhatIfScenario(instrument: thyao, amount: Money(2), startDate: day(0), entryPrice: Money(1))

        await store.add(first)
        await store.add(second)
        #expect(await store.current().map(\.id) == [second.id, first.id])

        await store.remove(second.id)
        #expect(await store.current().map(\.id) == [first.id])
    }

    @Test func updateReplacesInPlace() async {
        let store = WhatIfStore()
        let first = WhatIfScenario(instrument: thyao, amount: Money(1), startDate: day(0), entryPrice: Money(1))
        let second = WhatIfScenario(instrument: thyao, amount: Money(2), startDate: day(0), entryPrice: Money(1))
        await store.add(first)
        await store.add(second)

        let edited = WhatIfScenario(id: first.id, instrument: thyao, amount: Money(5), startDate: day(3), entryPrice: Money(2))
        await store.update(edited)

        #expect(await store.current() == [second, edited])
    }

    @Test func changesStreamCurrentThenUpdates() async {
        let store = WhatIfStore()
        var iterator = await store.changes().makeAsyncIterator()
        #expect(await iterator.next() == [])

        let scenario = WhatIfScenario(instrument: thyao, amount: Money(1), startDate: day(0), entryPrice: Money(1))
        await store.add(scenario)
        #expect(await iterator.next() == [scenario])
    }
}
