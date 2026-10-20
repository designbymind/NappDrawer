/**
 * Module developed by Napp ApS
 * www.napp.dk
 * Mads Møller
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */

#import "NappDrawerVisualState.h"
#import "CustomMMDrawerController.h"
#import "MMDrawerVisualState.h"
#import <QuartzCore/QuartzCore.h>

@implementation NappDrawerVisualState

+ (MMDrawerControllerDrawerVisualStateBlock)visualStateBlockForAnimationMode:(NSInteger)mode
{
    switch (mode) {
        case 1: return [self slideAndScaleVisualStateBlock];
        case 2: return [self slideVisualStateBlock];
        case 4: return [self parallax3VisualStateBlock];
        case 5: return [self parallax5VisualStateBlock];
        case 6: return [self parallax7VisualStateBlock];
        case 7: return [self fadeVisualStateBlock];
        case 8: return [self scaleVisualStateBlock];
        case 3:
        case 100:
        default: return [self noneVisualStateBlock];
    }
}

// G8: Redundante Visual State Methoden vereinfacht
// slideAndScale: eigen (unique to NappDrawer)
// slide: uses the bundled behavior with a pixel-safe left edge
// parallax3/5/7: delegiert an bundled MMDrawerVisualState
// none, fade: eigen (nicht im bundled MMDrawerVisualState vorhanden)

+ (MMDrawerControllerDrawerVisualStateBlock)slideAndScaleVisualStateBlock {
    MMDrawerControllerDrawerVisualStateBlock visualStateBlock = ^(MMDrawerController *drawerController, MMDrawerSide drawerSide, CGFloat percentVisible) {
        if (drawerSide == MMDrawerSideNone) return;

        // Read on every update, so existing global and per-side blocks use
        // runtime property changes without rebuilding or clearing overrides.
        CGFloat minScale = [drawerController isKindOfClass:CustomMMDrawerController.class]
            ? ((CustomMMDrawerController *)drawerController).animationMinScale : 0.90;
        CGFloat scale = minScale + (percentVisible * (1.0 - minScale));
        CATransform3D scaleTransform = CATransform3DMakeScale(scale, scale, scale);

        CGFloat maxDistance = 50;
        CGFloat distance = maxDistance * percentVisible;
        CATransform3D translateTransform;
        UIViewController *sideDrawerViewController;
        if (drawerSide == MMDrawerSideLeft) {
            sideDrawerViewController = drawerController.leftDrawerViewController;
            translateTransform = CATransform3DMakeTranslation((maxDistance - distance), 0.0, 0.0);
        } else if (drawerSide == MMDrawerSideRight) {
            sideDrawerViewController = drawerController.rightDrawerViewController;
            translateTransform = CATransform3DMakeTranslation(-(maxDistance - distance), 0.0, 0.0);
        }

        [sideDrawerViewController.view.layer setTransform:CATransform3DConcat(scaleTransform, translateTransform)];
        [sideDrawerViewController.view setAlpha:percentVisible];
    };
    return visualStateBlock;
}

+ (MMDrawerControllerDrawerVisualStateBlock)scaleVisualStateBlock {
    return ^(MMDrawerController *drawerController, MMDrawerSide drawerSide, CGFloat percentVisible) {
        if (drawerSide == MMDrawerSideNone) return;

        CustomMMDrawerController *customController =
            [drawerController isKindOfClass:CustomMMDrawerController.class]
                ? (CustomMMDrawerController *)drawerController : nil;
        CGFloat minScale = customController ? customController.animationMinScale : 0.90;
        CGFloat progress = MIN(MAX(percentVisible, 0.0), 1.0);
        CGFloat scale = minScale + (progress * (1.0 - minScale));
        UIViewController *sideController = drawerSide == MMDrawerSideLeft
            ? drawerController.leftDrawerViewController : drawerController.rightDrawerViewController;
        // Pure scaling: do not retain translation or opacity from a previous mode.
        sideController.view.layer.transform = CATransform3DMakeScale(scale, scale, scale);
        sideController.view.alpha = customController.animationScaleFade ? progress : 1.0;
    };
}

+ (MMDrawerControllerDrawerVisualStateBlock)slideVisualStateBlock {
    MMDrawerControllerDrawerVisualStateBlock bundledSlideVisualStateBlock = [MMDrawerVisualState slideVisualStateBlock];
    MMDrawerControllerDrawerVisualStateBlock visualStateBlock = ^(MMDrawerController *drawerController, MMDrawerSide drawerSide, CGFloat percentVisible) {
        if (drawerSide != MMDrawerSideLeft || percentVisible > 1.0) {
            bundledSlideVisualStateBlock(drawerController, drawerSide, percentVisible);
            return;
        }

        UIViewController *sideDrawerViewController = drawerController.leftDrawerViewController;
        CGFloat distance = MAX(drawerController.maximumLeftDrawerWidth, drawerController.visibleLeftDrawerWidth);
        CGFloat translation = -distance + (distance * percentVisible);

        UIScreen *screen = sideDrawerViewController.view.window.screen ?: [UIScreen mainScreen];
        CGFloat screenScale = MAX(screen.scale, 1.0);
        translation = round(translation * screenScale) / screenScale;

        // Keep the transformed drawer beneath the center view by one physical
        // pixel while it moves. The overlap naturally reaches zero when the
        // drawer is fully open, so the settled frame remains unchanged.
        CGFloat pixelOverlap = MIN(1.0 / screenScale, MAX(0.0, -translation));
        CATransform3D transform = CATransform3DMakeTranslation(translation + pixelOverlap, 0.0, 0.0);
        [sideDrawerViewController.view.layer setTransform:transform];
    };
    return visualStateBlock;
}

+ (MMDrawerControllerDrawerVisualStateBlock)noneVisualStateBlock {
    MMDrawerControllerDrawerVisualStateBlock visualStateBlock = ^(MMDrawerController *drawerController, MMDrawerSide drawerSide, CGFloat percentVisible) {
        // No animation
    };
    return visualStateBlock;
}

+ (MMDrawerControllerDrawerVisualStateBlock)fadeVisualStateBlock {
    MMDrawerControllerDrawerVisualStateBlock visualStateBlock = ^(MMDrawerController *drawerController, MMDrawerSide drawerSide, CGFloat percentVisible) {
        if (drawerSide == MMDrawerSideNone) return;

        UIViewController *sideDrawerViewController;
        if (drawerSide == MMDrawerSideLeft) {
            sideDrawerViewController = drawerController.leftDrawerViewController;
        } else {
            sideDrawerViewController = drawerController.rightDrawerViewController;
        }
        [sideDrawerViewController.view setAlpha:percentVisible];
    };
    return visualStateBlock;
}

+ (MMDrawerControllerDrawerVisualStateBlock)parallax3VisualStateBlock {
    return [MMDrawerVisualState parallaxVisualStateBlockWithParallaxFactor:3.0];
}

+ (MMDrawerControllerDrawerVisualStateBlock)parallax5VisualStateBlock {
    return [MMDrawerVisualState parallaxVisualStateBlockWithParallaxFactor:5.0];
}

+ (MMDrawerControllerDrawerVisualStateBlock)parallax7VisualStateBlock {
    return [MMDrawerVisualState parallaxVisualStateBlockWithParallaxFactor:7.0];
}

@end
