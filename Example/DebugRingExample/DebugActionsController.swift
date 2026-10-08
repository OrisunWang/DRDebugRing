import UIKit

/// Host-owned debug page exposes one operation that resets the main page's counter.
final class DebugActionsController: UITableViewController {
    /// Scene delegate connects this action to its own host controller, avoiding cross-scene state changes.
    private let resetCount: () -> Void
    /// Scene delegate supplies the callback that collapses only this scene's ring.
    private let close: () -> Void

    /// Inject the host operation and panel closing independently of DebugRing's library APIs.
    init(resetCount: @escaping () -> Void, close: @escaping () -> Void) {
        self.resetCount = resetCount
        self.close = close
        super.init(style: .insetGrouped)
    }

    /// This example is created in code and requires explicit host callbacks.
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(resetCount:close:)") }

    /// Keep standard UIKit navigation and provide an explicit panel close action.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug 操作"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(closePanel))
    }

    /// The example intentionally contains a single debug operation: resetting the host button count.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    /// Present the reset action as a system-styled, accessible table button.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "重置按钮计数"
        cell.textLabel?.textColor = .systemBlue
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.accessibilityTraits = .button
        return cell
    }

    /// Reset the host counter without closing the panel, allowing repeated debug operations.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        resetCount()
    }

    /// Delegate closing to the scene integration so the page remains independent of the pod.
    @objc private func closePanel() { close() }
}
