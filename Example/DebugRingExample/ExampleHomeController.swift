import UIKit

/// Host page owns the counter that its button increments and the debug action resets.
final class ExampleHomeController: UIViewController {
    /// Current scene's button count; changed only by increment/reset actions and rendered in the title.
    private var count = 0
    /// Main-page control displays the count; both host and debug actions refresh its title.
    private let countButton = UIButton(type: .system)

    /// Show a single accessible counter button centered inside the host's safe area.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DebugRing Example"
        view.backgroundColor = .systemBackground
        countButton.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        countButton.titleLabel?.adjustsFontForContentSizeCategory = true
        countButton.addTarget(self, action: #selector(incrementCount), for: .touchUpInside)
        countButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countButton)
        NSLayoutConstraint.activate([
            countButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            countButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            countButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            countButton.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            countButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        updateCountButton()
    }

    /// Called by this scene's debug page; update the underlying page immediately, even while covered.
    func resetCount() {
        count = 0
        updateCountButton()
    }

    /// Each completed button tap increments the host-owned counter exactly once.
    @objc private func incrementCount() {
        count += 1
        updateCountButton()
    }

    /// Keep the visible button title and VoiceOver's announced count in sync after either action.
    private func updateCountButton() {
        countButton.setTitle("按钮计数：\(count)", for: .normal)
    }
}
