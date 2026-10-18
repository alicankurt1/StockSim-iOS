import Testing
import Domain
@testable import StockSim

@MainActor
struct DistributionTests {

    /// Testler Debug'da ve `-distribution` olmadan koşar: geliştirme davranışı.
    @Test func developerBuildOffersBothSourcesAndBistTickers() {
        #expect(!Distribution.isEnabled)
        #expect(MarketDataSource.available == MarketDataSource.allCases)
        #expect(Distribution.universe.featured == BistCatalog.instruments)
    }

    /// Dağıtım metni kurgusal şirketleri ve tavsiye olmadığını açıkça söyler.
    @Test func aboutContentInDistribution() throws {
        let content = AboutContent.make(version: "1.0", build: "7", isDistribution: true)

        let market = try #require(content.sections.first { $0.title == "Simulated market" })
        #expect(market.body.contains("fictional"))
        #expect(content.sections.contains { $0.title == "Not investment advice" })
        #expect(content.sections.contains { $0.body.contains("collects no data") })
        #expect(content.footer == "Version 1.0 (7)")
    }

    @Test func aboutContentInDeveloperBuildMentionsRealData() throws {
        let content = AboutContent.make(version: "1.0", build: "1", isDistribution: false)
        let market = try #require(content.sections.first { $0.title == "Simulated market" })
        #expect(market.body.contains("delayed real data"))
    }
}
