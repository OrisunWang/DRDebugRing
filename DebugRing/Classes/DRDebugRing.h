// DebugRing — adapted from the original debug ring by Erick (2017).
#import <UIKit/UIKit.h>

// The dedicated build flag is defined only for the pod's Debug configuration.
#ifdef DEBUG_RING
NS_ASSUME_NONNULL_BEGIN

/// Posted after expansion completes; object is the ring that changed state.
UIKIT_EXTERN NSNotificationName const DRDebugRingDidExpandNotification;
/// Posted after collapse completes; object is the ring that changed state.
UIKIT_EXTERN NSNotificationName const DRDebugRingDidCollapseNotification;
@class DRDebugRing;
/// Completion runs on the main thread, including when an operation is already satisfied.
typedef void (^DRDebugRingCompletionBlock)(DRDebugRing *ring);

/// Overlay window that forwards touches outside the collapsed ring to the host app.
@interface DRRingWindow : UIWindow
/// Installed ring, updated during setup/removal and used for touch routing.
@property (nonatomic, strong, readonly, nullable) DRDebugRing *debugRing;
@end

/// UIKit control retained for compatibility with the original Objective-C integration.
/// All APIs must be called on the main thread; use a fresh, unparented content controller.
@interface DRDebugRing : UIControl
/// Whether the panel is collapsed; updated at expansion start and after collapse finishes.
@property (nonatomic, readonly, getter=isCollapsed) BOOL collapsed;
/// Installs in the sole foreground scene; explicitly pass a scene in multi-window apps.
+ (void)setupRingWithContentViewController:(UIViewController *)viewController;
/// Replaces the ring for the given scene, leaving other scenes independent.
+ (void)setupRingWithContentViewController:(UIViewController *)viewController windowScene:(UIWindowScene *)windowScene;
/// Returns the sole foreground scene's existing overlay, without creating a window.
+ (nullable DRRingWindow *)ringWindow;
/// Returns a scene's existing overlay, without changing visibility or key-window state.
+ (nullable DRRingWindow *)ringWindowForScene:(UIWindowScene *)windowScene;
/// Tears down the scene's overlay and restores the host key window when needed.
+ (void)removeRingForScene:(UIWindowScene *)windowScene NS_SWIFT_NAME(removeRing(for:));
/// Expands to a centered panel within the scene's safe area.
- (void)expandWithCompletion:(nullable DRDebugRingCompletionBlock)completion;
/// Removes content from the container after animating back to the ring position.
- (void)collapseWithCompletion:(nullable DRDebugRingCompletionBlock)completion;
/// Collapses first, then hides the window completely so invisible UI cannot intercept touches.
- (void)hideRing:(nullable DRDebugRingCompletionBlock)completion;
/// Reveals the overlay without taking keyboard focus from the host app.
- (void)showRing:(nullable DRDebugRingCompletionBlock)completion;
@end

/// Prefixed convenience accessor; explicit scene lookup is preferred for multi-window apps.
@interface UIApplication (DRDebugRing)
/// Existing foreground ring, resolved on access; nil when absent or ambiguous.
@property (nonatomic, readonly, nullable) DRDebugRing *DR_debugRing;
@end
NS_ASSUME_NONNULL_END
#endif
