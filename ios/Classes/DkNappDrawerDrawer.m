/**
 * Module developed by Napp ApS
 * www.napp.dk
 * Mads Møller
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#define USE_TI_UINAVIGATIONWINDOW

#import "DkNappDrawerDrawer.h"
#import "DkNappDrawerDrawerProxy.h"
#import "TiUINavigationWindowProxy.h"
#import "TiUtils.h"
#import "TiViewController.h"
#import "TiUINavigationWindowInternal.h"
#import <TitaniumKit/TiApp.h>



UIViewController *ControllerForViewProxy(TiViewProxy *proxy);

UIViewController *ControllerForViewProxy(TiViewProxy *proxy)
{
  [[proxy view] setAutoresizingMask:UIViewAutoresizingNone];

  //make the proper resize !
  if ([NSThread isMainThread]) {
    [proxy windowWillOpen];
    [proxy reposition];
    [proxy windowDidOpen];
  } else {
    TiThreadPerformOnMainThread(^{
      [proxy windowWillOpen];
      [proxy reposition];
      [proxy windowDidOpen];
    }, NO);
  }
  return [[TiViewController alloc] initWithViewProxy:proxy];
}

UINavigationController *NavigationControllerForViewProxy(TiUINavigationWindowProxy *proxy)
{
  return [proxy controller];
}

@implementation DkNappDrawerDrawer

#pragma mark - Accessibility

- (id)accessibilityElement
{
  return controllerView_;
}

// G12: Thread-safe accessibleElements mit @synchronized
- (NSArray *)accessibleElements
{
  @synchronized(self) {
    if (_accessibleElements != nil) {
      [_accessibleElements removeAllObjects];
    } else {
      _accessibleElements = [[NSMutableArray alloc] init];
    }

    if ([[self isLeftWindowOpen:nil] intValue]) {
      [_accessibleElements addObject:leftView_];
    } else if ([[self isRightWindowOpen:nil] intValue]) {
      [_accessibleElements addObject:rightView_];
    }
    [_accessibleElements addObject:controllerView_];

    return _accessibleElements;
  }
}

/* The container itself is not accessible, so MultiFacetedView should return NO in isAccessiblityElement. */
- (BOOL)isAccessibilityElement
{
  return NO;
}

