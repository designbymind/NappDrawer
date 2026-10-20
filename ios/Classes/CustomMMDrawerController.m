/**
 * Module developed by Napp ApS
 * www.napp.dk
 * Mads Møller
 *
 * CustomMMDrawerController - PR from Azwan b. Amit
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */

#import "CustomMMDrawerController.h"
#import "MMDrawerController+Subclass.h"
#import "UIViewController+MMDrawerController.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

/*
 * MMDrawerController keeps centerContainerView private. Since NappDrawer ships
 * MMDrawerController with the module, exposing the existing getter locally is
 * safe and avoids modifying the upstream MMDrawerController source.
 */
@interface MMDrawerController (NappDrawerInternalAccess)
@property (nonatomic, strong, readonly) UIView *centerContainerView;
@property (nonatomic, strong, readonly) UIView *childControllerContainerView;
- (MMOpenDrawerGestureMode)possibleOpenGestureModesForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer withTouch:(UITouch *)touch;
- (MMCloseDrawerGestureMode)possibleCloseGestureModesForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer withTouch:(UITouch *)touch;
- (BOOL)isPointContainedWithinCenterViewContentRect:(CGPoint)point;
@property (nonatomic, assign, getter = isAnimatingDrawer) BOOL animatingDrawer;
- (void)updateShadowForCenterView;
- (void)setOpenSide:(MMDrawerSide)side;
- (void)resetDrawerVisualStateForDrawerSide:(MMDrawerSide)side;
- (void)updateDrawerVisualStateForDrawerSide:(MMDrawerSide)side percentVisible:(CGFloat)percentVisible;
- (NSTimeInterval)animationDurationForAnimationDistance:(CGFloat)distance;
- (void)setMaximumDrawerWidth:(CGFloat)width forSide:(MMDrawerSide)side animated:(BOOL)animated completion:(void (^)(BOOL))completion;
@end

extern NSTimeInterval const MMDrawerMinimumAnimationDuration;
extern CGFloat const MMDrawerDefaultShadowRadius;
extern CGFloat const MMDrawerDefaultShadowOpacity;

@interface NappDrawerCenterStyleView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, strong) UIView *borderView;
@end

@implementation NappDrawerCenterStyleView
- (void)layoutSubviews
{
  [super layoutSubviews];
  self.contentView.frame = self.bounds;
  self.borderView.frame = self.bounds;
  [self bringSubviewToFront:self.borderView];
}
@end

@interface NappDrawerSheetInteractionView : UIView
@property (nonatomic, assign) BOOL blocksAllTouches;
@property (nonatomic, assign) CGFloat edgeWidth;
@property (nonatomic, weak) UISheetPresentationController *sheetPresentationController;
@end

@implementation NappDrawerSheetInteractionView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  if (![super pointInside:point withEvent:event]) {
    return NO;
  }

  if (self.blocksAllTouches) {
    return YES;
  }

  UISheetPresentationController *sheet = self.sheetPresentationController;
  UISheetPresentationControllerDetentIdentifier largestUndimmedIdentifier =
      sheet.largestUndimmedDetentIdentifier;
  UISheetPresentationControllerDetentIdentifier selectedIdentifier =
      sheet.selectedDetentIdentifier;

  // A missing largest-undimmed identifier means every sheet detent is dimmed.
  // Treat unknown identifiers conservatively as dimmed as well. In either case,
  // the sheet keeps the touch and the drawer remains programmatic-only.
  if (!sheet || !largestUndimmedIdentifier || !selectedIdentifier) {
    return NO;
  }

  NSInteger selectedIndex = NSNotFound;
  NSInteger largestUndimmedIndex = NSNotFound;
  NSArray<UISheetPresentationControllerDetent *> *detents = sheet.detents;

  for (NSUInteger index = 0; index < detents.count; index++) {
    UISheetPresentationControllerDetentIdentifier identifier =
        detents[index].identifier;

    if ([identifier isEqualToString:selectedIdentifier]) {
      selectedIndex = (NSInteger)index;
    }

    if ([identifier isEqualToString:largestUndimmedIdentifier]) {
      largestUndimmedIndex = (NSInteger)index;
    }
  }

  BOOL sheetIsDimmed =
      selectedIndex == NSNotFound ||
      largestUndimmedIndex == NSNotFound ||
      selectedIndex > largestUndimmedIndex;

  if (sheetIsDimmed) {
    return NO;
  }

  // Keep the native sheet fully interactive while the drawer is closed, but
  // reserve standard edge-swipe zones for opening either drawer only while
  // the current sheet detent has no background dimming.
  CGFloat edgeWidth = MAX(self.edgeWidth, 0.0f);

  if (edgeWidth <= 0.0f) {
    return NO;
  }

  edgeWidth = MIN(edgeWidth, CGRectGetWidth(self.bounds) / 2.0f);
  return point.x <= edgeWidth || point.x >= CGRectGetWidth(self.bounds) - edgeWidth;
}

@end

@interface CustomMMDrawerController () <UIGestureRecognizerDelegate> {
  CADisplayLink *_slidingDisplayLink;
  MMDrawerSide _slidingSide;
  CGFloat _lastSlidingProgress;
  MMDrawerSide _lastSlidingEventSide;
  BOOL _hasLastSlidingProgress;
  __weak UISheetPresentationController *_attachedSheetPresentationController;
  __weak UIView *_attachedSheetContainerView;
  __weak UIView *_previousSheetSourceView;
  BOOL _didReplaceSheetSourceView;
  CGAffineTransform _sheetContainerBaseTransform;
  CGAffineTransform _lastAppliedSheetContainerTransform;
  BOOL _hasAppliedSheetContainerTransform;
  UIPanGestureRecognizer *_attachedSheetDrawerPanGesture;
  UITapGestureRecognizer *_attachedSheetDrawerTapGesture;
  NappDrawerSheetInteractionView *_attachedSheetInteractionShield;
  CGFloat _presentedSheetEdgeWidth;
  BOOL _isDirectlyDraggingDrawer;
  BOOL _isAnimatingAttachedSheetWithDrawer;
  NappDrawerCenterStyleView *_centerStyleView;
  UIView *_centerCornerMeasurementContainer;
  UIView *_centerCornerMeasurementView;
  BOOL _isAnimatingCenterBorder;
  CGFloat _centerStyleProgress;
  BOOL _hasConfiguredShadowDefaults;
  BOOL _isResizingDrawer;
  MMDrawerSide _resizingDrawerSide;
  BOOL _resizeStartedFullyOpen;
  CGFloat _lastSlidingDrawerWidth;
  CGFloat _lastSlidingCenterOffset;
  BOOL _lastSlidingResizing;
  CGFloat _pendingDrawerWidth;
  MMDrawerSide _pendingDrawerWidthSide;
  BOOL _pendingDrawerWidthAnimated;
  void (^_pendingDrawerWidthCompletion)(BOOL);
  BOOL _isSettlingGesture;
  BOOL _isHandlingDrawerTap;
  BOOL _gestureWasCancelled;
  BOOL _isStartingDrawerTransition;
  UIImpactFeedbackGenerator *_drawerHapticGenerator;
}

- (void)startSlidingTrackingForSide:(MMDrawerSide)side;
- (void)stopSlidingTracking;
- (void)finishSlidingTrackingForSide:(MMDrawerSide)side progress:(CGFloat)progress;
- (void)slidingDisplayLinkDidFire:(CADisplayLink *)displayLink;
- (void)emitSlidingProgressUsingPresentationLayer:(BOOL)usePresentationLayer force:(BOOL)force;
- (void)emitSlidingProgress:(CGFloat)progress side:(MMDrawerSide)side resizing:(BOOL)resizing drawerWidth:(CGFloat)drawerWidth centerOffset:(CGFloat)centerOffset force:(BOOL)force;
- (nullable UISheetPresentationController *)presentedSheetFromViewController:(UIViewController *)viewController;
- (nullable UISheetPresentationController *)discoverPresentedSheet;
- (void)synchronizeAttachedSheetWithCenterOffset:(CGFloat)centerOffset;
- (void)animateAttachedSheetToCenterOffset:(CGFloat)centerOffset
                                  animated:(BOOL)animated
                                  duration:(NSTimeInterval)duration
                          animationOptions:(UIViewAnimationOptions)options;
