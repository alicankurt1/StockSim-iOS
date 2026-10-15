// Charts: elle çizilen grafik view'ları (sparkline, çizgi, mum).
// UIKit'e bağlı kod `#if canImport(UIKit)` içinde durur; böylece saf geometri
// (ölçek, hit-test) macOS'ta `swift test` ile test edilebilir.
import Domain

/// Modülün varlığını doğrulayan geçici işaret. Phase 4'te silinecek.
public enum ChartsModule {
    public static let name = "Charts"
}
