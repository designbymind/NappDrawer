# Titanium Napp Drawer Module

[![gitTio](http://gitt.io/badge.svg)](http://gitt.io/component/dk.napp.drawer)
[![NPM](https://img.shields.io/npm/v/ti-module-dk.napp.drawer.svg?style=flat-square)](https://www.npmjs.com/package/ti-module-dk.napp.drawer)

<img src="./example-cross-platform.jpg" alt="Cross Platform Example (iOS / Android)" width="800" />

## Description

The **Napp Drawer** module extends the Appcelerator Titanium Mobile framework with a cross-platform side-drawer navigation component. It provides a familiar sliding menu pattern used by popular apps like Facebook, Gmail, and LinkedIn.

**Platform Implementation:**
- **iOS**: Based on [MMDrawerController](https://github.com/MortimerGoro/MMDrawerController) — supports left, right, and center panels with smooth animations
- **Android**: Based on [SlidingMenu](https://github.com/jfeinstein10/SlidingMenu) — supports left and right panels with customizable animations

**Cross-Platform Parity:** Despite different underlying implementations, the API is consistent across platforms. Use the same properties and methods on both iOS and Android.

---

## Quick Start

For the cumulative iOS changes through 3.6.6, compatibility notes, and
validation limits, see [CHANGELOG.md](CHANGELOG.md). Download the iOS ZIP from
the repository's GitHub Releases; intermediate local build ZIPs are not published.

### Basic Usage

```javascript
var NappDrawer = require('dk.napp.drawer');
var drawer = NappDrawer.createDrawer({
  leftWindow: leftWin,
  centerWindow: centerWin,
  leftDrawerWidth: 280,
  animationMode: NappDrawer.ANIMATION_SLIDE
});

drawer.openLeftWindow();
```

---

## API Reference

### Module Constants

#### Animation Modes

| Constant | Value | Description |
|----------|-------|-------------|
| `ANIMATION_SLIDE_SCALE` | `1` | Side drawer slides, fades, and scales from `animationMinScale` to 1 as it opens |
| `ANIMATION_SLIDE` | `2` | Horizontal slide animation |
| `ANIMATION_PARALLAX_FACTOR_3` | `4` | Parallax with factor 3.0 |
| `ANIMATION_PARALLAX_FACTOR_5` | `5` | Parallax with factor 5.0 |
| `ANIMATION_PARALLAX_FACTOR_7` | `6` | Parallax with factor 7.0 |
| `ANIMATION_FADE` | `7` | Fade animation |
| `ANIMATION_SCALE` | `8` | iOS: side-drawer scaling only, with optional `animationScaleFade`; no side-drawer translation |
| `ANIMATION_NONE` | `100` | No animation |

> **Note:** New 3.6.6 scale configuration is iOS-only; Android animation behavior is unchanged.

#### Open/Close Gesture Modes

| Constant | iOS | Android | Description |
|----------|-----|---------|-------------|
| `CLOSE_MODE_NONE` | `MMCloseDrawerGestureModeNone` | `TOUCHMODE_NONE` | No gesture to close |
| `CLOSE_MODE_ALL` | `MMCloseDrawerGestureModeAll` | `TOUCHMODE_FULLSCREEN` | Tap/pan anywhere to close |
| `CLOSE_MODE_PANNING_NAVBAR` | `MMCloseDrawerGestureModePanningNavigationBar` | — | Pan navigation bar to close |
| `CLOSE_MODE_PANNING_CENTERWINDOW` | `MMCloseDrawerGestureModePanningCenterView` | — | Pan center view to close |
| `CLOSE_MODE_BEZEL_PANNING_CENTERWINDOW` | `MMCloseDrawerGestureModeBezelPanningCenterView` | — | Pan bezel area to close |
| `CLOSE_MODE_TAP_NAVBAR` | `MMCloseDrawerGestureModeTapNavigationBar` | — | Tap navigation bar to close |
| `CLOSE_MODE_TAP_CENTERWINDOW` | `MMCloseDrawerGestureModeTapCenterView` | — | Tap center view to close |
| `CLOSE_MODE_PANNING_DRAWER` | `MMCloseDrawerGestureModePanningDrawerView` | — | Pan drawer view to close |
| `OPEN_MODE_ALL` | `MMOpenDrawerGestureModeAll` | `TOUCHMODE_FULLSCREEN` | Any gesture to open |
| `OPEN_MODE_PANNING_NAVBAR` | `MMOpenDrawerGestureModePanningNavigationBar` | `TOUCHMODE_MARGIN` | Pan navigation bar to open |
| `OPEN_MODE_PANNING_CENTERWINDOW` | `MMOpenDrawerGestureModePanningCenterView` | — | Pan center view to open |
| `OPEN_MODE_BEZEL_PANNING_CENTERWINDOW` | `MMOpenDrawerGestureModeBezelPanningCenterView` | — | Pan bezel area to open |

#### Status Bar Styles

| Constant | Value | Description |
|----------|-------|-------------|
| `STATUSBAR_BLACK` | `UIStatusBarStyleDefault` | Dark status bar text |
| `STATUSBAR_WHITE` | `UIStatusBarStyleLightContent` | Light status bar text |

#### Status Bar Animation

| Constant | Value | Description |
|----------|-------|-------------|
| `STATUSBAR_ANIMATION_NONE` | `0` | No animation |
| `STATUSBAR_ANIMATION_FADE` | `1` | Fade animation |
| `STATUSBAR_ANIMATION_SLIDE` | `2` | Slide animation |

---

### Properties

The iOS module requires iOS 18.0 or later. Build with Xcode using an iOS 26+
SDK; newer APIs remain availability-guarded for iOS 18–25 compatibility.
The manifest's `minsdk` specifies the minimum Titanium SDK, not the iOS version.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `leftWindow` | TiViewProxy | `null` | Left drawer window/view proxy |
| `rightWindow` | TiViewProxy | `null` | Right drawer window/view proxy |
| `centerWindow` | TiViewProxy | `null` | Center content window/view proxy |
| `initialDrawerSide` | String | `center` | iOS 3.6.3+. Creation-time selection: `center`, `left`, or `right`. Positions the side before presentation without animation or haptic; missing side windows fall back to center |
| `leftDrawerWidth` | Number/String | `-100` | Left drawer width in pixels or dimension string (e.g., `"280dp"`) |
| `rightDrawerWidth` | Number/String | `-100` | Right drawer width in pixels or dimension string |
| `openDrawerGestureMode` | Number | `OPEN_MODE_ALL` | Gesture mode for opening the drawer |
| `openDrawerBezelWidth` | Number | `20` | iOS only. Opening bezel width in points for `OPEN_MODE_BEZEL_PANNING_CENTERWINDOW`; adjustable at runtime. `0` disables bezel opening; negative values clamp to zero. Does not restrict broader opening modes or change closing gestures. Sheet edge zones use `presentedSheetEdgeWidth` separately |
| `closeDrawerGestureMode` | Number | `CLOSE_MODE_ALL` | Gesture mode for closing the drawer |
| `closeDrawerBezelWidth` | Number | `20` | iOS 3.6.5+. Closing bezel width in points for `CLOSE_MODE_BEZEL_PANNING_CENTERWINDOW`; adjustable at runtime. `0` disables bezel closing only. Independent of `openDrawerBezelWidth`; broader closing modes remain unrestricted |
| `animationMode` | Number | `ANIMATION_SLIDE` | Animation mode for drawer transitions |
| `animationMinScale` | Number | `0.90` | iOS 3.6.6+. Minimum side-drawer scale for `ANIMATION_SLIDE_SCALE` and `ANIMATION_SCALE`, including per-side overrides. Interpolates to 1 as the drawer opens. Runtime changes apply on subsequent visual updates. Clamped to 0–1; non-finite values reset to 0.90. Does not scale the center window or affect other modes |
| `animationScaleFade` | Boolean | `false` | iOS 3.6.6+. Optional opacity animation for `ANIMATION_SCALE` only. `false` keeps the side drawer opaque; `true` fades with opening progress. Shared and per-side modes read runtime updates. Does not change the existing fade in `ANIMATION_SLIDE_SCALE` |
| `leftAnimationMode` | Number/null | unset | iOS only. Optional left-side animation override; unset or `null` uses `animationMode` |
| `rightAnimationMode` | Number/null | unset | iOS only. Optional right-side animation override; unset or `null` uses `animationMode` |
| `animationVelocity` | Number | `1.0` | Animation velocity factor |
| `shouldStretchDrawer` | Boolean | `false` | Enable elastic stretch effect on drawer |
| `showShadow` | Boolean | `true` | Show shadow behind drawer |
| `hapticFeedback` | String | `none` | iOS only. `none`, `gesture` (pan release), or `all` (pan release, tap-to-close, and programmatic transitions) |
| `hapticStyle` | String | `light` | iOS only. `light`, `medium`, `heavy`, `soft`, or `rigid` native impact feedback |
| `shadowRadius` | Number | `10` | iOS only. Shadow blur radius in points, clamped to zero or greater |
| `shadowColor` | Color | `black` | iOS only. Shadow color; supports Titanium color strings |
| `shadowOpacity` | Number | `0.8` | iOS only. Shadow opacity, clamped to 0–1; retained while `showShadow` is false |
| `shadowWidth` | Number/String | `0` | Shadow width in pixels or dimension string |
| `fading` | Number | `0.0` | Fade degree (0.0–1.0) for center view when drawer is open |
| `parallaxAmount` | Number | `0.0` | Parallax scroll scale (0.0–1.0) |
| `showStatusBarView` | Boolean | `true` | Show status bar background view |
| `statusBarStyle` | Number | `STATUSBAR_BLACK` | Status bar text color style |
| `centerHiddenInteractionMode` | Number | — | Interaction mode when center is hidden |
| `autoCloseWindows` | Boolean | `true` | Automatically close windows on drawer close |
| `followsPresentedSheet` | Boolean | `false` | iOS only. Opt in to native `UISheetPresentationController` coordination |
| `presentedSheetEdgeWidth` | Number | `32` | iOS only. Width of each undimmed-sheet edge zone; use `0` to disable drag-to-open over sheets |
| `backgroundColor` | TiBlob | — | Background color of the drawer view |
| `rootBackgroundColor` | Color | `black` | iOS only. Internal drawer root background, visible behind rounded or transparent child content. `transparent` reveals views underneath; it does not change touch handling |
| `centerCornerMode` | String | `none` | iOS only. `none`, `continuous` (smooth squircle-style corners), or `concentric` (3.6.6: resolve UIKit's aligned radius on iOS 26+ and hold it fixed during movement, including initial left/right startup; continuous fallback on older iOS) |
| `centerCornerRadius` | Number | `32` | iOS only. Radius in points for `continuous`; fallback for `concentric` on older iOS, before attachment/layout, or when UIKit reports no positive radius. Values below zero clamp to zero |
| `centerBorderWidth` | Number | `0` | iOS only. Center outline width in points; zero disables the border |
| `centerBorderColor` | Color | `black` | iOS only. Color of the center outline |
| `centerBorderOpacity` | Number | `1` | iOS only. Outline opacity, clamped to 0–1 |
| `centerBorderFollowsSliding` | Boolean | `false` | iOS only. Natively multiply outline opacity by drawer progress; hidden when closed, fully visible when open |
| `hamburgerIcon` | Boolean | `false` | Show hamburger icon on Android |
| `hamburgerIconColor` | String | `null` | Custom hamburger icon color (hex string) |
| `arrowAnimation` | Boolean | `false` | Animate hamburger icon to arrow on Android |
| `orientationModes` | Array | — | Supported orientation modes |

---

### Methods

#### Window Management

| Method | Parameters | Description |
|--------|-----------|-------------|
| `openLeftWindow(animated)` | `animated` (Boolean, optional) | Open the left drawer |
| `openRightWindow(animated)` | `animated` (Boolean, optional) | Open the right drawer |
| `closeLeftWindow(animated)` | `animated` (Boolean, optional) | Close the left drawer |
| `closeRightWindow(animated)` | `animated` (Boolean, optional) | Close the right drawer |
| `closeWindows(animated)` | `animated` (Boolean, optional) | Close all open drawers |
| `toggleLeftWindow(animated)` | `animated` (Boolean, optional) | Toggle left drawer open/closed |
| `toggleRightWindow(animated)` | `animated` (Boolean, optional) | Toggle right drawer open/closed |
| `setLeftDrawerWidth(width)` | Number or `{width, animated}` | iOS 3.6.1+. Set left width through the same path as `leftDrawerWidth` property assignment |
| `setRightDrawerWidth(width)` | Number or `{width, animated}` | iOS 3.6.1+. Set right width through the same path as `rightDrawerWidth` property assignment |
| `bounceLeftWindow(animated)` | `animated` (Boolean, optional) | Bounce open the left drawer |
| `bounceRightWindow(animated)` | `animated` (Boolean, optional) | Bounce open the right drawer |

#### State Queries

| Method | Returns | Description |
|--------|---------|-------------|
| `isLeftWindowOpen()` | Boolean | Check if left drawer is open |
| `isRightWindowOpen()` | Boolean | Check if right drawer is open |
| `isAnyWindowOpen()` | Boolean | Check if any drawer is open |
| `isAnySheetOpen()` | Boolean | iOS only. Check if any native sheet is currently presented |
| `getCenterCornerRadius()` | Number | iOS only. Current resolved center radius in points. Returns `0` when rounding is disabled or the drawer is not attached to a window |
| `getRealLeftViewWidth()` | Number | Get actual left drawer width in pixels |
| `getRealRightViewWidth()` | Number | Get actual right drawer width in pixels |

#### Status Bar (iOS)

| Method | Parameters | Description |
|--------|-----------|-------------|
| `showStatusBar(animationStyle)` | `animationStyle` (Number, optional) | Show the status bar |
| `hideStatusBar(animationStyle)` | `animationStyle` (Number, optional) | Hide the status bar |
| `setStatusBarStyle(style)` | `style` (Number) | Set status bar text color |

#### Native Sheet Integration (iOS)

| Method | Description |
|--------|-------------|
| `attachPresentedSheet()` | Attach the currently presented native `UISheetPresentationController` to the drawer's center panel |
| `detachPresentedSheet()` | Restore the native sheet's original source view and presentation-container transform |
| `isAnySheetOpen()` | Return whether any native `UISheetPresentationController` is currently presented |

Native sheet integration is opt-in and has no dependency on a particular
bottom-sheet module. NappDrawer discovers the currently presented
`UISheetPresentationController`, uses the center panel as its public
`sourceView` when supported, and synchronizes the public presentation
container with the center panel during drawer movement.

While the drawer is closed at an undimmed sheet detent, the attached sheet keeps
its normal interactions and NappDrawer reserves narrow left and right edge-swipe
zones for opening a drawer. At a dimmed detent, drag-to-open is disabled and the
drawer can only be opened programmatically. While that drawer is moving or open,
the attached sheet's content and dimming surface are temporarily shielded from
touches and NappDrawer's pan and tap recognizers remain available above it for
closing. Detaching restores the sheet and recognizers. Sheets presented
independently from a left or right drawer are not attached or shielded
automatically.

```javascript
const drawer = NappDrawer.createDrawer({
  centerWindow,
  leftWindow,
  followsPresentedSheet: true,
  presentedSheetEdgeWidth: 32
});

sheet.addEventListener('open', () => {
  drawer.attachPresentedSheet();
  Ti.API.info('Any sheet open: ' + drawer.isAnySheetOpen());
});

sheet.addEventListener('close', () => {
  drawer.detachPresentedSheet();
});
```

The explicit lifecycle methods are recommended because the sheet may be
presented after the drawer is created. When integration is disabled and neither
method is called, existing NappDrawer behavior is unchanged.

Set `presentedSheetEdgeWidth` to `0` to opt out of sheet-edge drawer opening
entirely. The property can also be changed at runtime. It has no effect at a
dimmed detent, where interactive drawer opening is always disabled.

---

### Events

| Event | Data | Description |
|-------|------|-------------|
| `windowDidOpen` | `{}` | Fired when a side drawer is opened; query `isLeftWindowOpen()` / `isRightWindowOpen()` for the side |
| `windowDidClose` | `{}` | Fired when a drawer is closed |
| `sliding` | `{progress, side, resizing, drawerWidth, centerOffset}` | Fired during drawer movement and open-drawer resizing. Progress remains 0–1; geometry is in UIKit points. A fully open resize keeps progress at 1 |
| `drawerTransition` | `{state, side, source}` | iOS only. State is `opening`/`closing` at transition start, then `open`/`closed` on successful completion; source is `gesture` or `programmatic` |
| `close` | — | Titanium drawer-window close event, not a side-panel close event |
| `focus` | — | Window focus event |
| `blur` | — | Window blur event |
| `open` | — | Window open event |

---

## Examples

### Basic Left Drawer

```javascript
var NappDrawer = require('dk.napp.drawer');

var leftWin = Ti.UI.createWindow({
  backgroundColor: '#333'
});

var centerWin = Ti.UI.createWindow({
  backgroundColor: '#fff'
});

var drawer = NappDrawer.createDrawer({
  leftWindow: leftWin,
  centerWindow: centerWin,
  leftDrawerWidth: 280,
  animationMode: NappDrawer.ANIMATION_SLIDE
});

drawer.openLeftWindow();
```

### Left + Right Drawer

```javascript
var leftWin = Ti.UI.createWindow({ backgroundColor: '#333' });
var rightWin = Ti.UI.createWindow({ backgroundColor: '#666' });
var centerWin = Ti.UI.createWindow({ backgroundColor: '#fff' });

var drawer = NappDrawer.createDrawer({
  leftWindow: leftWin,
  rightWindow: rightWin,
  centerWindow: centerWin,
  leftDrawerWidth: 280,
  rightDrawerWidth: 280,
  animationMode: NappDrawer.ANIMATION_PARALLAX_FACTOR_5
});

drawer.addEventListener('windowDidOpen', function(e) {
  Ti.API.info('Opened: ' + (drawer.isLeftWindowOpen() ? 'left' : 'right'));
});
```

### Hamburger Icon (Android)

```javascript
var drawer = NappDrawer.createDrawer({
  leftWindow: leftWin,
  centerWindow: centerWin,
  hamburgerIcon: true,
  hamburgerIconColor: '#ffffff',
  arrowAnimation: true
});
```

---

## Platform Differences

| Feature | iOS | Android |
|---------|-----|---------|
| Base Library | MMDrawerController | SlidingMenu |
| Panel Types | Windows | Views |
| Right Drawer | ✅ | ✅ |
| Parallax | ✅ (3.0, 5.0, 7.0) | ✅ (via parallaxAmount) |
| Bounce Animation | ✅ | ✅ |
| Hamburger Icon | ❌ | ✅ |
| Status Bar APIs | ✅ | ❌ |
| Orientation Modes | ✅ | ✅ |

---

## Requirements

- **Titanium SDK (iOS)**: 13.3.0.GA+ (release build: 13.4.1.GA)
- **iOS**: 18.0+; build using an iOS 26+ SDK
- **Android**: API 21+

---

## License

MIT License — Copyright (c) 2010-2013 Napp ApS  
Modified by Marc Bender

See [LICENSE](LICENSE) for details.

---

## Community

Contributions welcome! Please submit Pull Requests.

**Author:** Mads Møller  
web: http://www.napp.dk  
email: mm@napp.dk  
twitter: @nappdev

**Maintainer:** Marc Bender

### 3.6.4: closing a drawer project

The drawer window now completes Titanium's superclass `windowWillClose` and `windowDidClose` lifecycle after its child-window/controller cleanup. It no longer recursively calls `close` from `windowDidClose` or emits a separate manual close event. This allows closing a drawer opened above another application window to return to the previous window. Validation in AlloyTestApp is recorded separately from build/package checks.

### 3.6.5: independent opening and closing bezel widths

Includes the 3.6.4 window-close lifecycle fixes and configurable
`openDrawerBezelWidth` / `closeDrawerBezelWidth` (both default to 20 points).
These widths affect their respective bezel-pan modes only, not broader enabled
gesture modes. Existing attached-sheet gesture-shield behavior is unchanged.

### 3.6.6: scale controls and stable rounded corners

Add `animationMinScale` (default `0.90`) for `ANIMATION_SLIDE_SCALE` and the new
`ANIMATION_SCALE` mode. The latter scales without side-drawer translation;
`animationScaleFade: true` optionally adds fading (default `false`). All support
the shared/per-side animation paths and runtime updates. Existing modes retain
their behavior, including slide-scale translation/fading.

Opt-in `centerCornerMode: 'concentric'` now resolves the aligned center radius
natively, then applies that fixed radius to the moving center, border, and
shadow. This avoids corners flattening during movement, including startup with
`initialDrawerSide: 'right'`. No JavaScript radius capture is required. Omit the
corner mode or use `'none'` to keep square corners. See the changelog and iOS
README for geometry fallback and validation details.
