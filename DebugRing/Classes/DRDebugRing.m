// DebugRing — adapted from the original debug ring by Erick (2017).
#import "DRDebugRing.h"
#ifdef DEBUG_RING

NSNotificationName const DRDebugRingDidExpandNotification = @"DRDebugRingDidExpandNotification";
NSNotificationName const DRDebugRingDidCollapseNotification = @"DRDebugRingDidCollapseNotification";
/// Diameter preserves the original visual size while exceeding Apple's 44-point touch minimum.
static CGFloat const DRRingDiameter = 50;

/// Main-thread-only scene registry; removal also happens when a scene disconnects.
static NSMapTable<UIWindowScene *, DRRingWindow *> *DRWindows(void) {
    static NSMapTable *windows;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ windows = [NSMapTable weakToStrongObjectsMapTable]; });
    return windows;
}
/// Avoid choosing an arbitrary scene when multiple windows are active.
static UIWindowScene *DRForegroundScene(void) {
    UIWindowScene *result = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (result) return nil;
        result = (UIWindowScene *)scene;
    }
    return result;
}
/// Enforces UIKit's thread contract even when assertions are disabled.
static BOOL DRMainThread(void) {
    NSCAssert(NSThread.isMainThread, @"DebugRing must be used on the main thread.");
    return NSThread.isMainThread;
}

@interface DRRingWindow ()
/// Set during installation and cleared during teardown; controls hit testing.
@property (nonatomic, strong, readwrite, nullable) DRDebugRing *debugRing;
@end

/// Public UIKit container handles containment and scene-driven size changes.
@interface DRRingViewController : UIViewController
@end

@interface DRDebugRing () <UIGestureRecognizerDelegate>
/// Host-provided page; mounted only while expanded and retained for subsequent openings.
@property (nonatomic, strong) UIViewController *contentViewController;
/// Owning overlay is weak to avoid the window → view → window retain cycle.
@property (nonatomic, weak) DRRingWindow *overlay;
/// Expansion sets this false immediately; collapse sets it true after content has been removed.
@property (nonatomic, readwrite, getter=isCollapsed) BOOL collapsed;
/// Last collapsed rectangle; updated by dragging and geometry changes, restored on collapse.
@property (nonatomic) CGRect collapsedFrame;
/// Pan starting rectangle, updated at gesture begin to avoid cumulative translations.
@property (nonatomic) CGRect dragFrame;
/// Serializes animation and visibility operations so containment cannot be modified twice.
@property (nonatomic) BOOL transitioning;
/// Previous scene key window, captured on expansion and restored on collapse/removal.
@property (nonatomic, weak, nullable) UIWindow *originKeyWindow;
/// Soft feedback reused for accepted expand/collapse transitions.
@property (nonatomic, strong) UIImpactFeedbackGenerator *feedback;
/// Tracks safe-area changes so ordinary content layouts do not interrupt animations.
@property (nonatomic) CGRect lastSafeBounds;
/// Scene-specific observer installed at setup and removed at teardown/deallocation.
@property (nonatomic, strong, nullable) id disconnectObserver;
/// Creates a ring without mounting the host page until the first expansion.
- (instancetype)initWithContentViewController:(UIViewController *)controller;
/// Reconciles ring/panel geometry when the containing scene changes size or safe area.
- (void)updateGeometry;
/// Releases the host page and restores keyboard focus without waiting for an animation.
- (void)tearDown;
@end

@implementation DRRingWindow
/// The expanded overlay owns its full background; the collapsed overlay owns only the ring.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.debugRing || self.debugRing.alpha <= 0.01) return NO;
    if (!self.debugRing.collapsed) return [super pointInside:point withEvent:event];
    CGPoint local = [self.debugRing convertPoint:point fromView:self];
    return [self.debugRing pointInside:local withEvent:event];
}
@end

@implementation DRRingViewController
/// A clear container leaves the underlying application visible around the panel.
- (void)loadView { self.view = [[UIView alloc] init]; self.view.backgroundColor = UIColor.clearColor; }
/// Window geometry is supplied by UIKit rather than fixed screen/device-model assumptions.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [((DRRingWindow *)self.view.window).debugRing updateGeometry];
}
@end

