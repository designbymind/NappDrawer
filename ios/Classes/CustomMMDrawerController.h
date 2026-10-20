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

#import "MMDrawerController.h"

typedef void (^WindowAppearanceChangeBlock)(NSString *state);
typedef void (^DrawerSlidingChangeBlock)(CGFloat progress, MMDrawerSide side, BOOL resizing, CGFloat drawerWidth, CGFloat centerOffset);
typedef void (^DrawerTransitionChangeBlock)(NSString *state, MMDrawerSide side, NSString *source);

@interface CustomMMDrawerController : MMDrawerController {
  WindowAppearanceChangeBlock _callback;
  DrawerSlidingChangeBlock _slidingCallback;
}

- (void)setWindowAppearanceCallback:(void (^)(NSString *))callback;
- (void)setSlidingCallback:(DrawerSlidingChangeBlock)callback;
- (void)configureInitialDrawerSide:(MMDrawerSide)side;
@property (nonatomic, copy) DrawerTransitionChangeBlock transitionCallback;
@property (nonatomic, copy) NSString *hapticFeedback;
@property (nonatomic, copy) NSString *hapticStyle;
@property (nonatomic, assign) CGFloat openDrawerBezelWidth;
@property (nonatomic, assign) CGFloat closeDrawerBezelWidth;
@property (nonatomic, assign) CGFloat animationMinScale;
@property (nonatomic, assign) BOOL animationScaleFade;

// Optional native UISheetPresentationController integration.
@property (nonatomic, assign) BOOL followsPresentedSheet;
@property (nonatomic, assign) CGFloat presentedSheetEdgeWidth;
- (BOOL)attachPresentedSheet;
- (void)detachPresentedSheet;
- (BOOL)isAnySheetOpen;

// Optional styling of the complete center content, including navigation bars.
@property (nonatomic, copy) NSString *centerCornerMode;
@property (nonatomic, assign) CGFloat centerCornerRadius;
@property (nonatomic, assign) CGFloat centerBorderWidth;
@property (nonatomic, strong) UIColor *centerBorderColor;
@property (nonatomic, assign) CGFloat centerBorderOpacity;
@property (nonatomic, assign) BOOL centerBorderFollowsSliding;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGFloat shadowOpacity;
- (CGFloat)resolvedCenterCornerRadius;
@property (nonatomic, copy) MMDrawerControllerDrawerVisualStateBlock leftDrawerVisualStateOverride;
@property (nonatomic, copy) MMDrawerControllerDrawerVisualStateBlock rightDrawerVisualStateOverride;

// Cleanup callbacks / display-link tracking to avoid retain cycles.
- (void)clearWindowAppearanceCallback;

@end