/* The following methods are implementations of UIAccessibilityContainer protocol methods. */
- (NSInteger)accessibilityElementCount
{
  return [[self accessibleElements] count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  return [[self accessibleElements] objectAtIndex:index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  return [[self accessibleElements] indexOfObject:element];
}

#pragma mark - Init

// G1: Per-Instance thread-sichere lazy init (dispatch_once war prozessweit — verhindert Neuerstellung bei neuer Instanz)
- (MMDrawerController *)controller
{
  @synchronized(self) {
    if (controller != nil) {
      return controller;
    }
    // G2: isKindOfClass: statt String-Vergleich (TiUINavigationWindowProxy)
    TiUINavigationWindowProxy *centerProxy = [self.proxy valueForUndefinedKey:@"centerWindow"];
    BOOL useNavController = [centerProxy isKindOfClass:[TiUINavigationWindowProxy class]];

    // navController or TiWindow ?
    UIViewController *centerWindow = useNavController ? NavigationControllerForViewProxy(centerProxy) : ControllerForViewProxy(centerProxy);

    TiViewProxy *leftWindow = [self.proxy valueForUndefinedKey:@"leftWindow"];
    TiViewProxy *rightWindow = [self.proxy valueForUndefinedKey:@"rightWindow"];
    __weak __typeof__(self) weakSelf = self;

    if (leftWindow != nil) {

      BOOL leftIsNav = [leftWindow isKindOfClass:[TiUINavigationWindowProxy class]];
      UIViewController *leftController = leftIsNav
        ? NavigationControllerForViewProxy((TiUINavigationWindowProxy *)leftWindow)
        : ControllerForViewProxy(leftWindow);

      //both left and right
      if (rightWindow != nil) {

        BOOL rightIsNav = [rightWindow isKindOfClass:[TiUINavigationWindowProxy class]];
        UIViewController *rightController = rightIsNav
          ? NavigationControllerForViewProxy((TiUINavigationWindowProxy *)rightWindow)
          : ControllerForViewProxy(rightWindow);

        // G13: windowWillOpen/windowDidOpen nur für NavigationWindow feuern
        // (ControllerForViewProxy feuert sie bereits für reguläre Windows)
        if (useNavController) {
          if (![NSThread isMainThread]) {
            TiThreadPerformOnMainThread(^{
              [centerProxy windowWillOpen];
              [centerProxy windowDidOpen];
            }, NO);
          } else {
            [centerProxy windowWillOpen];
            [centerProxy windowDidOpen];
          }
        }

        controller = [[CustomMMDrawerController alloc] initWithCenterViewController:centerWindow
                                                           leftDrawerViewController:leftController
                                                          rightDrawerViewController:rightController];
        //left only
      } else {

        if (useNavController) {
          if (![NSThread isMainThread]) {
            TiThreadPerformOnMainThread(^{
              [centerProxy windowWillOpen];
              [centerProxy windowDidOpen];
            }, NO);
          } else {
            [centerProxy windowWillOpen];
            [centerProxy windowDidOpen];
          }
        }

        controller = [[CustomMMDrawerController alloc] initWithCenterViewController:centerWindow
                                                           leftDrawerViewController:leftController];
      }
      //right only
    } else if (rightWindow != nil) {

      BOOL rightIsNav = [rightWindow isKindOfClass:[TiUINavigationWindowProxy class]];
      UIViewController *rightController = rightIsNav
        ? NavigationControllerForViewProxy((TiUINavigationWindowProxy *)rightWindow)
        : ControllerForViewProxy(rightWindow);

      if (useNavController) {
        if (![NSThread isMainThread]) {
          TiThreadPerformOnMainThread(^{
            [centerProxy windowWillOpen];
            [centerProxy windowDidOpen];
          }, NO);
        } else {
          [centerProxy windowWillOpen];
          [centerProxy windowDidOpen];
        }
      }

      controller = [[CustomMMDrawerController alloc] initWithCenterViewController:centerWindow
                                                        rightDrawerViewController:rightController];

      //error
    } else {
      NSLog(@"[ERROR][DkNappDrawerDrawer] No windows assigned");
    }

    // G11: Block mit weak-self Referenz, callback wird auf nil gesetzt wenn Drawer schliesst
    [controller setWindowAppearanceCallback:^(NSString *state) {
      __typeof__(self) strongSelf = weakSelf;

      if (!strongSelf) {
        return;
      }

      if ([state isEqualToString:@"open"]) {
        [[strongSelf proxy] fireEvent:@"windowDidOpen"];
      } else if ([state isEqualToString:@"close"]) {
        if ([TiUtils boolValue:[[strongSelf proxy] valueForUndefinedKey:@"autoCloseWindows"] def:YES]) {
          [[strongSelf proxy] fireEvent:@"windowDidClose"];
        }
      }

      [strongSelf _fireStateEventForCurrentState];
    }];

    [controller setSlidingCallback:^(CGFloat progress, MMDrawerSide drawerSide, BOOL resizing, CGFloat drawerWidth, CGFloat centerOffset) {
      __typeof__(self) strongSelf = weakSelf;

      if (!strongSelf) {
        return;
      }

      if (![[strongSelf proxy] _hasListeners:@"sliding"]) {
        return;
      }

      NSString *side = @"none";

      if (drawerSide == MMDrawerSideLeft) {
        side = @"left";
      } else if (drawerSide == MMDrawerSideRight) {
        side = @"right";
      }

      [[strongSelf proxy] fireEvent:@"sliding"
                         withObject:@{
                           @"progress": @(progress),
                           @"side": side,
                           @"resizing": @(resizing),
                           @"drawerWidth": @(drawerWidth),
                           @"centerOffset": @(centerOffset)
                         }];
    }];

    // SET PROPERTIES at init
    controller.transitionCallback = ^(NSString *state, MMDrawerSide drawerSide, NSString *source) {
      __typeof__(self) strongSelf = weakSelf;
      if (strongSelf && [[strongSelf proxy] _hasListeners:@"drawerTransition"]) {
        [[strongSelf proxy] fireEvent:@"drawerTransition" withObject:@{
          @"state": state,
          @"side": drawerSide == MMDrawerSideLeft ? @"left" : @"right",
          @"source": source
        }];
      }
    };
    if ([self.proxy valueForUndefinedKey:@"hapticFeedback"] != nil) {
      [self setHapticFeedback_:[self.proxy valueForUndefinedKey:@"hapticFeedback"]];
    }
    if ([self.proxy valueForUndefinedKey:@"hapticStyle"] != nil) {
      [self setHapticStyle_:[self.proxy valueForUndefinedKey:@"hapticStyle"]];
    }
    if ([self.proxy valueForUndefinedKey:@"rootBackgroundColor"] != nil) {
      [self setRootBackgroundColor_:[self.proxy valueForUndefinedKey:@"rootBackgroundColor"]];
    }

    if ([self.proxy valueForUndefinedKey:@"openDrawerGestureMode"] != nil) {
      [self setOpenDrawerGestureMode_:[self.proxy valueForUndefinedKey:@"openDrawerGestureMode"]];
    }
    if ([self.proxy valueForUndefinedKey:@"openDrawerBezelWidth"] != nil) {
      [self setOpenDrawerBezelWidth_:[self.proxy valueForUndefinedKey:@"openDrawerBezelWidth"]];
    }

    if ([self.proxy valueForUndefinedKey:@"closeDrawerGestureMode"] != nil) {
      [self setCloseDrawerGestureMode_:[self.proxy valueForUndefinedKey:@"closeDrawerGestureMode"]];
    }
    if ([self.proxy valueForUndefinedKey:@"closeDrawerBezelWidth"] != nil) {
      [self setCloseDrawerBezelWidth_:[self.proxy valueForUndefinedKey:@"closeDrawerBezelWidth"]];
    }

    if ([self.proxy valueForUndefinedKey:@"leftDrawerWidth"] != nil) {
      [self setLeftDrawerWidth_:[self.proxy valueForUndefinedKey:@"leftDrawerWidth"]];
    }

    if ([self.proxy valueForUndefinedKey:@"rightDrawerWidth"] != nil) {
      [self setRightDrawerWidth_:[self.proxy valueForUndefinedKey:@"rightDrawerWidth"]];
    }

    if ([self.proxy valueForUndefinedKey:@"centerHiddenInteractionMode"] != nil) {
      [self setCenterHiddenInteractionMode_:[self.proxy valueForUndefinedKey:@"centerHiddenInteractionMode"]];
    }

    if ([self.proxy valueForUndefinedKey:@"showShadow"] != nil) {
      [self setShowShadow_:[self.proxy valueForUndefinedKey:@"showShadow"]];
    }
    if ([self.proxy valueForUndefinedKey:@"shadowRadius"] != nil) {
      [self setShadowRadius_:[self.proxy valueForUndefinedKey:@"shadowRadius"]];
    }
    if ([self.proxy valueForUndefinedKey:@"shadowColor"] != nil) {
      [self setShadowColor_:[self.proxy valueForUndefinedKey:@"shadowColor"]];
    }
    if ([self.proxy valueForUndefinedKey:@"shadowOpacity"] != nil) {
      [self setShadowOpacity_:[self.proxy valueForUndefinedKey:@"shadowOpacity"]];
    }

    if ([self.proxy valueForUndefinedKey:@"animationMode"] != nil) {
      [self setAnimationMode_:[self.proxy valueForUndefinedKey:@"animationMode"]];
    }
    if ([self.proxy valueForUndefinedKey:@"animationMinScale"] != nil) {
      [self setAnimationMinScale_:[self.proxy valueForUndefinedKey:@"animationMinScale"]];
    }
    if ([self.proxy valueForUndefinedKey:@"animationScaleFade"] != nil) {
      [self setAnimationScaleFade_:[self.proxy valueForUndefinedKey:@"animationScaleFade"]];
    }
    if ([self.proxy valueForUndefinedKey:@"leftAnimationMode"] != nil) {
      [self setLeftAnimationMode_:[self.proxy valueForUndefinedKey:@"leftAnimationMode"]];
    }
    if ([self.proxy valueForUndefinedKey:@"rightAnimationMode"] != nil) {
      [self setRightAnimationMode_:[self.proxy valueForUndefinedKey:@"rightAnimationMode"]];
    }

    if ([self.proxy valueForUndefinedKey:@"animationVelocity"] != nil) {
      [self setAnimationVelocity_:[self.proxy valueForUndefinedKey:@"animationVelocity"]];
    }

    if ([self.proxy valueForUndefinedKey:@"shouldStretchDrawer"] != nil) {
      [self setShouldStretchDrawer_:[self.proxy valueForUndefinedKey:@"shouldStretchDrawer"]];
    }

    if ([self.proxy valueForUndefinedKey:@"showStatusBarView"] != nil) {
      [self setShowsStatusBarBackgroundView_:[self.proxy valueForUndefinedKey:@"showStatusBarView"]];
    }

    if ([self.proxy valueForUndefinedKey:@"statusBarStyle"] != nil) {
      [self setStatusBarStyle_:[self.proxy valueForUndefinedKey:@"statusBarStyle"]];
    }

    if ([self.proxy valueForUndefinedKey:@"followsPresentedSheet"] != nil) {
      [self setFollowsPresentedSheet_:[self.proxy valueForUndefinedKey:@"followsPresentedSheet"]];
    }

    if ([self.proxy valueForUndefinedKey:@"presentedSheetEdgeWidth"] != nil) {
      [self setPresentedSheetEdgeWidth_:[self.proxy valueForUndefinedKey:@"presentedSheetEdgeWidth"]];
    }

    if ([self.proxy valueForUndefinedKey:@"centerCornerMode"] != nil) {
      [self setCenterCornerMode_:[self.proxy valueForUndefinedKey:@"centerCornerMode"]];
    }
    if ([self.proxy valueForUndefinedKey:@"centerCornerRadius"] != nil) {
      [self setCenterCornerRadius_:[self.proxy valueForUndefinedKey:@"centerCornerRadius"]];
    }
    if ([self.proxy valueForUndefinedKey:@"centerBorderWidth"] != nil) {
      [self setCenterBorderWidth_:[self.proxy valueForUndefinedKey:@"centerBorderWidth"]];
    }
    if ([self.proxy valueForUndefinedKey:@"centerBorderColor"] != nil) {
      [self setCenterBorderColor_:[self.proxy valueForUndefinedKey:@"centerBorderColor"]];
    }
    if ([self.proxy valueForUndefinedKey:@"centerBorderOpacity"] != nil) {
      [self setCenterBorderOpacity_:[self.proxy valueForUndefinedKey:@"centerBorderOpacity"]];
    }
    if ([self.proxy valueForUndefinedKey:@"centerBorderFollowsSliding"] != nil) {
      [self setCenterBorderFollowsSliding_:[self.proxy valueForUndefinedKey:@"centerBorderFollowsSliding"]];
    }

    UIViewController *topCtrl = TiApp.controller.topPresentedController;

    // set frame bounds & add it
    controllerView_ = [controller view];
    [controllerView_ setFrame:[self bounds]];
    // Establish containment before a visible initial side enters the window.
    // addChildViewController also performs willMoveToParentViewController.
    [topCtrl addChildViewController:controller];

    id initialSide = [self.proxy valueForUndefinedKey:@"initialDrawerSide"];
    if (initialSide != nil && initialSide != [NSNull null]) {
      [self setInitialDrawerSide_:initialSide]; // Validate without creating a view.
      MMDrawerSide side = [initialSide isEqualToString:@"left"] ? MMDrawerSideLeft :
          ([initialSide isEqualToString:@"right"] ? MMDrawerSideRight : MMDrawerSideNone);
      [controller configureInitialDrawerSide:side];
    }

    [self addSubview:controllerView_];

    // G3: didMoveToParentViewController: nach addChildViewController:
    [controller didMoveToParentViewController:topCtrl];

    leftView_ = leftWindow.view;
    rightView_ = rightWindow.view;
    centerView_ = centerWindow.view;
  } // end @synchronized
  return controller;
}

- (void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
  [[[self controller] view] setFrame:bounds];
  [super frameSizeChanged:frame bounds:bounds];
}

// G11: Cleanup beim Destroy — Callback, Notification Observer und TiViewControllers aus Parent entfernen
// Direkter Ivar-Zugriff statt Property-Getter, um @synchronized auf freigegebenem Objekt zu vermeiden
- (void)dealloc
{
  // centerViewController
  if (controller.centerViewController) {
    UIViewController *centerVC = controller.centerViewController;
    if ([centerVC respondsToSelector:@selector(parentViewController)]) {
      if (centerVC.parentViewController) {
        [centerVC removeFromParentViewController];
      }
    }
  }

  // leftDrawerViewController
  if (controller.leftDrawerViewController) {
    UIViewController *leftVC = controller.leftDrawerViewController;
    if ([leftVC respondsToSelector:@selector(parentViewController)]) {
      if (leftVC.parentViewController) {
        [leftVC removeFromParentViewController];
      }
    }
  }

  // rightDrawerViewController
  if (controller.rightDrawerViewController) {
    UIViewController *rightVC = controller.rightDrawerViewController;
    if ([rightVC respondsToSelector:@selector(parentViewController)]) {
      if (rightVC.parentViewController) {
        [rightVC removeFromParentViewController];
      }
    }
  }

  if (controller) {
    [controller clearWindowAppearanceCallback];
  }
}

#pragma mark - Properties

- (void)setCenterWindow_:(id)args
{
  ENSURE_UI_THREAD(setCenterWindow_, args);

  // G2: isKindOfClass: statt String-Vergleich
  TiUINavigationWindowProxy *centerProxy = [self.proxy valueForUndefinedKey:@"centerWindow"];
  BOOL useNavController = [centerProxy isKindOfClass:[TiUINavigationWindowProxy class]];
  UIViewController *centerWindow = useNavController
    ? NavigationControllerForViewProxy(centerProxy)
    : ControllerForViewProxy(centerProxy);

  if (useNavController && controller != nil) {
    if (![NSThread isMainThread]) {
      TiThreadPerformOnMainThread(^{
        [centerProxy windowWillOpen];
        [centerProxy windowDidOpen];
      }, NO);
    } else {
      [centerProxy windowWillOpen];
      [centerProxy windowDidOpen];
    }
  }

  [controller setCenterViewController:centerWindow];

  // Cleanup
  if (useNavController) {
    if (navProxy != nil) {
      if ([TiUtils boolValue:[[self proxy] valueForUndefinedKey:@"autoCloseWindows"] def:YES]) {
        [navProxy windowWillClose];
        [navProxy windowDidClose];
      }
    }
    // Save new proxy
    navProxy = centerProxy;
  }
}

- (void)setLeftWindow_:(id)args
{
  ENSURE_UI_THREAD(setLeftWindow_, args);
  if ([TiUtils boolValue:args] == 0) {
    [controller setLeftDrawerViewController:nil];
  } else {
    [controller setLeftDrawerViewController:ControllerForViewProxy(args)];
  }
}

- (void)setRightWindow_:(id)args
{
  ENSURE_UI_THREAD(setRightWindow_, args);
  if ([TiUtils boolValue:args] == 0) {
    [controller setRightDrawerViewController:nil];
  } else {
    [controller setRightDrawerViewController:ControllerForViewProxy(args)];
  }
}

- (void)setLeftDrawerWidth_:(id)args
{
  ENSURE_UI_THREAD(setLeftDrawerWidth_, args);
  //ENSURE_SINGLE_ARG(args, NSNumber);
  if ([args respondsToSelector:@selector(objectForKey:)]) {
    [controller setMaximumLeftDrawerWidth:[TiUtils floatValue:@"width" properties:args] animated:[TiUtils boolValue:@"animated" properties:args def:NO] completion:nil];
  } else {
    [controller setMaximumLeftDrawerWidth:[TiUtils floatValue:args]];
  }
}

- (void)setRightDrawerWidth_:(id)args
{
  ENSURE_UI_THREAD(setRightDrawerWidth_, args);
  // ENSURE_SINGLE_ARG(args, NSNumber);
  if ([args respondsToSelector:@selector(objectForKey:)]) {
    [controller setMaximumRightDrawerWidth:[TiUtils floatValue:@"width" properties:args] animated:[TiUtils boolValue:@"animated" properties:args def:NO] completion:nil];
  } else {
    [controller setMaximumRightDrawerWidth:[TiUtils floatValue:args]];
  }
}

- (void)setCloseDrawerGestureMode_:(id)args
{
  ENSURE_UI_THREAD(setCloseDrawerGestureMode_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setCloseDrawerGestureModeMask:[TiUtils intValue:args]];
}

- (void)setOpenDrawerGestureMode_:(id)args
{
  ENSURE_UI_THREAD(setOpenDrawerGestureMode_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setOpenDrawerGestureModeMask:[TiUtils intValue:args]];
}

- (void)setCloseDrawerBezelWidth_:(id)args
{
  ENSURE_UI_THREAD(setCloseDrawerBezelWidth_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.closeDrawerBezelWidth = [TiUtils floatValue:args def:20.0f];
}

- (void)setCenterHiddenInteractionMode_:(id)args
{
  ENSURE_UI_THREAD(setCenterHiddenInteractionMode_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setCenterHiddenInteractionMode:[TiUtils intValue:args]];
}

- (void)setOpenDrawerBezelWidth_:(id)args
{
  ENSURE_UI_THREAD(setOpenDrawerBezelWidth_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.openDrawerBezelWidth = [TiUtils floatValue:args def:20.0f];
}

- (void)setAnimationVelocity_:(id)args
{
  ENSURE_UI_THREAD(setAnimationVelocity_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setAnimationVelocity:[TiUtils floatValue:args]];
}

- (void)setShowShadow_:(id)args
{
  ENSURE_UI_THREAD(setShowShadow_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setShowsShadow:[TiUtils boolValue:args]];
}

- (void)setHapticFeedback_:(id)args
{
  ENSURE_UI_THREAD(setHapticFeedback_, args);
  ENSURE_SINGLE_ARG(args, NSString);
  if (![@[@"none", @"gesture", @"all"] containsObject:args]) {
    [NSException raise:NSInvalidArgumentException format:@"hapticFeedback must be none, gesture, or all"];
  }
  controller.hapticFeedback = args;
}

- (void)setInitialDrawerSide_:(id)args
{
  ENSURE_UI_THREAD(setInitialDrawerSide_, args);
  ENSURE_SINGLE_ARG(args, NSString);
  if (![@[@"center", @"left", @"right"] containsObject:args]) {
    [NSException raise:NSInvalidArgumentException format:@"initialDrawerSide must be center, left, or right"];
  }
  // Creation-time configuration only. Live updates do not move an open drawer.
}

- (void)setHapticStyle_:(id)args
{
  ENSURE_UI_THREAD(setHapticStyle_, args);
  ENSURE_SINGLE_ARG(args, NSString);
  if (![@[@"light", @"medium", @"heavy", @"soft", @"rigid"] containsObject:args]) {
    [NSException raise:NSInvalidArgumentException format:@"hapticStyle must be light, medium, heavy, soft, or rigid"];
  }
  controller.hapticStyle = args;
}

- (void)setShadowRadius_:(id)args
{
  ENSURE_UI_THREAD(setShadowRadius_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.shadowRadius = [TiUtils floatValue:args def:10.0f];
}

- (void)setShadowColor_:(id)args
{
  ENSURE_UI_THREAD(setShadowColor_, args);
  controller.shadowColor = [[TiUtils colorValue:args] _color];
}

- (void)setShadowOpacity_:(id)args
{
  ENSURE_UI_THREAD(setShadowOpacity_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.shadowOpacity = [TiUtils floatValue:args def:0.8f];
}

- (void)setShouldStretchDrawer_:(id)args
{
  ENSURE_UI_THREAD(setShouldStretchDrawer_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setShouldStretchDrawer:[TiUtils boolValue:args]];
}

- (void)setFollowsPresentedSheet_:(id)args
{
  ENSURE_UI_THREAD(setFollowsPresentedSheet_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.followsPresentedSheet = [TiUtils boolValue:args def:NO];
}

- (void)setRootBackgroundColor_:(id)args
{
  ENSURE_UI_THREAD(setRootBackgroundColor_, args);
  // Loading the view first lets MMDrawerController apply its default before
  // applying the requested color. A later assignment uses the same path.
  controller.view.backgroundColor = [[TiUtils colorValue:args] _color] ?: UIColor.blackColor;
}

- (void)setCenterCornerMode_:(id)args
{
  ENSURE_UI_THREAD(setCenterCornerMode_, args);
  ENSURE_SINGLE_ARG(args, NSString);
  if (![@[@"none", @"continuous", @"concentric"] containsObject:args]) {
    [NSException raise:NSInvalidArgumentException format:@"centerCornerMode must be none, continuous, or concentric"];
  }
  controller.centerCornerMode = args;
}

- (void)setCenterCornerRadius_:(id)args
{
  ENSURE_UI_THREAD(setCenterCornerRadius_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.centerCornerRadius = [TiUtils floatValue:args def:32.0f];
}

- (void)setCenterBorderWidth_:(id)args
{
  ENSURE_UI_THREAD(setCenterBorderWidth_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.centerBorderWidth = [TiUtils floatValue:args def:0.0f];
}

- (void)setCenterBorderColor_:(id)args
{
  ENSURE_UI_THREAD(setCenterBorderColor_, args);
  controller.centerBorderColor = [[TiUtils colorValue:args] _color];
}

- (void)setCenterBorderOpacity_:(id)args
{
  ENSURE_UI_THREAD(setCenterBorderOpacity_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.centerBorderOpacity = [TiUtils floatValue:args def:1.0f];
}

- (void)setCenterBorderFollowsSliding_:(id)args
{
  ENSURE_UI_THREAD(setCenterBorderFollowsSliding_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.centerBorderFollowsSliding = [TiUtils boolValue:args def:NO];
}

- (void)setPresentedSheetEdgeWidth_:(id)args
{
  ENSURE_UI_THREAD(setPresentedSheetEdgeWidth_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.presentedSheetEdgeWidth = [TiUtils floatValue:args def:32.0f];
}

- (void)setShowsStatusBarBackgroundView_:(id)args
{
  ENSURE_UI_THREAD(setShowsStatusBarBackgroundView_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  [controller setShowsStatusBarBackgroundView:[TiUtils boolValue:args]];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  // Direkter Ivar-Zugriff statt Property-Getter
  if (controller) {
    return [controller preferredStatusBarStyle];
  }
  return UIStatusBarStyleDefault;
}


- (void)setStatusBarStyle_:(NSNumber *)style
{
  ENSURE_UI_THREAD(setStatusBarStyle_, style);
  // StatusBar-Style wird über den Proxy gesetzt (siehe DkNappDrawerDrawerProxy)
  // Hier nichts tun — der Proxy handhabt dies über TiWindowProxy.barStyle
}

- (void)setAnimationMode_:(id)args
{
  ENSURE_UI_THREAD(setAnimationMode_, args);
  [controller setDrawerVisualStateBlock:
      [NappDrawerVisualState visualStateBlockForAnimationMode:[TiUtils intValue:args]]];
}

- (void)setAnimationMinScale_:(id)args
{
  ENSURE_UI_THREAD(setAnimationMinScale_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.animationMinScale = [TiUtils floatValue:args def:0.90f];
}

- (void)setAnimationScaleFade_:(id)args
{
  ENSURE_UI_THREAD(setAnimationScaleFade_, args);
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.animationScaleFade = [TiUtils boolValue:args def:NO];
}

- (void)setLeftAnimationMode_:(id)args
{
  ENSURE_UI_THREAD(setLeftAnimationMode_, args);
  if (args == nil || args == [NSNull null]) {
    controller.leftDrawerVisualStateOverride = nil;
    return;
  }
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.leftDrawerVisualStateOverride =
      [NappDrawerVisualState visualStateBlockForAnimationMode:[TiUtils intValue:args]];
}

- (void)setRightAnimationMode_:(id)args
{
  ENSURE_UI_THREAD(setRightAnimationMode_, args);
  if (args == nil || args == [NSNull null]) {
    controller.rightDrawerVisualStateOverride = nil;
    return;
  }
  ENSURE_SINGLE_ARG(args, NSNumber);
  controller.rightDrawerVisualStateOverride =
      [NappDrawerVisualState visualStateBlockForAnimationMode:[TiUtils intValue:args]];
}



#pragma mark - API

- (void)toggleLeftWindow:(id)args
{
  ENSURE_UI_THREAD(toggleLeftWindow, args);
  [controller toggleDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
}

- (void)toggleRightWindow:(id)args
{
  ENSURE_UI_THREAD(toggleRightWindow, args);
  [controller toggleDrawerSide:MMDrawerSideRight animated:YES completion:nil];
}

- (void)bounceLeftWindow:(id)args
{
  ENSURE_UI_THREAD(bounceLeftWindow, args);
  [controller bouncePreviewForDrawerSide:MMDrawerSideLeft completion:nil];
}

- (void)bounceRightWindow:(id)args
{
  ENSURE_UI_THREAD(bounceRightWindow, args);
  [controller bouncePreviewForDrawerSide:MMDrawerSideRight completion:nil];
}

- (void)attachPresentedSheet:(id)args
{
  ENSURE_UI_THREAD(attachPresentedSheet, args);
  [controller attachPresentedSheet];
}

- (void)detachPresentedSheet:(id)args
{
  ENSURE_UI_THREAD(detachPresentedSheet, args);
  [controller detachPresentedSheet];
}

- (NSNumber *)isAnySheetOpen:(id)args
{
  __block BOOL sheetIsOpen = NO;
  void (^querySheetState)(void) = ^{
    sheetIsOpen = [self->controller isAnySheetOpen];
  };

  if ([NSThread isMainThread]) {
    querySheetState();
  } else {
    TiThreadPerformOnMainThread(querySheetState, YES);
  }

  return NUMBOOL(sheetIsOpen);
}

- (NSNumber *)getCenterCornerRadius:(id)args
{
  __block CGFloat radius = 0.0f;
  void (^queryRadius)(void) = ^{
    radius = [self->controller resolvedCenterCornerRadius];
  };
  if ([NSThread isMainThread]) {
    queryRadius();
  } else {
    TiThreadPerformOnMainThread(queryRadius, YES);
  }
  return @(radius);
}

- (NSNumber *)isAnyWindowOpen:(id)args
{
  return NUMBOOL(controller.openSide != MMDrawerSideNone);
}

- (NSNumber *)isLeftWindowOpen:(id)args
{
  return NUMBOOL(controller.openSide == MMDrawerSideLeft);
}

- (NSNumber *)isRightWindowOpen:(id)args
{
  return NUMBOOL(controller.openSide == MMDrawerSideRight);
}

#pragma mark - Events

// Little hack to propagate focus/blur events
- (void)_fireStateEventForCurrentState
{
  if ([[self controller] openSide] == MMDrawerSideNone) {
    if ([[self proxy] _hasListeners:@"centerWindowDidFocus"]) {
      [[self proxy] fireEvent:@"centerWindowDidFocus"];
    }
  } else {
    if ([[self proxy] _hasListeners:@"centerWindowDidBlur"]) {
      [[self proxy] fireEvent:@"centerWindowDidBlur"];
    }
  }
}
@end