- (void)installDrawerGesturesOnAttachedSheetContainer;
- (void)restoreDrawerGestures;
- (void)setAttachedSheetInteractionBlocked:(BOOL)blocked;
- (void)updateAttachedSheetInteractionForCurrentDrawerState;
- (void)updateCenterStyle;
- (CGFloat)alignedConcentricCornerRadius;
- (void)applyConfiguredShadow;
- (void)applyPendingDrawerWidth;
- (UIImpactFeedbackGenerator *)drawerHapticGenerator;
- (void)beginDrawerTransition:(NSString *)state side:(MMDrawerSide)side source:(NSString *)source;
- (void)updateCenterBorderForProgress:(CGFloat)progress;
- (void)animateCenterBorderToProgress:(CGFloat)progress animated:(BOOL)animated
                            duration:(NSTimeInterval)duration
                    animationOptions:(UIViewAnimationOptions)options;

@end

@implementation CustomMMDrawerController

@synthesize presentedSheetEdgeWidth = _presentedSheetEdgeWidth;

- (id)initWithCenterViewController:(UIViewController *)centerViewController
          leftDrawerViewController:(UIViewController *)leftDrawerViewController
         rightDrawerViewController:(UIViewController *)rightDrawerViewController
{
  self = [super initWithCenterViewController:centerViewController
                    leftDrawerViewController:leftDrawerViewController
                   rightDrawerViewController:rightDrawerViewController];

  if (self) {
    _openDrawerBezelWidth = 20.0f;
    _closeDrawerBezelWidth = 20.0f;
    _animationMinScale = 0.90f;
    _animationScaleFade = NO;
    _presentedSheetEdgeWidth = 32.0f;
    _centerCornerMode = @"none";
    _centerCornerRadius = 32.0f;
    _centerBorderColor = UIColor.blackColor;
    _centerBorderOpacity = 1.0f;
    _shadowRadius = MMDrawerDefaultShadowRadius;
    _shadowOpacity = MMDrawerDefaultShadowOpacity;
    _shadowColor = UIColor.blackColor;
    _hasConfiguredShadowDefaults = YES;
    _hapticFeedback = @"none";
    _hapticStyle = @"light";
    [self updateShadowForCenterView];
  }

  return self;
}

#pragma mark - Center appearance

- (void)configureInitialDrawerSide:(MMDrawerSide)side
{
  UIViewController *selectedController = side == MMDrawerSideLeft
      ? self.leftDrawerViewController : self.rightDrawerViewController;
  if (side != MMDrawerSideNone && !selectedController) {
    NSLog(@"[WARN] NappDrawer initialDrawerSide has no matching window; starting at center");
    side = MMDrawerSideNone;
  }

  [UIView performWithoutAnimation:^{
    [self setOpenSide:side];
    [self resetDrawerVisualStateForDrawerSide:MMDrawerSideLeft];
    [self resetDrawerVisualStateForDrawerSide:MMDrawerSideRight];
    self.leftDrawerViewController.view.hidden = side != MMDrawerSideLeft;
    self.rightDrawerViewController.view.hidden = side != MMDrawerSideRight;
    CGFloat offset = side == MMDrawerSideLeft ? self.maximumLeftDrawerWidth :
        (side == MMDrawerSideRight ? -self.maximumRightDrawerWidth : 0.0f);
    CGRect centerFrame = self.centerContainerView.frame;
    centerFrame.origin.x = offset;
    self.centerContainerView.frame = centerFrame;
    if (side != MMDrawerSideNone) {
      selectedController.view.frame = selectedController.mm_visibleDrawerFrame;
      [self updateDrawerVisualStateForDrawerSide:side percentVisible:1.0f];
    }
    [self updateCenterBorderForProgress:side == MMDrawerSideNone ? 0.0f : 1.0f];
    [self updateCenterStyle];
    if (_attachedSheetPresentationController) {
      [self synchronizeAttachedSheetWithCenterOffset:offset];
      [self updateAttachedSheetInteractionForCurrentDrawerState];
    }
  }];
}

- (void)updateDrawerVisualStateForDrawerSide:(MMDrawerSide)side percentVisible:(CGFloat)percentVisible
{
  MMDrawerControllerDrawerVisualStateBlock override = nil;
  if (side == MMDrawerSideLeft) {
    override = self.leftDrawerVisualStateOverride;
  } else if (side == MMDrawerSideRight) {
    override = self.rightDrawerVisualStateOverride;
  }
  if (override) {
    override(self, side, percentVisible);
  } else {
    // Keep the global animationMode, including the original native default,
    // for any side whose optional override has not been supplied.
    [super updateDrawerVisualStateForDrawerSide:side percentVisible:percentVisible];
  }
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self updateCenterStyle];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self updateCenterStyle];
}

- (void)setCenterCornerMode:(NSString *)value
{
  _centerCornerMode = [value copy];
  [self updateCenterStyle];
}

- (void)setCenterCornerRadius:(CGFloat)value
{
  _centerCornerRadius = MAX(0.0f, value);
  [self updateCenterStyle];
}

- (void)setCenterBorderWidth:(CGFloat)value
{
  _centerBorderWidth = MAX(0.0f, value);
  [self updateCenterStyle];
}

- (void)setCenterBorderColor:(UIColor *)value
{
  _centerBorderColor = value ?: UIColor.blackColor;
  [self updateCenterStyle];
}

- (void)setCenterBorderOpacity:(CGFloat)value
{
  _centerBorderOpacity = MIN(MAX(value, 0.0f), 1.0f);
  [self updateCenterBorderForProgress:_centerStyleProgress];
}

- (void)setCenterBorderFollowsSliding:(BOOL)value
{
  _centerBorderFollowsSliding = value;
  [self updateCenterBorderForProgress:_centerStyleProgress];
}

- (void)setShadowRadius:(CGFloat)value
{
  _shadowRadius = MAX(0.0f, value);
  [self updateShadowForCenterView];
}

- (void)setAnimationMinScale:(CGFloat)value
{
  _animationMinScale = isfinite(value) ? MIN(MAX(value, 0.0f), 1.0f) : 0.90f;
}

- (void)setShadowColor:(UIColor *)value
{
  _shadowColor = value ?: UIColor.blackColor;
  [self updateShadowForCenterView];
}

- (void)setShadowOpacity:(CGFloat)value
{
  _shadowOpacity = MIN(MAX(value, 0.0f), 1.0f);
  [self updateShadowForCenterView];
}

- (void)applyConfiguredShadow
{
  // Superclass initialization can call our override before these defaults exist.
  if (!_hasConfiguredShadowDefaults) {
    return;
  }
  CALayer *layer = self.centerContainerView.layer;
  layer.shadowRadius = self.showsShadow ? _shadowRadius : 0.0f;
  layer.shadowOpacity = self.showsShadow ? _shadowOpacity : 0.0f;
  layer.shadowColor = _shadowColor.CGColor;
}

