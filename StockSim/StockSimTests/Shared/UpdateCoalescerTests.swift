import Testing
@testable import StockSim

/// Elle tetiklenen zamanlayıcı: "ekran karesi geldi" anını test belirler.
@MainActor
private final class ManualScheduler {
    private var work: [@MainActor () -> Void] = []
    var pendingCount: Int { work.count }

    func schedule(_ block: @escaping @MainActor () -> Void) { work.append(block) }

    func runNextFrame() {
        let current = work
        work.removeAll()
        current.forEach { $0() }
    }
}

@MainActor
struct UpdateCoalescerTests {

    private func make() -> (UpdateCoalescer<String, Int>, ManualScheduler, () -> [[(String, Int)]]) {
        let scheduler = ManualScheduler()
        var batches: [[(String, Int)]] = []
        let coalescer = UpdateCoalescer<String, Int>(
            schedule: { scheduler.schedule($0) },
            flush: { batches.append($0) }
        )
        return (coalescer, scheduler, { batches })
    }

    /// Bir kare içinde gelen tüm güncellemeler tek seferde teslim edilir.
    @Test func updatesWithinAFrameArriveAsOneBatch() {
        let (coalescer, scheduler, batches) = make()

        coalescer.submit(1, for: "THYAO")
        coalescer.submit(1, for: "ASELS")
        #expect(batches().isEmpty)          // kare gelmeden teslim yok
        #expect(scheduler.pendingCount == 1) // tek bir zamanlama

        scheduler.runNextFrame()

        #expect(batches().count == 1)
        #expect(batches().first?.map(\.0) == ["THYAO", "ASELS"])
    }

    /// Aynı anahtarın sadece en son değeri teslim edilir; sıra ilk geliş sırası.
    @Test func onlyTheLatestValuePerKeyIsDelivered() {
        let (coalescer, scheduler, batches) = make()

        coalescer.submit(1, for: "THYAO")
        coalescer.submit(5, for: "ASELS")
        coalescer.submit(2, for: "THYAO")
        coalescer.submit(3, for: "THYAO")
        scheduler.runNextFrame()

        #expect(batches().first?.map(\.0) == ["THYAO", "ASELS"])
        #expect(batches().first?.map(\.1) == [3, 5])
    }

    /// Teslimden sonra gelen güncelleme yeni bir kare planlar.
    @Test func laterUpdatesScheduleANewFrame() {
        let (coalescer, scheduler, batches) = make()

        coalescer.submit(1, for: "THYAO")
        scheduler.runNextFrame()
        coalescer.submit(2, for: "THYAO")
        scheduler.runNextFrame()

        #expect(batches().map { $0.map(\.1) } == [[1], [2]])
    }

    /// 1.200 güncelleme (120 hisse × 10) → 1 teslim, 120 satır.
    @Test func stressBurstCollapsesToOneApply() {
        let (coalescer, scheduler, batches) = make()

        for tick in 0..<10 {
            for index in 0..<120 { coalescer.submit(tick, for: "STR\(index)") }
        }
        scheduler.runNextFrame()

        #expect(batches().count == 1)
        #expect(batches().first?.count == 120)
        #expect(batches().first?.allSatisfy { $0.1 == 9 } == true)
    }
}
