# NappDrawer Module

The iOS module requires iOS 18.0 or later. Build with an iOS 26+ SDK and set
your application's `<ios><min-ios-ver>18.0</min-ios-ver></ios>` accordingly.
Newer features, including concentric corners, retain runtime availability
checks and use their documented fallback on iOS 18–25.

## Description

Native side-drawer navigation for Titanium. iOS 3.6.6 adds scale controls and
stable rounded corners to the sheet, appearance, animation, resizing, haptics,
lifecycle, and gesture additions consolidated in 3.6.5. Android is unchanged.

## Accessing the NappDrawer Module

To access this module from JavaScript, you would do the following:

    var nappdrawer = require("dk.napp.drawer");

The nappdrawer variable is a reference to the Module object.

## Reference

### Minimum slide-scale amount (iOS 3.6.6+)

`animationMinScale` defaults to `0.90`, preserving the previous
`ANIMATION_SLIDE_SCALE` behavior. It also controls the new `ANIMATION_SCALE` mode.
It applies to the side drawer, not the center
window, for both shared and per-side animation modes. For example:

```javascript
drawer.animationMode = nappdrawer.ANIMATION_SLIDE_SCALE;
drawer.animationMinScale = 0.95;
```

The property also works in `createDrawer()`. Scale interpolates from the minimum
to 1 as opening progress reaches 1. Use 1 to disable scaling while retaining
translation/fading. Values clamp to 0–1; non-finite values reset to 0.90. Runtime
assignments are read on subsequent visual updates without rebuilding animation
blocks or clearing side overrides. Other modes are unaffected.

### Scale-only animation (iOS 3.6.6+)

```javascript
drawer.animationMode = nappdrawer.ANIMATION_SCALE;
drawer.animationMinScale = 0.95;
drawer.animationScaleFade = true; // Optional; default false keeps the side opaque.
```

The side scales in place without translation. The center still moves normally
to reveal it. `animationScaleFade` adds opacity animation with progress, for
`ANIMATION_SCALE` only; it does not alter the existing slide-scale mode's fade.
Works with `leftAnimationMode` / `rightAnimationMode` as well as the shared mode.
Properties can be set at creation or runtime; updates are read on subsequent
visual updates. Scale/fade progress is capped at 0–1 during overshoot.

### Native sheet integration

Set `followsPresentedSheet: true` to opt into coordination with a native
`UISheetPresentationController`. Call `attachPresentedSheet()` after presenting
a sheet and `detachPresentedSheet()` when it closes. `isAnySheetOpen()` queries
whether a native sheet is presented. No particular bottom-sheet module is required.

An attached center sheet follows drawer dragging, finishing animations,
programmatic transitions, and width resizing. During drawer movement or while a
drawer is open, its content/dimming surface is shielded from touches (including
second-finger touches), while drawer closing gestures remain available above it.
Side-drawer sheets are not automatically attached or shielded. Detaching restores
the original source view and module-owned transform/gesture state.

`presentedSheetEdgeWidth` defaults to 32 points per edge; use zero to disable
opening over an undimmed sheet. At dimmed detents, opening is programmatic-only.
This sheet shield has separate behavior from center-window bezel settings.

### Slide-gap and animation synchronization fixes

Left-side `ANIMATION_SLIDE` now pixel-aligns translation and temporarily overlaps
one physical pixel beneath the center to prevent the hairline seam. Fully open
geometry is unchanged. Attached sheets use the drawer's finishing-animation
duration/easing without competing display-link writes, reducing visible lag.

### Opening bezel width

Set `openDrawerGestureMode` to `OPEN_MODE_BEZEL_PANNING_CENTERWINDOW` and
`openDrawerBezelWidth: 40` to accept opening pans within 40 points of either
available drawer's screen edge. The default is 20 points. The property can also
be assigned at runtime. Zero disables bezel opening; negative values clamp to
zero, non-finite values reset to 20, and hit testing caps the width to the
container. Closing gestures are unchanged. Other enabled opening modes are
unrestricted by this width; attached-sheet zones use `presentedSheetEdgeWidth`.

### Closing bezel width (iOS 3.6.5+)