- (CGFloat)alignedConcentricCornerRadius
{
  if (@available(iOS 26.0, *)) {
    UIView *parent = self.childControllerContainerView;
    if (!parent.window || CGRectIsEmpty(parent.bounds)) {
      // Creation-time styling may precede window attachment. Retry at layout;
      // never sample the displaced center when initialDrawerSide is left/right.
      return _centerCornerRadius;
    }
    if (!_centerCornerMeasurementContainer) {
      // Mirror centerContainerView -> clipping view, but at the closed center's
      // geometry. No content is moved and no drawer state/lifecycle is changed.
      _centerCornerMeasurementContainer = [[UIView alloc] initWithFrame:parent.bounds];
      _centerCornerMeasurementContainer.alpha = 0.0f;
      _centerCornerMeasurementContainer.userInteractionEnabled = NO;
      _centerCornerMeasurementContainer.accessibilityElementsHidden = YES;
      _centerCornerMeasurementView = [[UIView alloc] initWithFrame:_centerCornerMeasurementContainer.bounds];
      _centerCornerMeasurementView.userInteractionEnabled = NO;
      _centerCornerMeasurementView.cornerConfiguration =
          [UICornerConfiguration configurationWithUniformRadius:[UICornerRadius containerConcentricRadius]];
      [_centerCornerMeasurementContainer addSubview:_centerCornerMeasurementView];
    }
    [UIView performWithoutAnimation:^{
      if (_centerCornerMeasurementContainer.superview != parent) {
        [parent insertSubview:_centerCornerMeasurementContainer atIndex:0];
      }
      _centerCornerMeasurementContainer.frame = parent.bounds;
      _centerCornerMeasurementView.frame = _centerCornerMeasurementContainer.bounds;
      [_centerCornerMeasurementContainer layoutIfNeeded];
      [_centerCornerMeasurementView layoutIfNeeded];
    }];
    CGFloat radius = [_centerCornerMeasurementView effectiveRadiusForCorner:UIRectCornerAllCorners];
    // A rectangular/unresolved container can legitimately report zero. Keep
    // opted-in rounding using the configured fallback rather than flattening.
    return isfinite(radius) && radius > 0.0f ? radius : _centerCornerRadius;
  }
  return _centerCornerRadius;
}

- (void)updateCenterStyle
{
  if (!self.isViewLoaded) {
    return;
  }

  UIView *container = self.centerContainerView;
  UIView *content = self.centerViewController.view;
  BOOL rounded = _centerCornerMode != nil && ![_centerCornerMode isEqualToString:@"none"];
  BOOL concentric = rounded && [_centerCornerMode isEqualToString:@"concentric"];
  if (!concentric) {
    [_centerCornerMeasurementContainer removeFromSuperview];
    _centerCornerMeasurementContainer = nil;
    _centerCornerMeasurementView = nil;
  }

  if (!rounded && _centerBorderWidth <= 0.0f) {
    if (_centerStyleView) {
      UIView *previousContent = _centerStyleView.contentView;
      if (previousContent == content && previousContent.superview == _centerStyleView) {
        [container addSubview:previousContent];
        previousContent.frame = container.bounds;
      }
      [_centerStyleView removeFromSuperview];
      _centerStyleView = nil;
      [super updateShadowForCenterView];
      [self applyConfiguredShadow];
    }
    return;
  }

  if (!_centerStyleView) {
    _centerStyleView = [[NappDrawerCenterStyleView alloc] initWithFrame:container.bounds];
    _centerStyleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _centerStyleView.clipsToBounds = YES;
    _centerStyleView.borderView = [[UIView alloc] initWithFrame:_centerStyleView.bounds];
    _centerStyleView.borderView.userInteractionEnabled = NO;
    _centerStyleView.borderView.isAccessibilityElement = NO;
    [_centerStyleView addSubview:_centerStyleView.borderView];
    [container addSubview:_centerStyleView];
  }

  if (_centerStyleView.contentView != content || content.superview != _centerStyleView) {
    if (_centerStyleView.contentView != content) {
      [_centerStyleView.contentView removeFromSuperview];
    }
    _centerStyleView.contentView = content;
    [_centerStyleView insertSubview:content atIndex:0];
  }
  _centerStyleView.frame = container.bounds;
  content.frame = _centerStyleView.bounds;
  _centerStyleView.borderView.frame = _centerStyleView.bounds;

  CGFloat radius = rounded ? _centerCornerRadius : 0.0f;
  if (@available(iOS 26.0, *)) {
    if (concentric) {
      radius = [self alignedConcentricCornerRadius];
    }
    // Resolve concentric geometry on the stationary measurement view only.
    // The real center and border must not re-resolve as they move offscreen.
    UICornerConfiguration *configuration =
        [UICornerConfiguration configurationWithUniformRadius:[UICornerRadius fixedRadius:radius]];
    if (![_centerStyleView.cornerConfiguration isEqual:configuration]) {
      [UIView performWithoutAnimation:^{
        _centerStyleView.cornerConfiguration = configuration;
        _centerStyleView.borderView.cornerConfiguration = configuration;
      }];
    }
  } else {
    _centerStyleView.layer.cornerRadius = radius;
    _centerStyleView.borderView.layer.cornerRadius = radius;
  }
  _centerStyleView.layer.cornerCurve = kCACornerCurveContinuous;
  _centerStyleView.borderView.layer.cornerCurve = kCACornerCurveContinuous;
  _centerStyleView.borderView.layer.borderWidth = _centerBorderWidth;
  _centerStyleView.borderView.layer.borderColor = _centerBorderColor.CGColor;
  if (!_isAnimatingCenterBorder) {
    [self updateCenterBorderForProgress:_centerStyleProgress];
  }

  // Content clips inside the wrapper; the existing outer shadow stays visible.
  container.layer.masksToBounds = NO;
  if (self.showsShadow) {
    container.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:container.bounds
                                                        cornerRadius:radius].CGPath;
  }
}

- (void)updateShadowForCenterView
{
  [super updateShadowForCenterView];
  [self applyConfiguredShadow];
  [self updateCenterStyle];
}

- (CGFloat)resolvedCenterCornerRadius
{
  if (!self.isViewLoaded || !self.view.window ||
      [_centerCornerMode isEqualToString:@"none"] || !_centerCornerMode) {
    return 0.0f;
  }

  // Resolve pending layout before asking UIKit for the current geometry.
  [self.view layoutIfNeeded];
  [self updateCenterStyle];
  [_centerStyleView layoutIfNeeded];
  if (!_centerStyleView) {
    return 0.0f;
  }
  if (@available(iOS 26.0, *)) {
    return [_centerStyleView effectiveRadiusForCorner:UIRectCornerAllCorners];
  }
  return _centerStyleView.layer.cornerRadius;
}

- (void)updateCenterBorderForProgress:(CGFloat)progress
{
  _centerStyleProgress = MIN(MAX(progress, 0.0f), 1.0f);
  _centerStyleView.borderView.alpha = _centerBorderOpacity *
      (_centerBorderFollowsSliding ? _centerStyleProgress : 1.0f);
}

- (void)animateCenterBorderToProgress:(CGFloat)progress animated:(BOOL)animated
                            duration:(NSTimeInterval)duration
                    animationOptions:(UIViewAnimationOptions)options
{
  if (!_centerBorderFollowsSliding || !_centerStyleView) {
    return;
  }
  _isAnimatingCenterBorder = animated;
  [UIView animateWithDuration:animated ? duration : 0.0f delay:0.0 options:options
                   animations:^{ [self updateCenterBorderForProgress:progress]; }
                   completion:nil];
}

#pragma mark - Existing open / close callbacks

- (void)setHapticStyle:(NSString *)style
{
  _hapticStyle = [style copy];
  _drawerHapticGenerator = nil;
}

