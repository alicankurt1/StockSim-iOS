import os

/// Instruments'ta görünen ölçüm işaretleri ("Points of Interest" ve "os_signpost" araçları).
///
/// Kullanım: Xcode → Product → Profile → "Time Profiler" ya da "Animation Hitches";
/// işaretler zaman çizelgesinde aralık olarak görünür: hangi iş ne kadar sürdü, ne sıklıkta.
enum Signposts {
    static let signposter = OSSignposter(subsystem: "com.alicankurt.StockSim", category: .pointsOfInterest)
}
