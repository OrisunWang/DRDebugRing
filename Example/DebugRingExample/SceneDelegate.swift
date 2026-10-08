import UIKit
#if DEBUG
import DRDebugRing
#endif

/// Owns one host window and one scene-specific debug installation.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// The scene delegate creates and retains this host window for the scene lifetime.
    var window: UIWindow?

    /// Shows the host UI first, then installs an independent UIKit debug panel in Debug only.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let host = UIWindow(windowScene: windowScene)
        // Keep one host controller per scene; the debug callback resets this exact counter.
        let homeController = ExampleHomeController()
        host.rootViewController = UINavigationController(rootViewController: homeController)
        window = host
        host.makeKeyAndVisible()
        #if DEBUG
        let panel = DebugActionsController(resetCount: { [weak homeController] in
            // A weak capture avoids making the overlay own the host page's lifetime.
            homeController?.resetCount()
        }, close: { [weak windowScene] in
            guard let windowScene = windowScene else { return }
            DRDebugRing.ringWindow(for: windowScene)?.debugRing?.collapse(completion: nil)
        })
        DRDebugRing.setupRing(withContentViewController: UINavigationController(rootViewController: panel), windowScene: windowScene)
        #endif
    }

    /// Explicit teardown demonstrates integration even though the library also observes disconnects.
    func sceneDidDisconnect(_ scene: UIScene) {
        #if DEBUG
        guard let windowScene = scene as? UIWindowScene else { return }
        DRDebugRing.removeRing(for: windowScene)
        #endif
        window = nil
    }
}
