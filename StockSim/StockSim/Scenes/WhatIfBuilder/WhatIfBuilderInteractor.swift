import Foundation
import Domain

@MainActor
protocol WhatIfBuilderBusinessLogic {
    func load() async
    func edit(request: WhatIfBuilder.Edit.Request) async
    func track() async
}

/// Liste ekranının Router'ı düzenlenecek senaryoyu buraya yazar (DataPassing).
/// Boşsa yeni senaryo oluşturulur.
@MainActor
protocol WhatIfBuilderDataStore: AnyObject {
    var editing: WhatIfScenario? { get set }
}

/// Senaryoyu hesaplar: seçilen tarihteki alım fiyatını geçmiş mumlardan bulur,
/// bugünkü fiyatla değeri ve kâr/zararı çıkarır. Hesap kuralları Domain'de (`WhatIfScenario`).
@MainActor
final class WhatIfBuilderInteractor: WhatIfBuilderBusinessLogic, WhatIfBuilderDataStore {

    var editing: WhatIfScenario?

    private let presenter: WhatIfBuilderPresentationLogic
    private let worker: WhatIfBuilderWorking
    private let now: () -> Date

    private var instruments: [Instrument] = []
    private var instrument: Instrument?
    private var date: Date
    private var amount: Money? = Money(100_000)
    private var lastScenario: WhatIfScenario?
    /// Her yeni hesapta artar; geç dönen eski hesap ekranı ezmesin (reentrancy).
    private var generation = 0

    init(presenter: WhatIfBuilderPresentationLogic, worker: WhatIfBuilderWorking, now: @escaping () -> Date = Date.init) {
        self.presenter = presenter
        self.worker = worker
        self.now = now
        // Varsayılan: 6 ay önce.
        self.date = now().addingTimeInterval(-182 * 24 * 60 * 60)
    }

    /// Seçilebilir tarih aralığı: geçmiş veri 1 yıllık.
    private var dateRange: ClosedRange<Date> {
        now().addingTimeInterval(-365 * 24 * 60 * 60)...now()
    }

    func load() async {
        instruments = await worker.instruments()
        if let editing {
            // Düzenleme: formu kayıtlı senaryoyla doldur. Hisse artık izleme listesinde
            // olmasa bile seçilebilir kalsın.
            if !instruments.contains(where: { $0.symbol == editing.instrument.symbol }) {
                instruments.insert(editing.instrument, at: 0)
            }
            instrument = editing.instrument
            date = editing.startDate
            amount = editing.amount
        }
        instrument = instrument ?? instruments.first
        await recalculate()
    }

    func edit(request: WhatIfBuilder.Edit.Request) async {
        if let instrument = request.instrument { self.instrument = instrument }
        if let date = request.date { self.date = min(max(date, dateRange.lowerBound), dateRange.upperBound) }
        if let text = request.amountText { amount = Self.parseAmount(text) }
        await recalculate()
    }

    func track() async {
        guard let lastScenario else { return }
        if let editing {
            // Aynı kimlikle kaydet: listede yerinde güncellenir, yeni satır eklenmez.
            let updated = WhatIfScenario(
                id: editing.id,
                instrument: lastScenario.instrument,
                amount: lastScenario.amount,
                startDate: lastScenario.startDate,
                entryPrice: lastScenario.entryPrice
            )
            await worker.update(updated)
            presenter.presentTracked(response: WhatIfBuilder.Track.Response(scenario: updated))
        } else {
            await worker.track(lastScenario)
            presenter.presentTracked(response: WhatIfBuilder.Track.Response(scenario: lastScenario))
        }
    }

    // MARK: - Hesap

    private func recalculate() async {
        generation += 1
        let current = generation
        lastScenario = nil

        guard let instrument else { return present(.unavailable) }
        guard let amount, amount.amount > 0 else { return present(.invalidAmount) }
        present(.calculating)

        let range = WhatIfCalculator.range(for: date, now: now())
        do {
            async let candles = worker.history(for: instrument.symbol, range: range)
            async let quote = worker.quote(for: instrument.symbol)
            let (loadedCandles, loadedQuote) = try await (candles, quote)
            // Beklerken kullanıcı başka bir şey seçtiyse bu sonuç eskidi.
            guard current == generation else { return }

            guard let index = WhatIfCalculator.entryIndex(in: loadedCandles, on: date),
                  let currentPrice = loadedQuote?.price else {
                return present(.unavailable)
            }
            let scenario = WhatIfScenario(
                instrument: instrument,
                amount: amount,
                startDate: date,
                entryPrice: loadedCandles[index].open
            )
            lastScenario = scenario
            present(.result(scenario, currentPrice: currentPrice, candles: Array(loadedCandles[index...])))
        } catch {
            guard current == generation else { return }
            present(.unavailable)
        }
    }

    private func present(_ outcome: WhatIfBuilder.Response.Outcome) {
        presenter.presentBuilder(response: WhatIfBuilder.Response(
            isEditing: editing != nil,
            instruments: instruments,
            instrument: instrument,
            date: date,
            dateRange: dateRange,
            amount: amount,
            outcome: outcome
        ))
    }

    /// Kullanıcının yazdığı tutar: "100000", "100.000", "1.250,50" (Türkçe biçim).
    /// Nokta binlik ayırıcı, virgül ondalık. Geçersizse `nil`.
    static func parseAmount(_ text: String) -> Money? {
        let cleaned = text
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return Money(value)
    }
}
