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
#import <QuartzCore/QuartzCore.h>
#import <math.h>

/*
 * MMDrawerController keeps centerContainerView private. Since NappDrawer ships
 * MMDrawerController with the module, exposing the existing getter locally is
 * safe and avoids modifying the upstream MMDrawerController source.
 */
@interface MMDrawerController (NappDrawerInternalAccess)
@property (nonatomic, strong, readonly) UIView *centerContainerView;
@end

@interface CustomMMDrawerController () {
  CADisplayLink *_slidingDisplayLink;
  MMDrawerSide _slidingSide;
  CGFloat _lastSlidingProgress;
  MMDrawerSide _lastSlidingEventSide;
  BOOL _hasLastSlidingProgress;
}

- (void)startSlidingTrackingForSide:(MMDrawerSide)side;
- (void)stopSlidingTracking;
- (void)finishSlidingTrackingForSide:(MMDrawerSide)side progress:(CGFloat)progress;
- (void)slidingDisplayLinkDidFire:(CADisplayLink *)displayLink;
- (void)emitSlidingProgressUsingPresentationLayer:(BOOL)usePresentationLayer force:(BOOL)force;
- (void)emitSlidingProgress:(CGFloat)progress side:(MMDrawerSide)side force:(BOOL)force;

@end

@implementation CustomMMDrawerController

#pragma mark - Existing open / close callbacks

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

- (void)setSlidingCallback:(void (^)(CGFloat progress, MMDrawerSide side))callback
{
  _slidingCallback = [callback copy];

  if (!_slidingCallback) {
    [self stopSlidingTracking];
  }
}

#pragma mark - Continuous sliding tracking

- (void)startSlidingTrackingForSide:(MMDrawerSide)side
{
  if (!_slidingCallback) {
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

  [self emitSlidingProgressUsingPresentationLayer:YES force:NO];
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
  if (side == MMDrawerSideNone) {
    side = _slidingSide;
  }

  if (_slidingCallback && side != MMDrawerSideNone) {
    [self emitSlidingProgress:progress side:side force:YES];
  }

  [self stopSlidingTracking];

  _slidingSide = MMDrawerSideNone;
  _hasLastSlidingProgress = NO;
  _lastSlidingEventSide = MMDrawerSideNone;
}

- (void)slidingDisplayLinkDidFire:(CADisplayLink *)displayLink
{
  [self emitSlidingProgressUsingPresentationLayer:YES force:NO];
}

- (void)emitSlidingProgressUsingPresentationLayer:(BOOL)usePresentationLayer
                                            force:(BOOL)force
{
  if (!_slidingCallback) {
    return;
  }

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

  if (side == MMDrawerSideNone) {
    return;
  }

  _slidingSide = side;

  // shouldStretchDrawer can make MMDrawerController exceed 1.0.
  // The Titanium API intentionally remains normalized.
  progress = MIN(MAX(progress, 0.0f), 1.0f);

  [self emitSlidingProgress:progress side:side force:force];
}

- (void)emitSlidingProgress:(CGFloat)progress
                       side:(MMDrawerSide)side
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
      fabs(progress - _lastSlidingProgress) > 0.0001f;

  if (force || changed) {
    _slidingCallback(progress, side);

    _lastSlidingProgress = progress;
    _lastSlidingEventSide = side;
    _hasLastSlidingProgress = YES;
  }
}

#pragma mark - Gesture tracking

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
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
    [self startSlidingTrackingForSide:self.openSide];
  }

  [super panGestureCallback:panGesture];

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
      [self stopSlidingTracking];
      _slidingSide = MMDrawerSideNone;
      _hasLastSlidingProgress = NO;
      _lastSlidingEventSide = MMDrawerSideNone;
    }
  }
}

#pragma mark - Programmatic / finishing animations

- (void)openDrawerSide:(MMDrawerSide)drawerSide
              animated:(BOOL)animated
              velocity:(CGFloat)velocity
      animationOptions:(UIViewAnimationOptions)options
            completion:(void (^)(BOOL finished))completion
{
  [self startSlidingTrackingForSide:drawerSide];

  [super openDrawerSide:drawerSide
               animated:animated
               velocity:velocity
       animationOptions:options
             completion:^(BOOL finished) {

               if (finished) {
                 [self finishSlidingTrackingForSide:drawerSide progress:1.0f];
               } else {
                 [self emitSlidingProgressUsingPresentationLayer:YES force:YES];
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

  [super closeDrawerAnimated:animated
                    velocity:velocity
            animationOptions:options
                  completion:^(BOOL finished) {

                    if (finished) {
                      [self finishSlidingTrackingForSide:closingSide progress:0.0f];
                    } else {
                      [self emitSlidingProgressUsingPresentationLayer:YES force:YES];
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
  [self stopSlidingTracking];

  _callback = nil;
  _slidingCallback = nil;

  _slidingSide = MMDrawerSideNone;
  _hasLastSlidingProgress = NO;
  _lastSlidingEventSide = MMDrawerSideNone;

  [super setGestureCompletionBlock:nil];
}

@end
