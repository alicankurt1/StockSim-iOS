import UIKit
import Domain
import MarketSimulator

/// Geliştirici aracı: simülatörün uç durum tetikleyicilerini uygulama içinden çalıştırır.
///
/// Bilerek bir VIP sahnesi değil: ürünün parçası değil, sadece composition root'un
/// simülatöre erişimiyle çalışan küçük bir test paneli. Ekranlar bu olayları normal
/// akıştan (`MarketUpdate`) alır; yani bu panel ekranların uç durum davranışını gerçekten dener.
@MainActor
final class MarketControlsMenu {

    private let simulator: MarketSimulator
    private let watchlist: any WatchlistStoring

    init(simulator: MarketSimulator, watchlist: any WatchlistStoring) {
        self.simulator = simulator
        self.watchlist = watchlist
    }

    func present(from presenter: UIViewController) {
        let sheet = UIAlertController(
            title: "Market controls",
            message: "Simulated market only. Screens react through the normal price stream.",
            preferredStyle: .actionSheet
        )
        sheet.addAction(action("Crash market −10%") { await $0.trigger(.crash(nil, percent: 10)) })
        sheet.addAction(UIAlertAction(title: "Crash a stock −15%…", style: .default) { [self, weak presenter] _ in
            // self strong: menüyü başka kimse tutmuyor; weak olsaydı burada nil olurdu.
            // Döngü yok: alert menüyü tutar, menü alert'i tutmaz.
            guard let presenter else { return }
            self.chooseStock(title: "Crash which stock?", from: presenter) { simulator, symbol in
                await simulator.trigger(.crash(symbol, percent: 15))
            }
        })
        sheet.addAction(action("Volatility spike ×6 (30 s)") { await $0.trigger(.volatilitySpike(multiplier: 6, duration: .seconds(30))) })
        sheet.addAction(UIAlertAction(title: "Halt / resume a stock…", style: .default) { [self, weak presenter] _ in
            // self strong: menüyü başka kimse tutmuyor; weak olsaydı burada nil olurdu.
            // Döngü yok: alert menüyü tutar, menü alert'i tutmaz.
            guard let presenter else { return }
            self.chooseStock(title: "Halt or resume", from: presenter, toggleHalt: true) { simulator, symbol in
                let halted = await simulator.isHalted(symbol)
                await simulator.trigger(halted ? .resume(symbol) : .halt(symbol))
            }
        })
        sheet.addAction(action("Drop price feed (10 s)") { await $0.trigger(.dropFeed(duration: .seconds(10))) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        anchor(sheet, in: presenter)
        presenter.present(sheet, animated: true)
    }

    // MARK: - Yardımcılar

    private func action(_ title: String, run: @escaping @Sendable (MarketSimulator) async -> Void) -> UIAlertAction {
        UIAlertAction(title: title, style: .default) { [simulator] _ in
            Task { await run(simulator) }
        }
    }

    /// İzleme listesinden hisse seçtirir. `toggleHalt`: başlıkta "Halt"/"Resume" göster.
    private func chooseStock(
        title: String,
        from presenter: UIViewController,
        toggleHalt: Bool = false,
        run: @escaping @Sendable (MarketSimulator, Symbol) async -> Void
    ) {
        Task { [simulator, watchlist] in
            let instruments = await watchlist.current()
            let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            for instrument in instruments {
                var label = instrument.symbol.rawValue
                if toggleHalt {
                    label = await simulator.isHalted(instrument.symbol) ? "Resume \(label)" : "Halt \(label)"
                }
                sheet.addAction(UIAlertAction(title: label, style: .default) { _ in
                    Task { await run(simulator, instrument.symbol) }
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            anchor(sheet, in: presenter)
            presenter.present(sheet, animated: true)
        }
    }

    /// iPad'de action sheet bir kaynağa bağlanmak zorunda.
    private func anchor(_ sheet: UIAlertController, in presenter: UIViewController) {
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
    }
}
