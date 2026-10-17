import UIKit

// Storyboard yok: pencereyi kodla kuruyoruz.
// SceneDelegate sadece pencereyi açar; hangi ekranın, hangi bağımlılıklarla
// kurulacağına AppAssembler karar verir (composition root).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let assembler = AppAssembler()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = ShakeWindow(windowScene: windowScene)
        // Salla → piyasa kontrolleri (sadece simüle piyasada).
        window.onShake = { [weak assembler] in assembler?.showMarketControls() }
        // Tema koyu modda tasarlandı; açık mod Phase 13'te elden geçecek.
        window.overrideUserInterfaceStyle = .dark
        window.tintColor = Theme.Color.accent
        assembler.window = window
        window.rootViewController = assembler.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
