import XCTest
import UIKit
import DRDebugRing

/// Integration checks exercise actual scene windows, containment and touch routing on iOS.
final class DebugRingTests: XCTestCase {
    /// Locate the host scene rather than constructing an artificial disconnected UIWindowScene.
    @MainActor private func hostScene() throws -> UIWindowScene {
        try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }

    /// Verify replacement removes the old hierarchy and a collapsed ring passes outside touches.
    @MainActor func testReplacementAndTouchPassthrough() throws {
        let scene = try hostScene()
        defer { DRDebugRing.removeRing(for: scene) }
        DRDebugRing.setupRing(withContentViewController: UIViewController(), windowScene: scene)
        let old = try XCTUnwrap(DRDebugRing.ringWindow(for: scene))
        DRDebugRing.setupRing(withContentViewController: UIViewController(), windowScene: scene)
        let window = try XCTUnwrap(DRDebugRing.ringWindow(for: scene))
        let ring = try XCTUnwrap(window.debugRing)
        XCTAssertFalse(old === window)
        XCTAssertTrue(old.isHidden)
        XCTAssertTrue(old.rootViewController?.view.subviews.isEmpty == true)
        XCTAssertTrue(ring.isCollapsed)
        XCTAssertFalse(window.point(inside: CGPoint(x: window.bounds.midX, y: window.bounds.midY), with: nil))
        let center = ring.convert(CGPoint(x: ring.bounds.midX, y: ring.bounds.midY), to: window)
        XCTAssertTrue(window.point(inside: center, with: nil))
        ring.hide(nil)
        XCTAssertTrue(window.isHidden)
        XCTAssertFalse(window.point(inside: center, with: nil))
        ring.show(nil)
        XCTAssertFalse(window.isHidden)
        DRDebugRing.removeRing(for: scene)
        XCTAssertNil(DRDebugRing.ringWindow(for: scene))
    }

    /// Expansion mounts content and focuses the overlay; hide restores focus and detaches content.
    @MainActor func testExpandThenHideRestoresHostAndContainment() throws {
        let scene = try hostScene()
        defer { DRDebugRing.removeRing(for: scene) }
        let host = scene.windows.first(where: { $0.isKeyWindow })
        let content = UIViewController()
        DRDebugRing.setupRing(withContentViewController: content, windowScene: scene)
        let window = try XCTUnwrap(DRDebugRing.ringWindow(for: scene))
        let ring = try XCTUnwrap(window.debugRing)
        let expanded = expectation(description: "expanded notification")
        let expansion = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "DRDebugRingDidExpandNotification"), object: ring, queue: .main) { _ in expanded.fulfill() }
        defer { NotificationCenter.default.removeObserver(expansion) }
        ring.expand(completion: nil)
        wait(for: [expanded], timeout: 3)
        XCTAssertFalse(ring.isCollapsed)
        XCTAssertTrue(window.isKeyWindow)
        let backgroundTap = try XCTUnwrap(window.rootViewController?.view.gestureRecognizers?.first)
        XCTAssertTrue(backgroundTap.delegate?.gestureRecognizerShouldBegin?(backgroundTap) == true)
        XCTAssertTrue(content.parent === window.rootViewController)
        let hidden = expectation(description: "collapse before hiding")
        ring.hide { _ in hidden.fulfill() }
        wait(for: [hidden], timeout: 3)
        XCTAssertTrue(ring.isCollapsed)
        XCTAssertTrue(window.isHidden)
        XCTAssertNil(content.parent)
        XCTAssertNil(content.view.superview)
        XCTAssertTrue(host?.isKeyWindow == true)
    }

    /// Reinstalling during animation must not let the old completion reattach orphaned content.
    @MainActor func testRemovalDuringExpansion() throws {
        let scene = try hostScene()
        defer { DRDebugRing.removeRing(for: scene) }
        let content = UIViewController()
        DRDebugRing.setupRing(withContentViewController: content, windowScene: scene)
        let ring = try XCTUnwrap(DRDebugRing.ringWindow(for: scene)?.debugRing)
        let finished = expectation(description: "interrupted expansion completes")
        ring.expand { _ in finished.fulfill() }
        DRDebugRing.removeRing(for: scene)
        wait(for: [finished], timeout: 3)
        XCTAssertNil(content.parent)
        XCTAssertNil(content.view.superview)
        XCTAssertNil(DRDebugRing.ringWindow(for: scene))
    }
}
