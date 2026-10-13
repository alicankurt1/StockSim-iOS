import Testing
@testable import Domain

// Duman testi: modül derleniyor ve test altyapısı simülatörsüz çalışıyor mu?
@Test func domainModuleLoads() {
    #expect(DomainModule.name == "Domain")
}
