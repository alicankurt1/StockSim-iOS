/// Sık gelen güncellemeleri biriktirip toplu olarak teslim eder (batching / coalescing).
///
/// Örnek: 120 hisse × saniyede 10 fiyat = saniyede 1.200 güncelleme. Her biri için ayrı bir
/// diffable `apply` yapmak yerine, aynı anahtarın sadece EN SON değeri tutulur ve bir sonraki
/// "zamanlama"da (ör. ekran karesi) hepsi tek seferde teslim edilir.
///
/// Zamanlama dışarıdan verilir (DIP): uygulamada ekran karesi, testte elle tetiklenen sahte.
/// UIKit bilmez; bu yüzden UI olmadan test edilir.
@MainActor
final class UpdateCoalescer<Key: Hashable, Value> {

    /// "Bunu bir sonraki uygun anda çalıştır" diyen fonksiyon.
    typealias Scheduler = (@escaping @MainActor () -> Void) -> Void

    private var pending: [Key: Value] = [:]
    /// Sıra korunsun diye anahtarların geliş sırası.
    private var order: [Key] = []
    private var isScheduled = false
    private let schedule: Scheduler
    private let flush: ([(Key, Value)]) -> Void

    init(schedule: @escaping Scheduler, flush: @escaping ([(Key, Value)]) -> Void) {
        self.schedule = schedule
        self.flush = flush
    }

    func submit(_ value: Value, for key: Key) {
        if pending.updateValue(value, forKey: key) == nil {
            order.append(key)
        }
        guard !isScheduled else { return }
        isScheduled = true
        schedule { [weak self] in self?.drain() }
    }

    private func drain() {
        isScheduled = false
        let batch = order.compactMap { key in pending[key].map { (key, $0) } }
        pending.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
        if !batch.isEmpty { flush(batch) }
    }
}
