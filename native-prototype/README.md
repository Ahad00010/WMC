# WMC native prototype

An independent Godot 4.4.1 project, not an APK WebView and not a replacement for the existing game. It is a **performance/feel prototype**, not a complete game. It uses the existing Sepang centreline, Ducati and rider assets; the road geometry and controls are deliberately simplified and are not a port of the authoritative multiplayer physics.

## Test it

The `Build native prototype` GitHub Actions workflow builds a Windows EXE and an Android debug APK. Download the two named artifacts from a successful workflow run. The Android debug APK is signed with a CI-generated debug key, so it is for testing, not Play Store release; a later CI run may not install over an earlier one unless you uninstall it first. Windows may show a SmartScreen warning for an unsigned EXE. Back up any device data before uninstalling. This prototype does not connect to accounts or award points.

Use W / up for gas, S / down to brake and A/D or arrows to steer on Windows. On Android, use the on-screen buttons. Start/restart puts the bike at the start; the results button previews a simple results layout. The FPS counter is the native game frame rate.

Toggle **REPLAY VIEW** while driving to render a second live camera view at a target of 24 fps (up to 1080p on PC, 480p on mobile). Compare FPS with it on and off on the same section of track. It is deliberately off by default.

**Important:** This only measures the extra camera rendering cost. It does **not** encode, record, share, or play video, so it cannot establish whether the real replay will run smoothly. Native cross-platform hardware video encoding and real finish footage must be implemented and measured separately; this prototype does not fake a replay from positions. The results screen is a static visual preview, not the original animated results or Marc scene. There are no opponents, lap timing, networking, collision rules, championship, menus or audio yet. Use it to decide whether a full migration is worth pursuing, not as a replacement for the current game.

## Local build

Open `native-prototype/project.godot` with Godot 4.4.1. Install the matching export templates and Android SDK/JDK 17 in Godot editor settings, then export using the Windows and Android presets. The GitHub workflow documents a repeatable CI build.

The opening screen and soundtrack are native approximations of the web menu. Play starts the prototype immediately. Hold Space for hard braking; controls use no keyboard focus to prevent Space activating UI buttons. The camera now banks subtly with the bike as in the web game. The native Google sign-in uses your system browser and PKCE, keeping tokens only in memory and retrieving your existing rider profile; new profiles must be created in the web game. It uses an app-local callback on port 18674, so browser or device restrictions may affect it and real Windows/Android sign-in testing is required. Signing out clears the prototype's in-memory token; your browser's Google session is not signed out.
