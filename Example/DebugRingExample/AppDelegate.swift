import UIKit

/// The example uses a scene lifecycle so each window owns its own debug content.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Returns scene configuration without changing any signing or entitlement settings.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
