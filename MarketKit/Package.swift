// swift-tools-version: 6.0
import PackageDescription

// Tools 6.0 → tüm target'lar Swift 6 dil modunda, strict concurrency açık.
// Uygulama target'ıyla aynı kural: üye görünürlüğü sadece import edilen modüllerden gelir.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility")
]

let package = Package(
    name: "MarketKit",
    // macOS: `swift test` simülatörsüz koşabilsin diye.
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "MarketSimulator", targets: ["MarketSimulator"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Charts", targets: ["Charts"]),
    ],
    targets: [
        // Bağımlılıklar tek yönlü: herkes Domain'e bakar, Domain kimseye bakmaz.
        .target(name: "Domain", swiftSettings: swiftSettings),
        .target(name: "MarketSimulator", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .target(name: "Persistence", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .target(name: "Charts", dependencies: ["Domain"], swiftSettings: swiftSettings),

        .testTarget(name: "DomainTests", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .testTarget(name: "MarketSimulatorTests", dependencies: ["MarketSimulator"], swiftSettings: swiftSettings),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"], swiftSettings: swiftSettings),
        .testTarget(name: "ChartsTests", dependencies: ["Charts"], swiftSettings: swiftSettings),
    ]
)
