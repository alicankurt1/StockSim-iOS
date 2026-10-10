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

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = assembler.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
