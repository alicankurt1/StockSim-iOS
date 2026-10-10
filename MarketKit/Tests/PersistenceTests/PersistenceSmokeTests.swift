import Testing
@testable import Persistence

// Duman testi: modül derleniyor ve test altyapısı simülatörsüz çalışıyor mu?
@Test func persistenceModuleLoads() {
    #expect(PersistenceModule.name == "Persistence")
}
