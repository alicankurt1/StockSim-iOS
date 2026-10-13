// MarketSimulator: seed'li random walk ile fiyat üretimi (actor). Phase 2'de dolacak.
import Domain

/// Modülün varlığını doğrulayan geçici işaret. Phase 2'de silinecek.
public enum MarketSimulatorModule {
    public static let name = "MarketSimulator"
    /// Domain'e bağımlılığın derlendiğini gösterir.
    public static let dependsOn = DomainModule.name
}