@implementation DRDebugRing
/// Convenience installation refuses ambiguous foreground scenes.
+ (void)setupRingWithContentViewController:(UIViewController *)controller {
    if (!DRMainThread()) return;
    UIWindowScene *scene = DRForegroundScene();
    NSAssert(scene, @"Pass windowScene explicitly when there is no sole active scene.");
    if (scene) [self setupRingWithContentViewController:controller windowScene:scene];
}
/// A fresh window per scene avoids the original global singleton's cross-scene routing issues.
+ (void)setupRingWithContentViewController:(UIViewController *)controller windowScene:(UIWindowScene *)scene {
    if (!DRMainThread()) return;
    NSAssert(controller && scene && !controller.parentViewController, @"Provide a scene and an unparented controller.");
    if (!controller || !scene || controller.parentViewController) return;
    [self removeRingForScene:scene];
    DRRingWindow *window = [[DRRingWindow alloc] initWithWindowScene:scene];
    window.frame = scene.coordinateSpace.bounds;
    window.windowLevel = UIWindowLevelAlert;
    window.backgroundColor = UIColor.clearColor;
    window.rootViewController = [[DRRingViewController alloc] init];
    DRDebugRing *ring = [[self alloc] initWithContentViewController:controller];
    ring.overlay = window;
    window.debugRing = ring;
    [window.rootViewController.view addSubview:ring];
    [DRWindows() setObject:window forKey:scene];
    __weak UIWindowScene *weakScene = scene;
    ring.disconnectObserver = [NSNotificationCenter.defaultCenter addObserverForName:UISceneDidDisconnectNotification object:scene queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        UIWindowScene *disconnected = weakScene;
        if (disconnected) [DRDebugRing removeRingForScene:disconnected];
    }];
    window.hidden = NO;
    [window.rootViewController.view layoutIfNeeded];
    [ring updateGeometry];
    UITapGestureRecognizer *outside = [[UITapGestureRecognizer alloc] initWithTarget:ring action:@selector(outsideTapped:)];
    outside.delegate = ring;
    [window.rootViewController.view addGestureRecognizer:outside];
}
/// Querying does not install UI; ambiguous scenes deliberately return nil.
+ (DRRingWindow *)ringWindow {
    if (!DRMainThread()) return nil;
    UIWindowScene *scene = DRForegroundScene();
    return scene ? [self ringWindowForScene:scene] : nil;
}
/// Scene-explicit lookup is reliable even while a scene is inactive.
+ (DRRingWindow *)ringWindowForScene:(UIWindowScene *)scene {
    return DRMainThread() ? [DRWindows() objectForKey:scene] : nil;
}
/// Immediate teardown also safely handles replacement during an animation.
+ (void)removeRingForScene:(UIWindowScene *)scene {
    if (!DRMainThread()) return;
    DRRingWindow *window = [DRWindows() objectForKey:scene];
    [window.debugRing tearDown];
    window.hidden = YES;
    window.debugRing = nil;
    // Keep the empty container until the hidden window is released, allowing UIKit to finish
    // any pending appearance transition after rapid installation/removal.
    [DRWindows() removeObjectForKey:scene];
}
/// Set up public UIKit gestures and accessible labeling without third-party dependencies.
- (instancetype)initWithContentViewController:(UIViewController *)controller {
    if ((self = [super initWithFrame:CGRectMake(0, 0, DRRingDiameter, DRRingDiameter)])) {
        _contentViewController = controller;
        _collapsed = YES;
        _feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        self.clipsToBounds = YES;
        self.backgroundColor = UIColor.clearColor;
        self.layer.cornerRadius = DRRingDiameter / 2;
        self.layer.borderWidth = 3;
        self.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.45].CGColor;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Debug actions";
        self.accessibilityHint = @"Opens the custom debug panel";
        self.accessibilityTraits = UIAccessibilityTraitButton;
        [self addTarget:self action:@selector(ringTapped) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
        pan.delegate = self;
        [self addGestureRecognizer:pan];
    }
    return self;
}
/// Token removal prevents the scene observer from outliving an uninstalled ring.
- (void)dealloc { if (_disconnectObserver) [NSNotificationCenter.defaultCenter removeObserver:_disconnectObserver]; }
/// Insets derive from the actual window, supporting notch, rotation, iPad and Stage Manager.
- (CGRect)safeBounds { return UIEdgeInsetsInsetRect(self.superview.bounds, self.superview.safeAreaInsets); }
/// Clamp all four edges so a dragged ring remains recoverable after resizing.
- (CGRect)clampedRingFrame:(CGRect)frame {
    CGRect safe = [self safeBounds];
    CGFloat diameter = MIN(DRRingDiameter, MIN(safe.size.width, safe.size.height));
    frame.size = CGSizeMake(MAX(0, diameter), MAX(0, diameter));
    frame.origin.x = MAX(CGRectGetMinX(safe), MIN(frame.origin.x, CGRectGetMaxX(safe) - diameter));
    frame.origin.y = MAX(CGRectGetMinY(safe), MIN(frame.origin.y, CGRectGetMaxY(safe) - diameter));
    return frame;
}
/// Preserve the original 80% presentation while staying within safe bounds.
- (CGRect)panelFrame { CGRect safe = [self safeBounds]; return CGRectInset(safe, safe.size.width * 0.1, safe.size.height * 0.1); }
/// First layout positions bottom-left; subsequent layouts preserve and clamp the chosen location.
- (void)updateGeometry {
    CGRect safe = [self safeBounds];
    if (CGRectEqualToRect(safe, self.lastSafeBounds)) return;
    self.lastSafeBounds = safe;
    if (CGRectIsEmpty(self.collapsedFrame)) self.collapsedFrame = CGRectMake(safe.origin.x, CGRectGetMaxY(safe) - DRRingDiameter, DRRingDiameter, DRRingDiameter);
    self.collapsedFrame = [self clampedRingFrame:self.collapsedFrame];
    if (!self.transitioning) self.frame = self.collapsed ? self.collapsedFrame : [self panelFrame];
}
/// Control and VoiceOver share the same state transition.
- (void)ringTapped { [self expandWithCompletion:nil]; }
/// Only touches outside the panel reach this recognizer's action.
- (void)outsideTapped:(UITapGestureRecognizer *)gesture { [self collapseWithCompletion:nil]; }
/// Disable dragging during presentation and animations to preserve the saved collapsed frame.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (self.transitioning) return NO;
    return [gesture isKindOfClass:UITapGestureRecognizer.class] ? !self.collapsed : self.collapsed;
}
/// The background recognizer must not cancel buttons, scrolling or text fields inside content.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if ([gesture isKindOfClass:UITapGestureRecognizer.class]) return !self.collapsed && !self.transitioning && !CGRectContainsPoint(self.frame, [touch locationInView:self.superview]);
    return self.collapsed && !self.transitioning;
}
/// Cancelled drags also snap so interruptions cannot leave the ring outside usable bounds.
- (void)panned:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) self.dragFrame = self.frame;
    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint delta = [gesture translationInView:self.superview];
        self.frame = [self clampedRingFrame:CGRectOffset(self.dragFrame, delta.x, delta.y)];
    }
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGRect frame = [self clampedRingFrame:self.frame];
        CGRect safe = [self safeBounds];
        CGFloat gaps[] = {CGRectGetMinX(frame)-CGRectGetMinX(safe), CGRectGetMaxX(safe)-CGRectGetMaxX(frame), CGRectGetMinY(frame)-CGRectGetMinY(safe), CGRectGetMaxY(safe)-CGRectGetMaxY(frame)};
        NSUInteger nearest = 0;
        for (NSUInteger i = 1; i < 4; i++) if (gaps[i] < gaps[nearest]) nearest = i;
        if (nearest == 0) frame.origin.x = CGRectGetMinX(safe);
        if (nearest == 1) frame.origin.x = CGRectGetMaxX(safe)-frame.size.width;
        if (nearest == 2) frame.origin.y = CGRectGetMinY(safe);
        if (nearest == 3) frame.origin.y = CGRectGetMaxY(safe)-frame.size.height;
        self.collapsedFrame = frame;
        self.transitioning = YES;
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.25 animations:^{ self.frame = frame; } completion:^(BOOL finished) { self.transitioning = NO; [self updateAfterTransition]; }];
    }
}
/// Resolve geometry again after animation, including scene resizing while it was running.
- (void)updateAfterTransition { self.collapsedFrame = [self clampedRingFrame:self.collapsedFrame]; self.frame = self.collapsed ? self.collapsedFrame : [self panelFrame]; }
/// Balanced containment and public makeKeyWindow enable editable custom debug panels.
- (void)expandWithCompletion:(DRDebugRingCompletionBlock)completion {
    if (!DRMainThread()) return;
    if (!self.overlay || self.overlay.hidden || !self.collapsed || self.transitioning) { if (completion) completion(self); return; }
    self.transitioning = YES;
    self.collapsedFrame = self.frame;
    for (UIWindow *window in self.overlay.windowScene.windows) if (window.isKeyWindow && window != self.overlay) self.originKeyWindow = window;
    [self.overlay makeKeyWindow];
    UIViewController *root = self.overlay.rootViewController;
    [root addChildViewController:self.contentViewController];
    UIView *content = self.contentViewController.view;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:content];
    [NSLayoutConstraint activateConstraints:@[[content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor], [content.topAnchor constraintEqualToAnchor:self.topAnchor], [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]]];
    [self.contentViewController didMoveToParentViewController:root];
    self.collapsed = NO;
    self.isAccessibilityElement = NO;
    self.backgroundColor = UIColor.systemBackgroundColor;
    [self.feedback impactOccurred];
    content.alpha = 0;
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.3 animations:^{ self.frame = [self panelFrame]; content.alpha = 1; [self layoutIfNeeded]; } completion:^(BOOL finished) {
        if (!self.overlay) { if (completion) completion(self); return; }
        self.transitioning = NO;
        [self updateAfterTransition];
        [NSNotificationCenter.defaultCenter postNotificationName:DRDebugRingDidExpandNotification object:self];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, content);
        if (completion) completion(self);
    }];
}
/// Restore host focus after removing content; never rely on private UIWindow selectors.
- (void)collapseWithCompletion:(DRDebugRingCompletionBlock)completion {
    if (!DRMainThread()) return;
    if (!self.overlay || self.collapsed || self.transitioning) { if (completion) completion(self); return; }
    self.transitioning = YES;
    [self.contentViewController.view endEditing:YES];
    [self.contentViewController willMoveToParentViewController:nil];
    [self.feedback impactOccurred];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.3 animations:^{ self.frame = self.collapsedFrame; self.contentViewController.view.alpha = 0; } completion:^(BOOL finished) {
        if (!self.overlay) { if (completion) completion(self); return; }
        [self.contentViewController.view removeFromSuperview];
        [self.contentViewController removeFromParentViewController];
        self.collapsed = YES;
        self.transitioning = NO;
        self.isAccessibilityElement = YES;
        self.backgroundColor = UIColor.clearColor;
        [self restoreHostWindow];
        [self updateAfterTransition];
        [NSNotificationCenter.defaultCenter postNotificationName:DRDebugRingDidCollapseNotification object:self];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self);
        if (completion) completion(self);
    }];
}
/// Avoid stealing focus from another host window that became key while the panel was open.
- (void)restoreHostWindow {
    if (self.overlay.isKeyWindow && self.originKeyWindow && !self.originKeyWindow.hidden && self.originKeyWindow.windowScene == self.overlay.windowScene) [self.originKeyWindow makeKeyWindow];
    self.originKeyWindow = nil;
}
/// Busy requests are ignored with completion; callers can retry after the active transition.
- (void)hideRing:(DRDebugRingCompletionBlock)completion {
    if (!DRMainThread()) return;
    if (self.transitioning || !self.overlay) { if (completion) completion(self); return; }
    if (!self.collapsed) { [self collapseWithCompletion:^(DRDebugRing *ring) { [ring hideRing:completion]; }]; return; }
    self.overlay.hidden = YES;
    if (completion) completion(self);
}
/// Showing a collapsed window preserves the app's current key window.
- (void)showRing:(DRDebugRingCompletionBlock)completion {
    if (!DRMainThread()) return;
    if (!self.transitioning) self.overlay.hidden = NO;
    if (completion) completion(self);
}
/// VoiceOver's escape gesture closes custom content without requiring a visible close button.
- (BOOL)accessibilityPerformEscape { if (self.collapsed || self.transitioning) return NO; [self collapseWithCompletion:nil]; return YES; }
/// VoiceOver activation must explicitly expand because UIControl subclasses have no title view.
- (BOOL)accessibilityActivate { if (!self.collapsed || self.transitioning) return NO; [self expandWithCompletion:nil]; return YES; }
/// Immediate teardown makes replacement safe even if Core Animation completions arrive later.
- (void)tearDown {
    if (self.disconnectObserver) [NSNotificationCenter.defaultCenter removeObserver:self.disconnectObserver];
    self.disconnectObserver = nil;
    [self.layer removeAllAnimations];
    if (self.contentViewController.parentViewController) {
        [self.contentViewController willMoveToParentViewController:nil];
        [self.contentViewController.view removeFromSuperview];
        [self.contentViewController removeFromParentViewController];
    }
    [self restoreHostWindow];
    [self removeFromSuperview];
    self.overlay = nil;
}
@end

@implementation UIApplication (DRDebugRing)
/// Resolves on demand without owning a ring or choosing between multiple scenes.
- (DRDebugRing *)DR_debugRing { return DRDebugRing.ringWindow.debugRing; }
@end
#endif
