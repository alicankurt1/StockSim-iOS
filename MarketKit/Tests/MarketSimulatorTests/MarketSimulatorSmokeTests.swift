import Testing
@testable import MarketSimulator

// Duman testi: modül derleniyor ve test altyapısı simülatörsüz çalışıyor mu?
@Test func marketSimulatorModuleLoads() {
    #expect(MarketSimulatorModule.name == "MarketSimulator")
}