- (UIImpactFeedbackGenerator *)drawerHapticGenerator
{
  if (!_drawerHapticGenerator) {
    UIImpactFeedbackStyle style = UIImpactFeedbackStyleLight;
    if ([_hapticStyle isEqualToString:@"medium"]) style = UIImpactFeedbackStyleMedium;
    else if ([_hapticStyle isEqualToString:@"heavy"]) style = UIImpactFeedbackStyleHeavy;
    else if ([_hapticStyle isEqualToString:@"soft"]) style = UIImpactFeedbackStyleSoft;
    else if ([_hapticStyle isEqualToString:@"rigid"]) style = UIImpactFeedbackStyleRigid;
    _drawerHapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
  }
  return _drawerHapticGenerator;
}

- (void)beginDrawerTransition:(NSString *)state side:(MMDrawerSide)side source:(NSString *)source
{
  _isStartingDrawerTransition = YES;
  BOOL feedbackEnabled = [_hapticFeedback isEqualToString:@"all"] ||
      ([_hapticFeedback isEqualToString:@"gesture"] && _isSettlingGesture);
  if (feedbackEnabled && !_gestureWasCancelled) {
    [[self drawerHapticGenerator] impactOccurred];
  }
  if (self.transitionCallback) {
    self.transitionCallback(state, side, source);
  }
  _isStartingDrawerTransition = NO;
}

- (void)tapGestureCallback:(UITapGestureRecognizer *)tapGesture
{
  _isHandlingDrawerTap = YES;
  [super tapGestureCallback:tapGesture];
  _isHandlingDrawerTap = NO;
}

- (void)openDrawerSide:(MMDrawerSide)drawerSide
              animated:(BOOL)animated
            completion:(void (^)(BOOL finished))completion
{
  [super openDrawerSide:drawerSide
               animated:animated
             completion:^(BOOL finished) {
               if (finished && self->_callback) {
                 self->_callback(@"open");
               }

               if (completion) {
                 completion(finished);
               }
             }];
}

- (void)closeDrawerAnimated:(BOOL)animated
                 completion:(void (^)(BOOL finished))completion
{
  [super closeDrawerAnimated:animated
                  completion:^(BOOL finished) {
                    if (finished && self->_callback) {
                      self->_callback(@"close");
                    }

                    if (completion) {
                      completion(finished);
                    }
                  }];
}

- (void)setWindowAppearanceCallback:(void (^)(NSString *))callback
{
  _callback = [callback copy];

  __weak __typeof__(self) weakSelf = self;

  [super setGestureCompletionBlock:^(MMDrawerController *controller, UIGestureRecognizer *gesture) {
    __typeof__(self) strongSelf = weakSelf;

    if (!strongSelf || !strongSelf->_callback) {
      return;
    }

    if (controller.openSide == MMDrawerSideNone) {
      strongSelf->_callback(@"close");
    } else {
      strongSelf->_callback(@"open");
    }
  }];
}

#pragma mark - Sliding callback

- (void)setSlidingCallback:(DrawerSlidingChangeBlock)callback
{
  _slidingCallback = [callback copy];

  if (!_slidingCallback && !_centerBorderFollowsSliding) {
    [self stopSlidingTracking];
  }
}

#pragma mark - Continuous sliding tracking

- (void)startSlidingTrackingForSide:(MMDrawerSide)side
{
  CGFloat centerOffset = CGRectGetMinX(self.centerContainerView.frame);

  // Auto-discovery only occurs while the center is closed. A sheet presented
  // from an already-open side drawer must remain independent.
  if (_followsPresentedSheet &&
      !_attachedSheetPresentationController &&
      self.openSide == MMDrawerSideNone &&
      fabs(centerOffset) < 0.5f) {
    [self attachPresentedSheet];
  }

  if (_attachedSheetPresentationController) {
    [self setAttachedSheetInteractionBlocked:YES];
  }

  if (!_slidingCallback && !_centerBorderFollowsSliding) {
    return;
  }

  if (side != MMDrawerSideNone) {
    _slidingSide = side;
  }

  if (_slidingDisplayLink == nil) {
    _slidingDisplayLink = [CADisplayLink displayLinkWithTarget:self
                                                     selector:@selector(slidingDisplayLinkDidFire:)];

    // Common modes keeps updates flowing during UIKit gesture tracking.
    [_slidingDisplayLink addToRunLoop:[NSRunLoop mainRunLoop]
                              forMode:NSRunLoopCommonModes];
  }

  // A finishing drag starts from its current model position. Sampling a stale
  // presentation frame here would briefly pull the border/sheet backwards.
  [self emitSlidingProgressUsingPresentationLayer:self.isAnimatingDrawer force:NO];
}

#pragma mark - Native sheet integration

- (UISheetPresentationController *)presentedSheetFromViewController:(UIViewController *)viewController
{
  if (!viewController) {
    return nil;
  }

  UIViewController *presentedViewController = viewController.presentedViewController;

  if (presentedViewController) {
    UISheetPresentationController *nestedSheet =
        [self presentedSheetFromViewController:presentedViewController];

    if (nestedSheet) {
      return nestedSheet;
    }

    UIPresentationController *presentationController =
        presentedViewController.presentationController;

    if ([presentationController isKindOfClass:[UISheetPresentationController class]] &&
        presentationController.containerView.window) {
      return (UISheetPresentationController *)presentationController;
    }
  }

  for (UIViewController *childViewController in
       [viewController.childViewControllers reverseObjectEnumerator]) {
    UISheetPresentationController *childSheet =
        [self presentedSheetFromViewController:childViewController];

    if (childSheet) {
      return childSheet;
    }
  }

  return nil;
}

- (UISheetPresentationController *)discoverPresentedSheet
{
  if (@available(iOS 15.0, *)) {
    UIViewController *rootViewController = self.view.window.rootViewController;
    UISheetPresentationController *sheet =
        [self presentedSheetFromViewController:rootViewController];

    if (!sheet && self.parentViewController != rootViewController) {
      sheet = [self presentedSheetFromViewController:self.parentViewController];
    }

    return sheet;
  }

  return nil;
}

- (BOOL)attachPresentedSheet
{
  if (@available(iOS 15.0, *)) {
    UISheetPresentationController *sheet = [self discoverPresentedSheet];
    UIView *centerView = self.centerContainerView;

    if (!sheet || !centerView) {
      return NO;
    }

    BOOL supportsSourceView =
        [sheet respondsToSelector:@selector(setSourceView:)];

    if (_attachedSheetPresentationController == sheet &&
        (!supportsSourceView || sheet.sourceView == centerView)) {
      [self installDrawerGesturesOnAttachedSheetContainer];
      [self updateAttachedSheetInteractionForCurrentDrawerState];
      return YES;
    }

    [self detachPresentedSheet];

    _attachedSheetPresentationController = sheet;
    _attachedSheetContainerView = sheet.containerView;
    _previousSheetSourceView = supportsSourceView ? sheet.sourceView : nil;
    _didReplaceSheetSourceView =
        supportsSourceView && sheet.sourceView != centerView;
    _sheetContainerBaseTransform = sheet.containerView.transform;
    _lastAppliedSheetContainerTransform = CGAffineTransformIdentity;
    _hasAppliedSheetContainerTransform = NO;
    if (supportsSourceView) {
      sheet.sourceView = centerView;
    }

    [self installDrawerGesturesOnAttachedSheetContainer];
    [self synchronizeAttachedSheetWithCenterOffset:CGRectGetMinX(centerView.frame)];
    [self updateAttachedSheetInteractionForCurrentDrawerState];

    return YES;
  }

  return NO;
}

