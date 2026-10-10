import Testing
@testable import Charts

// Duman testi: modül derleniyor ve test altyapısı simülatörsüz çalışıyor mu?
@Test func chartsModuleLoads() {
    #expect(ChartsModule.name == "Charts")
}