Use `closeDrawerGestureMode: NappDrawerModule.CLOSE_MODE_BEZEL_PANNING_CENTERWINDOW`
and `closeDrawerBezelWidth: 60`. The width is in points, defaults to 20, and is
independent of `openDrawerBezelWidth`; both support runtime assignments.
Zero disables that bezel mode only. Negative values clamp to zero, non-finite
values reset to 20, and hit testing caps the width to the container.
Closing starts at the right screen edge for an open left drawer, or the left
screen edge for an open right drawer, within visible center content and excluding
navigation bars. Broader enabled closing modes remain unrestricted. Separate
attached-sheet gesture-shield behavior is unchanged.

3.6.5 retains the 3.6.4 superclass window-close lifecycle fixes.

### Initial drawer side (iOS 3.6.3+)

Set `initialDrawerSide: 'left'` or `'right'` in `createDrawer()` to start with that
side open at its configured width. The default is `'center'`. Initial positioning
happens before presentation, without an opening animation, haptic, `sliding`, or
`drawerTransition` event. The center window is still required; a missing requested
side falls back to the center with a warning. This property is creation-time only;
later assignments do not move the drawer. Normal window lifecycle events remain.

### Haptics and drawer transitions (iOS 3.6.0+)

`hapticFeedback` defaults to `none`; use `gesture` for one impact at pan release
when the finishing animation chooses opening or closing. Use `all` to include
tap-to-close and programmatic transitions. `hapticStyle` defaults to `light` and
accepts `light`, `medium`, `heavy`, `soft`, or `rigid`. Configure either at creation
or afterward. Feedback is native, with no second completion impact; cancelled
pans, resizing, bounce previews, rejected requests, and no-op requests do not
vibrate. Haptic output depends on device capabilities and system settings.

`drawerTransition` reports `{state, side, source}` independently of haptics.
`state` is `opening` or `closing` at start, then `open` or `closed` upon successful
completion. `side` is `left` or `right`; `source` is `gesture` or `programmatic` and
is retained through completion. Tap-to-close and cancelled pans are gestures.
Resizing, bounce previews, rejected requests, and no-op requests do not produce
these events. Existing lifecycle events and sliding payloads are preserved.

### Width resizing and sliding geometry (iOS 3.5.0+)

The explicit `setLeftDrawerWidth()` / `setRightDrawerWidth()` JavaScript methods
require 3.6.1+. Earlier versions expose only the `leftDrawerWidth` /
`rightDrawerWidth` properties; assign `{width: number, animated: true}` to those
properties to request an animated change. The 3.6.1 method wrappers use that same
property-update path and also accept a numeric width.

Use 3.6.2 or later for these exports. The 3.6.1 wrappers force view creation during
creation-time property application; 3.6.2 removes that eager initialization to
avoid launch hierarchy exceptions while retaining the same method API.

`drawer.setLeftDrawerWidth({width: drawer.rect.width, animated: true})` expands
the open left drawer to full window width; use `setRightDrawerWidth` for the right.
Restore the previous width with the same method. Attached center sheets follow
the center with the same animation duration and easing. Independent side-drawer
sheets are unaffected. Closed-side changes do not generate resize events.

`sliding` retains `progress` (0–1) and `side` (`left`/`right`), adding `resizing`
(Boolean), `drawerWidth` (current animated width in points), and `centerOffset`
(signed center displacement in points: positive left, negative right).
A fully open drawer stays at `progress: 1` while resizing; its native border
remains visible. Completion emits a final `resizing: false` geometry event.
The latest width request made during movement is applied after movement finishes.
Pans and drawer open/close are blocked while the resize animation is active.

### Per-drawer animation modes (iOS 3.4.0+)

`leftAnimationMode` and `rightAnimationMode` optionally override `animationMode`
for their respective side. Set them at creation or afterward using the existing
animation constants. Unset values use the shared mode; assign `null` to clear an
override. Updating `animationMode` preserves any explicit overrides. Animation
velocity remains shared.