- (void)detachPresentedSheet
{
  _isAnimatingAttachedSheetWithDrawer = NO;
  [self setAttachedSheetInteractionBlocked:NO];
  [self restoreDrawerGestures];
  [_attachedSheetInteractionShield removeFromSuperview];
  _attachedSheetInteractionShield = nil;

  if (@available(iOS 15.0, *)) {
    UISheetPresentationController *sheet = _attachedSheetPresentationController;
    UIView *containerView = _attachedSheetContainerView;

    if (sheet &&
        [sheet respondsToSelector:@selector(setSourceView:)] &&
        _didReplaceSheetSourceView &&
        sheet.sourceView == self.centerContainerView) {
      sheet.sourceView = _previousSheetSourceView;
    }

    if (containerView &&
        _hasAppliedSheetContainerTransform &&
        CGAffineTransformEqualToTransform(containerView.transform,
                                          _lastAppliedSheetContainerTransform)) {
      containerView.transform = _sheetContainerBaseTransform;
    }
  }

  _attachedSheetPresentationController = nil;
  _attachedSheetContainerView = nil;
  _previousSheetSourceView = nil;
  _didReplaceSheetSourceView = NO;
  _sheetContainerBaseTransform = CGAffineTransformIdentity;
  _lastAppliedSheetContainerTransform = CGAffineTransformIdentity;
  _hasAppliedSheetContainerTransform = NO;
}

- (BOOL)isAnySheetOpen
{
  return [self discoverPresentedSheet] != nil;
}

- (void)installDrawerGesturesOnAttachedSheetContainer
{
  UIView *containerView = _attachedSheetContainerView;

  if (!containerView) {
    return;
  }

  if (!_attachedSheetInteractionShield) {
    _attachedSheetInteractionShield =
        [[NappDrawerSheetInteractionView alloc] initWithFrame:containerView.bounds];
    _attachedSheetInteractionShield.backgroundColor = UIColor.clearColor;
    _attachedSheetInteractionShield.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _attachedSheetInteractionShield.userInteractionEnabled = YES;
    _attachedSheetInteractionShield.isAccessibilityElement = NO;
    _attachedSheetInteractionShield.accessibilityElementsHidden = YES;
    _attachedSheetInteractionShield.blocksAllTouches = NO;
    _attachedSheetInteractionShield.edgeWidth = _presentedSheetEdgeWidth;
    _attachedSheetInteractionShield.sheetPresentationController =
        _attachedSheetPresentationController;
    [containerView addSubview:_attachedSheetInteractionShield];
  }

  _attachedSheetInteractionShield.sheetPresentationController =
      _attachedSheetPresentationController;
  _attachedSheetInteractionShield.edgeWidth = _presentedSheetEdgeWidth;

  if (!_attachedSheetDrawerPanGesture) {
    _attachedSheetDrawerPanGesture =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(panGestureCallback:)];
    _attachedSheetDrawerPanGesture.delegate = self;
    [_attachedSheetInteractionShield
        addGestureRecognizer:_attachedSheetDrawerPanGesture];
  }

  if (!_attachedSheetDrawerTapGesture) {
    _attachedSheetDrawerTapGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(tapGestureCallback:)];
    _attachedSheetDrawerTapGesture.delegate = self;
    [_attachedSheetInteractionShield
        addGestureRecognizer:_attachedSheetDrawerTapGesture];
  }

  [containerView bringSubviewToFront:_attachedSheetInteractionShield];
}

- (void)restoreDrawerGestures
{
  if (_attachedSheetDrawerPanGesture) {
    [_attachedSheetInteractionShield
        removeGestureRecognizer:_attachedSheetDrawerPanGesture];
  }

  if (_attachedSheetDrawerTapGesture) {
    [_attachedSheetInteractionShield
        removeGestureRecognizer:_attachedSheetDrawerTapGesture];
  }

  _attachedSheetDrawerPanGesture = nil;
  _attachedSheetDrawerTapGesture = nil;
}

- (void)setAttachedSheetInteractionBlocked:(BOOL)blocked
{
  UIView *containerView = _attachedSheetContainerView;

  if (!containerView || !_attachedSheetInteractionShield) {
    return;
  }

  _attachedSheetInteractionShield.blocksAllTouches = blocked;
  [containerView bringSubviewToFront:_attachedSheetInteractionShield];
}

- (void)setPresentedSheetEdgeWidth:(CGFloat)presentedSheetEdgeWidth
{
  _presentedSheetEdgeWidth = MAX(presentedSheetEdgeWidth, 0.0f);
  _attachedSheetInteractionShield.edgeWidth = _presentedSheetEdgeWidth;
}

- (void)updateAttachedSheetInteractionForCurrentDrawerState
{
  CGFloat centerOffset = CGRectGetMinX(self.centerContainerView.frame);
  BOOL drawerIsVisible =
      self.openSide != MMDrawerSideNone || fabs(centerOffset) >= 0.5f;
  [self setAttachedSheetInteractionBlocked:drawerIsVisible];
}

- (void)synchronizeAttachedSheetWithCenterOffset:(CGFloat)centerOffset
{
  if (@available(iOS 15.0, *)) {
    UISheetPresentationController *sheet = _attachedSheetPresentationController;
    UIView *containerView = _attachedSheetContainerView;

    if (!sheet || !containerView || !containerView.window) {
      [self detachPresentedSheet];
      return;
    }

    CGAffineTransform currentTransform = containerView.transform;

    // Preserve a UIKit transform that changed independently between updates.
    if (!_hasAppliedSheetContainerTransform ||
        !CGAffineTransformEqualToTransform(currentTransform,
                                           _lastAppliedSheetContainerTransform)) {
      _sheetContainerBaseTransform = currentTransform;
    }

    CGAffineTransform synchronizedTransform = _sheetContainerBaseTransform;
    synchronizedTransform.tx += centerOffset;

    if (!CGAffineTransformEqualToTransform(currentTransform,
                                           synchronizedTransform)) {
      containerView.transform = synchronizedTransform;
    }

    _lastAppliedSheetContainerTransform = synchronizedTransform;
    _hasAppliedSheetContainerTransform = YES;
  }
}

- (void)animateAttachedSheetToCenterOffset:(CGFloat)centerOffset
                                  animated:(BOOL)animated
                                  duration:(NSTimeInterval)duration
                          animationOptions:(UIViewAnimationOptions)options
{
  UIView *containerView = _attachedSheetContainerView;

  if (!containerView || !containerView.window) {
    _isAnimatingAttachedSheetWithDrawer = NO;
    return;
  }

  if (!animated) {
    _isAnimatingAttachedSheetWithDrawer = NO;
    [self synchronizeAttachedSheetWithCenterOffset:centerOffset];
    return;
  }

  _isAnimatingAttachedSheetWithDrawer = YES;

  [UIView animateWithDuration:duration
                        delay:0.0
                      options:options
                   animations:^{
                     [self synchronizeAttachedSheetWithCenterOffset:centerOffset];
                   }
                   completion:nil];
}

- (void)setFollowsPresentedSheet:(BOOL)followsPresentedSheet
{
  _followsPresentedSheet = followsPresentedSheet;

  if (_followsPresentedSheet) {
    [self attachPresentedSheet];
  } else {
    [self detachPresentedSheet];
  }
}

- (void)stopSlidingTracking
{
  if (_slidingDisplayLink) {
    [_slidingDisplayLink invalidate];
    _slidingDisplayLink = nil;
  }
}

- (void)finishSlidingTrackingForSide:(MMDrawerSide)side
                           progress:(CGFloat)progress
{
  [self updateCenterBorderForProgress:progress];
  if (side == MMDrawerSideNone) {
    side = _slidingSide;
  }

  if (_slidingCallback && side != MMDrawerSideNone) {
    CGFloat width = side == MMDrawerSideLeft ? self.maximumLeftDrawerWidth : self.maximumRightDrawerWidth;
    [self emitSlidingProgress:progress side:side resizing:NO drawerWidth:width
                 centerOffset:CGRectGetMinX(self.centerContainerView.frame) force:YES];
  }

  [self synchronizeAttachedSheetWithCenterOffset:
            CGRectGetMinX(self.centerContainerView.frame)];
  [self setAttachedSheetInteractionBlocked:progress > 0.0001f];

  [self stopSlidingTracking];

  _slidingSide = MMDrawerSideNone;
  _hasLastSlidingProgress = NO;
  _lastSlidingEventSide = MMDrawerSideNone;
  [self applyPendingDrawerWidth];
}

