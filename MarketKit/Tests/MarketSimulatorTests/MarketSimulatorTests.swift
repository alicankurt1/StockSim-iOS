import Foundation
import Testing
import Domain
@testable import MarketSimulator

private let thyao = Symbol("THYAO")
private let asels = Symbol("ASELS")
private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

/// İki hisseli, beklemeyen, saati sabit bir simülatör.
private func makeSimulator(seed: UInt64 = 42, sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> MarketSimulator {
    MarketSimulator(
        configuration: SimulatorConfiguration(seed: seed, instruments: [
            SimulatedInstrument("THYAO", name: "Türk Hava Yolları", price: 100),
            SimulatedInstrument("ASELS", name: "Aselsan", price: 50),
        ]),
        sleep: sleep,
        now: { fixedNow }
    )
}

/// Akıştan sıradaki `count` olayı alır.
private func next(_ count: Int, from iterator: inout AsyncStream<MarketUpdate>.Iterator) async -> [MarketUpdate] {
    var updates: [MarketUpdate] = []
    for _ in 0..<count {
        guard let update = await iterator.next() else { break }
        updates.append(update)
    }
    return updates
}

private func price(_ update: MarketUpdate) -> Money? {
    if case let .quote(quote) = update { quote.price } else { nil }
}

struct MarketSimulatorTests {

    // MARK: - Determinizm

    @Test func sameSeedProducesSamePrices() async {
        let a = makeSimulator(seed: 7)
        let b = makeSimulator(seed: 7)
        for _ in 0..<50 {
            await a.tick()
            await b.tick()
        }
        #expect(await a.quote(for: thyao) == b.quote(for: thyao))
        #expect(await a.quote(for: asels) == b.quote(for: asels))
    }

    @Test func differentSeedProducesDifferentPrices() async {
        let a = makeSimulator(seed: 1)
        let b = makeSimulator(seed: 2)
        for _ in 0..<50 {
            await a.tick()
            await b.tick()
        }
        #expect(await a.rawPrice(of: thyao) != b.rawPrice(of: thyao))
    }

    // MARK: - Akış

    @Test func subscribingSendsCurrentQuotesOnlyForRequestedSymbols() async {
        let simulator = makeSimulator()
        var iterator = await simulator.updates(for: [thyao]).makeAsyncIterator()

        let first = await next(1, from: &iterator)
        #expect(first == [.quote(await simulator.quote(for: thyao)!)])

        await simulator.tick()
        let afterTick = await next(1, from: &iterator)
        #expect(afterTick == [.quote(await simulator.quote(for: thyao)!)])
    }

    @Test func quoteKeepsPreviousCloseForDailyChange() async {
        let simulator = makeSimulator()
        for _ in 0..<10 { await simulator.tick() }
        let quote = await simulator.quote(for: thyao)!
        #expect(quote.previousClose == Money(100))
        #expect(quote.timestamp == fixedNow)
    }

    @Test func cancellingTheListenerRemovesTheSubscriber() async {
        let simulator = makeSimulator()
        let stream = await simulator.updates(for: [thyao])
        #expect(await simulator.subscriberCount == 1)

        let listener = Task { for await _ in stream {} }
        listener.cancel()
        await listener.value

        // Temizlik actor'e ayrı bir Task ile gidiyor; birkaç tur bekle.
        for _ in 0..<100 where await simulator.subscriberCount > 0 {
            await Task.yield()
        }
        #expect(await simulator.subscriberCount == 0)
    }

    @Test func startedLoopProducesQuotesUntilStopped() async {
        let simulator = makeSimulator(sleep: { _ in await Task.yield() })
        var iterator = await simulator.updates(for: [thyao]).makeAsyncIterator()
        _ = await next(1, from: &iterator)   // ilk değer

        await simulator.start()
        let updates = await next(3, from: &iterator)
        await simulator.stop()

        #expect(updates.count == 3)
        #expect(updates.allSatisfy { price($0) != nil })
    }

    // MARK: - Tetikleyiciler

    @Test func crashDropsPriceByPercent() async {
        let simulator = makeSimulator()
        await simulator.trigger(.crash(thyao, percent: 10))
        #expect(await simulator.quote(for: thyao)?.price == Money(90))
        #expect(await simulator.quote(for: asels)?.price == Money(50))
    }

    @Test func crashWithoutSymbolHitsEverything() async {
        let simulator = makeSimulator()
        await simulator.trigger(.crash(nil, percent: 20))
        #expect(await simulator.quote(for: thyao)?.price == Money(80))
        #expect(await simulator.quote(for: asels)?.price == Money(40))
    }

    @Test func haltFreezesPriceAndResumeRestores() async {
        let simulator = makeSimulator()
        var iterator = await simulator.updates(for: [thyao]).makeAsyncIterator()
        _ = await next(1, from: &iterator)

        await simulator.trigger(.halt(thyao))
        #expect(await next(1, from: &iterator) == [.halted(thyao)])
        #expect(await simulator.isHalted(thyao))

        let frozen = await simulator.rawPrice(of: thyao)
        for _ in 0..<5 { await simulator.tick() }
        #expect(await simulator.rawPrice(of: thyao) == frozen)

        await simulator.trigger(.resume(thyao))
        let resumed = await next(2, from: &iterator)
        #expect(resumed.first == .resumed(thyao))
        #expect(price(resumed[1]) != nil)
    }

    /// Bir hissenin durdurulması diğerlerinin fiyat yolunu değiştirmemeli.
    @Test func haltingOneSymbolDoesNotChangeOthers() async {
        let baseline = makeSimulator()
        let halted = makeSimulator()
        await halted.trigger(.halt(thyao))
        for _ in 0..<20 {
            await baseline.tick()
            await halted.tick()
        }
        #expect(await baseline.rawPrice(of: asels) == halted.rawPrice(of: asels))
    }

    @Test func droppedFeedGoesSilentThenRestores() async {
        let simulator = makeSimulator()   // tickInterval 1 sn
        var iterator = await simulator.updates(for: [thyao]).makeAsyncIterator()
        _ = await next(1, from: &iterator)

        await simulator.trigger(.dropFeed(duration: .seconds(3)))
        #expect(await next(1, from: &iterator) == [.feedInterrupted])

        // İlk iki tick sessiz; crash bile duyurulmaz.
        await simulator.tick()
        await simulator.trigger(.crash(thyao, percent: 5))
        await simulator.tick()
        // Üçüncü tick'te akış geri gelir ve güncel fiyat yollanır.
        await simulator.tick()
        let restored = await next(2, from: &iterator)
        #expect(restored.first == .feedRestored)
        #expect(price(restored[1]) == (await simulator.quote(for: thyao))?.price)
    }

    @Test func volatilitySpikeAmplifiesMovesThenEnds() async throws {
        let baseline = makeSimulator()
        let spiked = makeSimulator()
        await spiked.trigger(.volatilitySpike(multiplier: 5, duration: .seconds(2)))

        // Aynı rastgele sayılar: spike süresince fark büyür.
        await baseline.tick(); await spiked.tick()
        let baseMove = abs(log(try #require(await baseline.rawPrice(of: thyao)) / 100))
        let spikedMove = abs(log(try #require(await spiked.rawPrice(of: thyao)) / 100))
        #expect(spikedMove > baseMove * 4)

        // 2 tick sonra spike biter: tick'teki oransal hareket tekrar aynı olur.
        await baseline.tick(); await spiked.tick()
        let baseBefore = try #require(await baseline.rawPrice(of: thyao))
        let spikedBefore = try #require(await spiked.rawPrice(of: thyao))
        await baseline.tick(); await spiked.tick()
        let baseRatio = try #require(await baseline.rawPrice(of: thyao)) / baseBefore
        let spikedRatio = try #require(await spiked.rawPrice(of: thyao)) / spikedBefore
        #expect(abs(baseRatio - spikedRatio) < 1e-12)
    }

    // MARK: - Geçmiş

    @Test func historyEndsAtLivePrice() async throws {
        let simulator = makeSimulator()
        for _ in 0..<10 { await simulator.tick() }
        let candles = try await simulator.history(for: thyao, range: .day)
        #expect(candles.last?.close == (await simulator.quote(for: thyao))?.price)
    }

    @Test func historyIsDeterministic() async throws {
        let a = try await makeSimulator().history(for: thyao, range: .year)
        let b = try await makeSimulator().history(for: thyao, range: .year)
        #expect(a == b)
    }

    @Test func historyForUnknownSymbolThrows() async {
        let unknown = Symbol("NOPE")
        await #expect(throws: MarketDataError.unknownSymbol(unknown)) {
            try await makeSimulator().history(for: unknown, range: .day)
        }
    }

    @Test func instrumentsComeFromConfiguration() async {
        #expect(await makeSimulator().instruments().map(\.symbol) == [thyao, asels])
    }
}
