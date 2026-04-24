# Nodex

Nodex is a native macOS SwiftUI notch app forked from the boringNotch codebase. This fork keeps the native panel, motion, hover debounce, haptics, pan gestures, and media playback plumbing, while replacing the primary notch surface with the Nodex media control flow.

## Scope

- Closed media notch: `286x34`
- Hover compact media notch: `312x73`
- Expanded media controls: `364x249`
- Expanded media controls with lyrics: `364x376`

Non-v1 surfaces such as shelf-first drag behavior, calendar, mirror, and HUD replacement remain in the source for later reuse, but the main notch experience is focused on media control.

## Build

Open `nodex.xcodeproj` in Xcode 16 or later and run the `nodex` scheme.

```bash
xcodebuild -project nodex.xcodeproj -scheme nodex -configuration Debug build
```

The local bundle identifier defaults to `com.nodex.app`.