- (void)slidingDisplayLinkDidFire:(CADisplayLink *)displayLink
{
  [self emitSlidingProgressUsingPresentationLayer:YES force:NO];
}

- (void)emitSlidingProgressUsingPresentationLayer:(BOOL)usePresentationLayer
                                            force:(BOOL)force
{
  UIView *centerContainerView = self.centerContainerView;

  if (!centerContainerView) {
    return;
  }

  CALayer *layer = centerContainerView.layer;

  if (usePresentationLayer) {
    CALayer *presentationLayer = (CALayer *)layer.presentationLayer;

    if (presentationLayer) {
      layer = presentationLayer;
    }
  }

  CGRect frame = layer.frame;
  CGFloat originX = CGRectGetMinX(frame);

  BOOL shouldSynchronizeSheet =
      !usePresentationLayer ||
      (!_isDirectlyDraggingDrawer && !_isAnimatingAttachedSheetWithDrawer);

  if (shouldSynchronizeSheet) {
    [self synchronizeAttachedSheetWithCenterOffset:originX];
  }

  if (!_slidingCallback && !_centerBorderFollowsSliding) {
    return;
  }

  MMDrawerSide side = _slidingSide;
  CGFloat progress = 0.0f;

  if (originX > 0.0f && self.maximumLeftDrawerWidth > 0.0f) {
    side = MMDrawerSideLeft;
    progress = originX / self.maximumLeftDrawerWidth;
  } else if (originX < 0.0f && self.maximumRightDrawerWidth > 0.0f) {
    side = MMDrawerSideRight;
    progress = fabs(originX) / self.maximumRightDrawerWidth;
  } else {
    // At exactly zero we retain the currently tracked side so the final
    // closing event can still report left/right instead of "none".
    progress = 0.0f;

    if (side == MMDrawerSideNone && self.openSide != MMDrawerSideNone) {
      side = self.openSide;
    }
  }

  BOOL resizing = _isResizingDrawer && side == _resizingDrawerSide;
  CGFloat drawerWidth = side == MMDrawerSideLeft ? self.maximumLeftDrawerWidth : self.maximumRightDrawerWidth;
  if (resizing) {
    UIViewController *sideController = side == MMDrawerSideLeft ? self.leftDrawerViewController : self.rightDrawerViewController;
    CALayer *sideLayer = sideController.view.layer;
    if (usePresentationLayer && sideLayer.presentationLayer) {
      sideLayer = sideLayer.presentationLayer;
    }
    drawerWidth = CGRectGetWidth(sideLayer.bounds);
    // The width changes, not the open fraction. The border stays fully visible.
    progress = _resizeStartedFullyOpen ? 1.0f : (drawerWidth > 0.0f ? fabs(originX) / drawerWidth : 0.0f);
  }

  if (!usePresentationLayer || (!_isDirectlyDraggingDrawer && !_isAnimatingCenterBorder)) {
    [self updateCenterBorderForProgress:progress];
  }

  if (side == MMDrawerSideNone) {
    return;
  }

  _slidingSide = side;

  // shouldStretchDrawer can make MMDrawerController exceed 1.0.
  // The Titanium API intentionally remains normalized.
  progress = MIN(MAX(progress, 0.0f), 1.0f);

  [self emitSlidingProgress:progress side:side resizing:resizing drawerWidth:drawerWidth centerOffset:originX force:force];
}

- (void)emitSlidingProgress:(CGFloat)progress
                       side:(MMDrawerSide)side
                   resizing:(BOOL)resizing
                drawerWidth:(CGFloat)drawerWidth
               centerOffset:(CGFloat)centerOffset
                      force:(BOOL)force
{
  if (!_slidingCallback || side == MMDrawerSideNone) {
    return;
  }

  progress = MIN(MAX(progress, 0.0f), 1.0f);

  // Avoid sending duplicate bridge events when the presentation layer has not
  // changed between display-link callbacks.
  BOOL changed =
      !_hasLastSlidingProgress ||
      _lastSlidingEventSide != side ||
      fabs(progress - _lastSlidingProgress) > 0.0001f ||
      _lastSlidingResizing != resizing ||
      fabs(drawerWidth - _lastSlidingDrawerWidth) > 0.0001f ||
      fabs(centerOffset - _lastSlidingCenterOffset) > 0.0001f;

  if (force || changed) {
    _slidingCallback(progress, side, resizing, drawerWidth, centerOffset);

    _lastSlidingProgress = progress;
    _lastSlidingEventSide = side;
    _hasLastSlidingProgress = YES;
    _lastSlidingResizing = resizing;
    _lastSlidingDrawerWidth = drawerWidth;
    _lastSlidingCenterOffset = centerOffset;
  }
}

#pragma mark - Gesture tracking

- (void)setOpenDrawerBezelWidth:(CGFloat)width
{
  _openDrawerBezelWidth = isfinite(width) ? MAX(width, 0.0f) : 20.0f;
}

- (void)setCloseDrawerBezelWidth:(CGFloat)width
{
  _closeDrawerBezelWidth = isfinite(width) ? MAX(width, 0.0f) : 20.0f;
}

- (MMCloseDrawerGestureMode)possibleCloseGestureModesForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
                                                              withTouch:(UITouch *)touch
{
  MMCloseDrawerGestureMode modes = [super possibleCloseGestureModesForGestureRecognizer:gestureRecognizer withTouch:touch];
  // Keep tap, navigation, drawer-content, and custom gesture eligibility intact.
  modes &= ~MMCloseDrawerGestureModeBezelPanningCenterView;
  if (![gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class] ||
      self.closeDrawerBezelWidth <= 0.0f || self.openSide == MMDrawerSideNone) {
    return modes;
  }
  CGPoint point = [touch locationInView:self.childControllerContainerView];
  if (![self isPointContainedWithinCenterViewContentRect:point]) {
    return modes;
  }
  CGRect bounds = self.childControllerContainerView.bounds;
  CGFloat width = MIN(self.closeDrawerBezelWidth, CGRectGetWidth(bounds));
  CGRect bezel, remainder;
  // Preserve the existing screen-edge mapping: right edge closes the left drawer.
  CGRectEdge edge = self.openSide == MMDrawerSideLeft ? CGRectMaxXEdge : CGRectMinXEdge;
  CGRectDivide(bounds, &bezel, &remainder, width, edge);
  if (CGRectContainsPoint(bezel, point)) {
    modes |= MMCloseDrawerGestureModeBezelPanningCenterView;
  }
  return modes;
}

