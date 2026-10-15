import Foundation

/// Seed'li rastgele sayı üreteci (SplitMix64).
///
/// Swift'in `SystemRandomNumberGenerator`'ı her çalıştırmada farklı sayı verir.
/// Bu üreteç aynı seed ile hep aynı diziyi verir; testler tekrarlanabilir olur.
struct SeededGenerator: RandomNumberGenerator, Sendable {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Standart normal dağılımdan bir sayı (ortalama 0, standart sapma 1). Box–Muller yöntemi.
    mutating func nextGaussian() -> Double {
        // log(0) olmasın diye u1 sıfırdan büyük seçilir.
        let u1 = Double.random(in: Double.ulpOfOne..<1, using: &self)
        let u2 = Double.random(in: 0..<1, using: &self)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// Bir metinden her çalıştırmada AYNI olan sayı üretir (FNV-1a).
///
/// Neden `hashValue` değil? Swift güvenlik için `hashValue`'yu her açılışta
/// rastgele tohumlar; dün "THYAO" için çıkan sayı bugün farklı olur.
func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x0000_0100_0000_01B3
    }
    return hash
}
