/// Hesabın kalıcı olarak saklandığı yer (DIP: Domain sadece bu soyutlamayı bilir).
///
/// Bilerek SENKRON: `PortfolioStore` actor'ü kaydederken `await` etmez. `await` etseydi,
/// beklerken araya başka bir emir girebilirdi (actor reentrancy) ve kayıtlar karışabilirdi.
/// Küçük bir JSON dosyası için senkron yazma yeterince hızlı ve actor main thread'de değil.
public protocol PortfolioRepository: Sendable {
    /// Kayıt yoksa `nil`.
    func load() throws -> Portfolio?
    func save(_ portfolio: Portfolio) throws
}