- (MMOpenDrawerGestureMode)possibleOpenGestureModesForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
                                                            withTouch:(UITouch *)touch
{
  MMOpenDrawerGestureMode modes = [super possibleOpenGestureModesForGestureRecognizer:gestureRecognizer withTouch:touch];
  // Replace only the opening bezel bit, independently of the closing width.
  modes &= ~MMOpenDrawerGestureModeBezelPanningCenterView;
  if (![gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class] || self.openDrawerBezelWidth <= 0.0f) {
    return modes;
  }

  CGPoint point = [touch locationInView:self.childControllerContainerView];
  if (![self isPointContainedWithinCenterViewContentRect:point]) {
    return modes;
  }
  CGRect bounds = self.childControllerContainerView.bounds;
  CGFloat width = MIN(self.openDrawerBezelWidth, CGRectGetWidth(bounds));
  CGRect leftBezel, rightBezel, remainder;
  CGRectDivide(bounds, &leftBezel, &remainder, width, CGRectMinXEdge);
  CGRectDivide(bounds, &rightBezel, &remainder, width, CGRectMaxXEdge);
  if ((self.leftDrawerViewController && CGRectContainsPoint(leftBezel, point)) ||
      (self.rightDrawerViewController && CGRectContainsPoint(rightBezel, point))) {
    modes |= MMOpenDrawerGestureModeBezelPanningCenterView;
  }
  return modes;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldReceiveTouch:(UITouch *)touch
{
  if (gestureRecognizer == _attachedSheetDrawerPanGesture) {
    if (self.openSide == MMDrawerSideNone) {
      MMOpenDrawerGestureMode supportedOpenModes =
          MMOpenDrawerGestureModePanningCenterView |
          MMOpenDrawerGestureModeBezelPanningCenterView |
          MMOpenDrawerGestureModeCustom;
      return (self.openDrawerGestureModeMask & supportedOpenModes) != 0;
    }

    MMCloseDrawerGestureMode supportedCloseModes =
        MMCloseDrawerGestureModePanningNavigationBar |
        MMCloseDrawerGestureModePanningCenterView |
        MMCloseDrawerGestureModeBezelPanningCenterView |
        MMCloseDrawerGestureModePanningDrawerView |
        MMCloseDrawerGestureModeCustom;
    return (self.closeDrawerGestureModeMask & supportedCloseModes) != 0;
  }

  if (gestureRecognizer == _attachedSheetDrawerTapGesture) {
    if (self.openSide == MMDrawerSideNone) {
      return NO;
    }

    MMCloseDrawerGestureMode supportedTapModes =
        MMCloseDrawerGestureModeTapNavigationBar |
        MMCloseDrawerGestureModeTapCenterView |
        MMCloseDrawerGestureModeCustom;
    return (self.closeDrawerGestureModeMask & supportedTapModes) != 0;
  }

  return [super gestureRecognizer:gestureRecognizer shouldReceiveTouch:touch];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (_isResizingDrawer && [gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    return NO;
  }
  if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    return YES;
  }

  UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
  CGPoint velocity = [panGesture velocityInView:self.view];

  // Keep vertical scrolling available to drawer content such as TableViews.
  if (fabs(velocity.x) <= fabs(velocity.y)) {
    return NO;
  }

  // Reserve the direction opposite drawer closing for child horizontal
  // gestures, including TableView row actions.
  if (self.openSide == MMDrawerSideRight) {
    return velocity.x > 0.0f;
  }

  if (self.openSide == MMDrawerSideLeft) {
    return velocity.x < 0.0f;
  }

  // Preserve the configured opening-gesture behavior while closed.
  return YES;
}

- (void)panGestureCallback:(UIPanGestureRecognizer *)panGesture
{
  if (panGesture.state == UIGestureRecognizerStateBegan) {
    _isDirectlyDraggingDrawer = YES;
    [self startSlidingTrackingForSide:self.openSide];
    if (![_hapticFeedback isEqualToString:@"none"]) {
      [[self drawerHapticGenerator] prepare];
    }
  }

  if (panGesture.state == UIGestureRecognizerStateEnded ||
      panGesture.state == UIGestureRecognizerStateCancelled ||
      panGesture.state == UIGestureRecognizerStateFailed) {
    // MMDrawerController starts its finishing animation synchronously from
    // super. Mark direct tracking complete first so that animation can own the
    // sheet transform without competing display-link updates.
    _isDirectlyDraggingDrawer = NO;
  }

  _isSettlingGesture = panGesture.state == UIGestureRecognizerStateEnded ||
      panGesture.state == UIGestureRecognizerStateCancelled;
  _gestureWasCancelled = panGesture.state == UIGestureRecognizerStateCancelled;
  [super panGestureCallback:panGesture];
  _isSettlingGesture = NO;
  _gestureWasCancelled = NO;

  if (panGesture.state == UIGestureRecognizerStateChanged) {
    // During direct dragging the model layer is already at the finger's
    // position, so sample it immediately for the lowest possible latency.
    [self emitSlidingProgressUsingPresentationLayer:NO force:NO];
  }

  if (panGesture.state == UIGestureRecognizerStateEnded ||
      panGesture.state == UIGestureRecognizerStateCancelled ||
      panGesture.state == UIGestureRecognizerStateFailed) {

    /*
     * Normally MMDrawerController synchronously begins its finishing open/close
     * animation before returning from super, and the overrides below keep the
     * display link alive for that animation.
     *
     * If no drawer movement actually began, stop the display link here.
     */
    UIView *centerContainerView = self.centerContainerView;
    CGFloat originX = CGRectGetMinX(centerContainerView.frame);

    if (self.openSide == MMDrawerSideNone &&
        fabs(originX) < 0.5f &&
        centerContainerView.layer.animationKeys.count == 0) {
      [self setAttachedSheetInteractionBlocked:NO];
      [self stopSlidingTracking];
      _slidingSide = MMDrawerSideNone;
      _hasLastSlidingProgress = NO;
      _lastSlidingEventSide = MMDrawerSideNone;
      [self applyPendingDrawerWidth];
    }
  }
}

#pragma mark - Programmatic / finishing animations

- (void)applyPendingDrawerWidth
{
  if (_pendingDrawerWidthSide == MMDrawerSideNone || self.isAnimatingDrawer ||
      _isResizingDrawer || _isDirectlyDraggingDrawer || _isStartingDrawerTransition) {
    return;
  }
  CGFloat width = _pendingDrawerWidth;
  MMDrawerSide side = _pendingDrawerWidthSide;
  BOOL animated = _pendingDrawerWidthAnimated;
  void (^completion)(BOOL) = _pendingDrawerWidthCompletion;
  _pendingDrawerWidthSide = MMDrawerSideNone;
  _pendingDrawerWidthCompletion = nil;
  [self setMaximumDrawerWidth:width forSide:side animated:animated completion:completion];
}

- (void)setMaximumDrawerWidth:(CGFloat)width forSide:(MMDrawerSide)side
                     animated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  NSParameterAssert(isfinite(width) && width > 0.0f);
  NSParameterAssert(side == MMDrawerSideLeft || side == MMDrawerSideRight);

  if (_isResizingDrawer || self.isAnimatingDrawer || _isDirectlyDraggingDrawer || _isStartingDrawerTransition) {
    void (^supersededCompletion)(BOOL) = _pendingDrawerWidthCompletion;
    _pendingDrawerWidth = width;
    _pendingDrawerWidthSide = side;
    _pendingDrawerWidthAnimated = animated;
    _pendingDrawerWidthCompletion = [completion copy];
    if (supersededCompletion) {
      supersededCompletion(NO);
    }
    return;
  }

  CGFloat oldWidth = side == MMDrawerSideLeft ? self.maximumLeftDrawerWidth : self.maximumRightDrawerWidth;
  if (self.openSide != side || oldWidth <= 0.0f || fabs(width - oldWidth) < 0.0001f) {
    [super setMaximumDrawerWidth:width forSide:side animated:animated completion:completion];
    return;
  }

  CGFloat offset = CGRectGetMinX(self.centerContainerView.frame);
  CGFloat targetOffset = side == MMDrawerSideLeft ? width : -width;
  NSTimeInterval duration = [self animationDurationForAnimationDistance:fabs(width - oldWidth)];
  _isResizingDrawer = YES;
  _resizingDrawerSide = side;
  _resizeStartedFullyOpen = fabs(fabs(offset) - oldWidth) < 0.5f;
  [self startSlidingTrackingForSide:side];
  [self animateCenterBorderToProgress:1.0f animated:animated duration:duration
                    animationOptions:UIViewAnimationOptionCurveEaseInOut];
  [self animateAttachedSheetToCenterOffset:targetOffset animated:animated duration:duration
                         animationOptions:UIViewAnimationOptionCurveEaseInOut];
  self.animatingDrawer = animated;

  [super setMaximumDrawerWidth:width forSide:side animated:animated completion:^(BOOL finished) {
    self.animatingDrawer = NO;
    _isResizingDrawer = NO;
    _resizingDrawerSide = MMDrawerSideNone;
    _isAnimatingAttachedSheetWithDrawer = NO;
    _isAnimatingCenterBorder = NO;
    CGFloat currentOffset = CGRectGetMinX(self.centerContainerView.frame);
    CGFloat currentWidth = side == MMDrawerSideLeft ? self.maximumLeftDrawerWidth : self.maximumRightDrawerWidth;
    CGFloat progress = currentWidth > 0.0f ? MIN(fabs(currentOffset) / currentWidth, 1.0f) : 0.0f;
    [self finishSlidingTrackingForSide:side progress:progress];
    if (completion) {
      completion(finished);
    }
  }];
}

