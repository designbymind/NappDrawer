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
typedef void (^DrawerSlidingChangeBlock)(CGFloat progress, MMDrawerSide side);

@interface CustomMMDrawerController : MMDrawerController {
  WindowAppearanceChangeBlock _callback;
  DrawerSlidingChangeBlock _slidingCallback;
}

- (void)setWindowAppearanceCallback:(void (^)(NSString *))callback;
- (void)setSlidingCallback:(void (^)(CGFloat progress, MMDrawerSide side))callback;

// Cleanup callbacks / display-link tracking to avoid retain cycles.
- (void)clearWindowAppearanceCallback;

@end
