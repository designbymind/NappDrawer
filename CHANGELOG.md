# Changelog

## iOS 3.6.5

This is the first published release after iOS 3.2.1. It consolidates the local
3.3.0–3.6.5 development builds; those intermediate versions are not separate
GitHub releases. Android source and packages are unchanged.

### Native sheet integration

- Add opt-in `followsPresentedSheet`, `attachPresentedSheet()`,
  `detachPresentedSheet()`, and `isAnySheetOpen()` for native
  `UISheetPresentationController` sheets, without a bottom-sheet-module dependency.
- Synchronize an attached sheet with the center panel during dragging, finishing
  animations, programmatic opening/closing, and animated drawer-width changes.
  Finishing animations use the drawer's duration/easing instead of competing
  display-link transform updates, reducing sheet lag.
- Shield attached-sheet content and dimming surfaces while the drawer moves or
  remains open, including second-finger interactions; keep drawer closing gestures
  available above the sheet. Independently presented side-drawer sheets are not
  automatically attached or shielded.
- Add `presentedSheetEdgeWidth` (32 points by default, zero to disable). Edge
  opening is available only at undimmed detents; dimmed sheets require
  programmatic drawer opening. The sheet shield has its own gesture behavior,
  separate from the center-window bezel widths.
- Restore the sheet's previous source view/owned transform when detaching and
  clean up display links, recognizers, callbacks, and presentation state.

### Geometry, appearance, and animations

- Fix the left-side `ANIMATION_SLIDE` hairline gap using pixel-aligned translation
  and a temporary one-physical-pixel overlap; fully open geometry stays unchanged.
- Add `rootBackgroundColor` (black by default). `transparent` reveals underlying
  views; it does not change touch handling or eliminate geometry gaps by itself.
- Add optional `centerCornerMode` (`none`, `continuous`, `concentric`),
  `centerCornerRadius`, `centerBorderWidth`, `centerBorderColor`,
  `centerBorderOpacity`, and `centerBorderFollowsSliding`. Defaults keep square
  corners and no border. Clip the complete center content, including navigation
  bars, while keeping the shadow outside and the border non-interactive.
- On iOS 26+, concentric mode uses UIKit container-relative corner geometry;
  iOS 18–25 use the continuous-radius fallback. This is not a private physical
  display-radius API. `getCenterCornerRadius()` reads the resolved center radius
  after attachment/layout, or zero when disabled/unattached.
- Add `shadowRadius` (10), `shadowColor` (black), and `shadowOpacity` (0.8),
  retaining settings when `showShadow` is disabled; the existing offset stays.
- Add optional `leftAnimationMode` / `rightAnimationMode` overrides (3.4.0 local
  milestone). Unset or `null` uses shared `animationMode`; velocity stays shared.
- Extend animated open-drawer resizing (3.5.0 local milestone) so the center,
  attached sheet, border, and `sliding` geometry remain coordinated. Defer the
  latest width request during movement and block competing transitions/pans
  while resizing.

### JavaScript API and lifecycle

- Extend `sliding` without removing `progress` or `side`: add `resizing`,
  `drawerWidth`, and signed `centerOffset`, in UIKit points. Fully open resizing
  keeps progress at one and finishes with `resizing: false`.
- Add native opt-in `hapticFeedback` (`none`, `gesture`, `all`) and `hapticStyle`
  (`light`, `medium`, `heavy`, `soft`, `rigid`) at the finishing-animation handoff
  (3.6.0 local milestone). Do not emit a second completion impact or vibrate for
  cancelled pans, resizing, bounce previews, or rejected/no-op requests.
- Add `drawerTransition` events with `{state, side, source}`. States are
  `opening`, `closing`, `open`, `closed`; source is `gesture` or `programmatic`.
  Transition events are independent of whether haptics are enabled.
- Export explicit `setLeftDrawerWidth()` / `setRightDrawerWidth()` methods
  accepting a number or `{width, animated}` (3.6.1 local milestone). The 3.6.2
  correction stores creation-time values without eagerly creating native views,
  avoiding the 3.6.1 launch hierarchy exception. Use 3.6.2 or newer, not 3.6.1.
- Add creation-time `initialDrawerSide` (`center`, `left`, `right`; default
  `center`) in 3.6.3. Position before presentation without opening animation,
  haptics, `sliding`, or `drawerTransition`; a missing side falls back to center.
  Preserve normal window lifecycle events and controller containment order.
- Preserve the 3.6.4 window-close fix: complete Titanium's superclass
  `windowWillClose` / `windowDidClose` after child cleanup, remove recursive
  `close()` and duplicate manual close-event emission, and return correctly to
  the previous application window.
- Add independent `openDrawerBezelWidth` and `closeDrawerBezelWidth`, both
  defaulting to 20 points and supporting runtime updates. They affect only their
  respective `*_MODE_BEZEL_PANNING_CENTERWINDOW` bits. Zero disables that bezel
  bit; broader enabled modes remain unrestricted. Negative widths clamp to zero,
  non-finite widths reset to 20, and hit testing caps widths to container width.
  Closing uses the right screen edge for an open left drawer and vice versa,
  intersected with exposed center content and excluding navigation bars.

### Requirements, examples, and validation

- Raise the iOS deployment target to 18.0; develop/build using an iOS 26+ SDK.
  The minimum Titanium SDK remains 13.3.0.GA. Update Xcode project settings for
  the current toolchain; newer UIKit APIs retain runtime availability guards.
- Expand the Classic example with a native sheet, sheet attachment lifecycle,
  resize controls, animation overrides, appearance, haptics, startup-side, and
  bezel settings. The example's `OPEN_MODE_ALL` / `CLOSE_MODE_ALL` deliberately
  allow broad panning; select bezel modes to try custom bezel widths.
- Document the public APIs in the root README, iOS README, and packaged docs.
- Native compilation/package checks cover device arm64, simulator arm64/x86_64,
  and Catalyst arm64/x86_64. These do not establish full interactive correctness.
  Historical project navigation/reopening checks are recorded separately in
  [ios/PROJECT_CLOSE_VALIDATION.md](ios/PROJECT_CLOSE_VALIDATION.md). The newly
  configurable bezel widths still require simulator/device gesture validation.

## iOS 3.2.1 (previous published baseline)

- Preserve vertical TableView scrolling and horizontal row actions: swipe left
  in the right drawer or right in the left drawer while reserving the opposite
  horizontal direction for drawer closing.
- Keep the existing continuous `sliding` event and opening gestures. The earlier
  continuous-event work is already in the cloned baseline, not a new 3.6.5 API.