- (void)openDrawerSide:(MMDrawerSide)drawerSide
              animated:(BOOL)animated
              velocity:(CGFloat)velocity
      animationOptions:(UIViewAnimationOptions)options
            completion:(void (^)(BOOL finished))completion
{
  if (_isResizingDrawer || _isStartingDrawerTransition) {
    if (completion) completion(NO);
    return;
  }
  [self startSlidingTrackingForSide:drawerSide];

  UIViewController *drawerViewController =
      drawerSide == MMDrawerSideLeft ? self.leftDrawerViewController
                                     : self.rightDrawerViewController;
  CGFloat currentOffset = CGRectGetMinX(self.centerContainerView.frame);
  CGFloat targetOffset = drawerSide == MMDrawerSideLeft
      ? self.maximumLeftDrawerWidth
      : -self.maximumRightDrawerWidth;
  CGFloat distance = fabs(currentOffset - targetOffset);
  NSTimeInterval duration =
      MAX(distance / fabs(velocity), MMDrawerMinimumAnimationDuration);
  BOOL shouldCoordinateSheet =
      !self.isAnimatingDrawer && drawerViewController != nil;
  NSString *source = (_isSettlingGesture || _isHandlingDrawerTap) ? @"gesture" : @"programmatic";
  BOOL emitsTransition = shouldCoordinateSheet && distance > 0.0001f;
  if (emitsTransition) {
    [self beginDrawerTransition:@"opening" side:drawerSide source:source];
  }

  if (shouldCoordinateSheet) {
    [self animateCenterBorderToProgress:1.0f animated:animated duration:duration animationOptions:options];
    [self animateAttachedSheetToCenterOffset:targetOffset
                                    animated:animated
                                    duration:duration
                            animationOptions:options];
  }

  [super openDrawerSide:drawerSide
               animated:animated
               velocity:velocity
       animationOptions:options
             completion:^(BOOL finished) {

               _isAnimatingAttachedSheetWithDrawer = NO;
               if (shouldCoordinateSheet) {
                 _isAnimatingCenterBorder = NO;
               }

               if (finished) {
                 [self finishSlidingTrackingForSide:drawerSide progress:1.0f];
                 if (emitsTransition && self.transitionCallback) {
                   self.transitionCallback(@"open", drawerSide, source);
                 }
               } else {
                 [self emitSlidingProgressUsingPresentationLayer:YES force:YES];
                 [self updateAttachedSheetInteractionForCurrentDrawerState];
                 [self stopSlidingTracking];
               }

               if (completion) {
                 completion(finished);
               }
             }];
}

- (void)closeDrawerAnimated:(BOOL)animated
                   velocity:(CGFloat)velocity
           animationOptions:(UIViewAnimationOptions)options
                 completion:(void (^)(BOOL finished))completion
{
  if (_isResizingDrawer || _isStartingDrawerTransition) {
    if (completion) completion(NO);
    return;
  }
  MMDrawerSide closingSide = self.openSide;

  if (closingSide == MMDrawerSideNone) {
    CGFloat originX = CGRectGetMinX(self.centerContainerView.frame);

    if (originX > 0.0f) {
      closingSide = MMDrawerSideLeft;
    } else if (originX < 0.0f) {
      closingSide = MMDrawerSideRight;
    } else {
      closingSide = _slidingSide;
    }
  }

  [self startSlidingTrackingForSide:closingSide];

  CGFloat currentOffset = CGRectGetMinX(self.centerContainerView.frame);
  CGFloat distance = fabs(currentOffset);
  NSTimeInterval duration =
      MAX(distance / fabs(velocity), MMDrawerMinimumAnimationDuration);
  BOOL shouldCoordinateSheet = !self.isAnimatingDrawer;
  NSString *source = (_isSettlingGesture || _isHandlingDrawerTap) ? @"gesture" : @"programmatic";
  BOOL emitsTransition = shouldCoordinateSheet && closingSide != MMDrawerSideNone && distance > 0.0001f;
  if (emitsTransition) {
    [self beginDrawerTransition:@"closing" side:closingSide source:source];
  }

  if (shouldCoordinateSheet) {
    [self animateCenterBorderToProgress:0.0f animated:animated duration:duration animationOptions:options];
    [self animateAttachedSheetToCenterOffset:0.0f
                                    animated:animated
                                    duration:duration
                            animationOptions:options];
  }

  [super closeDrawerAnimated:animated
                    velocity:velocity
            animationOptions:options
                  completion:^(BOOL finished) {

                    _isAnimatingAttachedSheetWithDrawer = NO;
                    if (shouldCoordinateSheet) {
                      _isAnimatingCenterBorder = NO;
                    }

                    if (finished) {
                      [self finishSlidingTrackingForSide:closingSide progress:0.0f];
                      if (emitsTransition && self.transitionCallback) {
                        self.transitionCallback(@"closed", closingSide, source);
                      }
                    } else {
                      [self emitSlidingProgressUsingPresentationLayer:YES force:YES];
                      [self updateAttachedSheetInteractionForCurrentDrawerState];
                      [self stopSlidingTracking];
                    }

                    if (completion) {
                      completion(finished);
                    }
                  }];
}

#pragma mark - Bounce tracking

- (void)bouncePreviewForDrawerSide:(MMDrawerSide)drawerSide
                          distance:(CGFloat)distance
                        completion:(void (^)(BOOL finished))completion
{
  [self startSlidingTrackingForSide:drawerSide];

  [super bouncePreviewForDrawerSide:drawerSide
                           distance:distance
                         completion:^(BOOL finished) {

                           /*
                            * Bounce uses a CAKeyframeAnimation directly on the
                            * center layer. CADisplayLink samples the presentation
                            * layer so the sliding event follows the actual bounce.
                            */
                           [self finishSlidingTrackingForSide:drawerSide progress:0.0f];

                           if (completion) {
                             completion(finished);
                           }
                         }];
}

#pragma mark - Cleanup

- (void)clearWindowAppearanceCallback
{
  self.transitionCallback = nil;
  _drawerHapticGenerator = nil;
  if (_isResizingDrawer) {
    self.animatingDrawer = NO;
  }
  _isResizingDrawer = NO;
  _pendingDrawerWidthCompletion = nil;
  _pendingDrawerWidthSide = MMDrawerSideNone;
  _isAnimatingCenterBorder = NO;
  _isDirectlyDraggingDrawer = NO;
  [self stopSlidingTracking];
  [self detachPresentedSheet];

  [_centerCornerMeasurementContainer removeFromSuperview];
  _centerCornerMeasurementContainer = nil;
  _centerCornerMeasurementView = nil;
  _callback = nil;
  _slidingCallback = nil;

  _slidingSide = MMDrawerSideNone;
  _hasLastSlidingProgress = NO;
  _lastSlidingEventSide = MMDrawerSideNone;

  [super setGestureCompletionBlock:nil];
}

@end
