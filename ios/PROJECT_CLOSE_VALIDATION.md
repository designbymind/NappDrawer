# NappDrawer 3.6.4 project-close validation

Recorded 2026-10-14. Titanium SDK 13.4.1.GA; Xcode 27.1 beta; existing iOS 27 iPhone 18 Pro simulator.

The app-local package was built from an isolated copy of the current NappDrawer-sheet-integration checkout, using the same native source and manifest with a build-only titanium.xcconfig SDK override to 13.4.1.GA. Existing unrelated checkout edits were preserved. ZIP integrity, embedded manifest and iOS device arm64 / simulator arm64+x86_64 / Catalyst arm64+x86_64 slices were verified.

Direct Device Hub UI checks in AlloyTestApp passed:

- Open Drawer from the launcher; allow its native sheet to appear; tap Projects; verify the main chooser is visible.
- Reopen Drawer and return again. Each observed open/close cycle has a matching native project-close callback.
- Open Keyboard control, open a chat layout, return to the project entry and then the main chooser.
- Reopen Keyboard control and return again.

AlloyTestApp uses modules/iphone/dk.napp.drawer/3.6.4 and pins that version in tiapp.xml. The global module registry was not modified. Keyboard-control packages were not changed for this test-host restructuring. These checks establish project navigation and reopening, not a new full regression of drawer gestures or keyboard/composer behavior.

Package SHA-256: 1a6fa7b569189c8fb5ef7f19873f29ea5922f7cb33f14273c78625b4a54f0b64
