import UIKit

// Composition root: somut tiplerin oluşturulduğu TEK yer (DIP).
// Sahneler sadece protokolleri bilir; gerçek mi sahte mi veri kaynağı kullanılacağı,
// hangi worker'ın bağlanacağı burada seçilir. Sahneler eklendikçe burası büyüyecek.
@MainActor
final class AppAssembler {

    func makeRootViewController() -> UIViewController {
        // Phase 3'te Watchlist sahnesi buraya gelecek.
        let placeholder = PlaceholderViewController(title: "Watchlist", message: "Coming in Phase 3")
        let navigationController = UINavigationController(rootViewController: placeholder)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}