```javascript
drawer.leftAnimationMode = nappdrawer.ANIMATION_PARALLAX_FACTOR_7;
drawer.rightAnimationMode = nappdrawer.ANIMATION_SLIDE;
// Rejoin the shared mode:
drawer.leftAnimationMode = null;
```

### Center appearance (iOS)

Set these properties on the object returned by `createDrawer()`, at creation
or afterward. Defaults preserve square center corners without a border.

| Property | Default | Behavior |
| --- | --- | --- |
| `rootBackgroundColor` | `black` | Internal root behind all windows; `transparent` reveals the underlying views |
| `shadowRadius` | `10` | Shadow blur radius in points, clamped to zero or greater |
| `shadowColor` | `black` | Shadow color |
| `shadowOpacity` | `0.8` | Shadow opacity, clamped to 0–1 |
| `centerCornerMode` | `none` | `none`, `continuous`, or `concentric` |
| `centerCornerRadius` | `32` | Continuous radius in points; concentric fallback on older iOS, before attachment/layout, or when UIKit reports no positive radius |
| `centerBorderWidth` | `0` | Border width in points; zero disables it |
| `centerBorderColor` | `black` | Outline color |
| `centerBorderOpacity` | `1` | Outline opacity, clamped to 0–1 |
| `centerBorderFollowsSliding` | `false` | Native border fading: multiplies opacity by drawer progress |

`continuous` uses a smooth squircle-style curve. `concentric` uses UIKit's
container-concentric radius on iOS 26+, with uniform corners; older iOS uses
the continuous fallback. In 3.6.6, native measurement uses the center's aligned
resting geometry, not its translated position. The real center and border keep
that fixed radius during dragging, finishing animations, and resizing, including
`initialDrawerSide: 'left'` / `'right'`. Measurement refreshes on appearance/layout;
before attachment/layout, or when UIKit reports no positive radius, the configured
`centerCornerRadius` is used. No visible recentering or JavaScript startup query
is needed. This is not an API for reading the physical screen radius.

Rounding remains optional: omit `centerCornerMode` or set it to `'none'` for
square corners. Set `centerBorderWidth: 0` to disable the independent border.

```javascript
var drawer = nappdrawer.createDrawer({
  centerWindow: centerWindow,
  leftWindow: leftWindow,
  centerCornerMode: 'concentric',
  centerCornerRadius: 32,
  centerBorderWidth: 1,
  centerBorderColor: '#888',
  centerBorderOpacity: 0.8,
  centerBorderFollowsSliding: true
});
```

For custom animation, leave `centerBorderFollowsSliding` false and update
`centerBorderOpacity` in a `sliding` listener using `e.progress` (0–1).
For continuous corners, `centerCornerRadius` can also be updated with progress.
The clipping surface includes NavigationWindow content, the border does not
intercept touches, and the existing shadow stays outside the clipping surface.

Use `showShadow: true` to show the shadow. Its radius, color, and opacity can be
set at creation or updated afterward, and are retained when the shadow is hidden.
The existing shadow offset is unchanged.

`drawer.getCenterCornerRadius()` returns the currently resolved center corner
radius in UIKit points. Call it after the drawer opens and layout is available.
For iOS 26+ concentric mode it reports the applied stable aligned radius (or
the configured fallback), including when a side is open. It returns `0` when rounding is disabled
or the drawer is not attached to a window. This is the center's radius, not a
private getter for the physical display radius.

## Usage

See the bundled `example/app.js` for sheet attachment, styling, resizing,
haptics, per-side animations, startup-side selection, and bezel configuration.
Set `<module platform="iphone" version="3.6.6">dk.napp.drawer</module>` in your
application's `tiapp.xml`. The minimum Titanium SDK is 13.3.0.GA.

## Author

Originally developed by Napp ApS; see the repository README for maintainers.

## License

See the bundled LICENSE and the vendored dependency notices.

### 3.6.4: closing a drawer project

The drawer window now completes Titanium's superclass `windowWillClose` and `windowDidClose` lifecycle after its child-window/controller cleanup. It no longer recursively calls `close` from `windowDidClose` or emits a separate manual close event. This allows closing a drawer opened above another application window to return to the previous window. Validation in AlloyTestApp is recorded separately from build/package checks.
