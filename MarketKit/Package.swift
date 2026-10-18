// swift-tools-version: 6.0
import PackageDescription

// Tools 6.0 → tüm target'lar Swift 6 dil modunda, strict concurrency açık.
// Uygulama target'ıyla aynı kural: üye görünürlüğü sadece import edilen modüllerden gelir.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility")
]

// Gerçek veri sadece Debug derlemesinde var. Release (TestFlight) derlemesinde
// `MarketData` boş bir modül olur: Yahoo kodu ve adresleri uygulamaya hiç girmez.
let realDataSettings = swiftSettings + [.define("REAL_DATA", .when(configuration: .debug))]

let package = Package(
    name: "MarketKit",
    // macOS: `swift test` simülatörsüz koşabilsin diye.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "MarketSimulator", targets: ["MarketSimulator"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "MarketData", targets: ["MarketData"]),
        .library(name: "Charts", targets: ["Charts"]),
    ],
    targets: [
        // Bağımlılıklar tek yönlü: herkes Domain'e bakar, Domain kimseye bakmaz.
        .target(name: "Domain", swiftSettings: swiftSettings),
        .target(name: "MarketSimulator", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .target(name: "Persistence", dependencies: ["Domain"], swiftSettings: swiftSettings),
        // Gerçek (gecikmeli) piyasa verisi: HTTP üzerinden.
        .target(name: "MarketData", dependencies: ["Domain"], swiftSettings: realDataSettings),
        .target(name: "Charts", dependencies: ["Domain"], swiftSettings: swiftSettings),

        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .testTarget(name: "MarketSimulatorTests", dependencies: ["MarketSimulator"], swiftSettings: swiftSettings),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"], swiftSettings: swiftSettings),
        .testTarget(name: "MarketDataTests", dependencies: ["MarketData"], swiftSettings: realDataSettings),
        .testTarget(name: "ChartsTests", dependencies: ["Charts"], swiftSettings: swiftSettings),
    ]
)
