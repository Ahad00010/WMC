# WMC native prototype

An independent Godot 4.4.1 project, not an APK WebView and not a replacement for the existing game. It is a **performance/feel prototype**, not a complete game. It uses the existing Sepang centreline, Ducati and rider assets; the road geometry and controls are deliberately simplified and are not a port of the authoritative multiplayer physics.

## Test it

The `Build native prototype` GitHub Actions workflow builds a Windows EXE and an Android debug APK. Download the two named artifacts from a successful workflow run. The Android debug APK is signed with a CI-generated debug key, so it is for testing, not Play Store release; a later CI run may not install over an earlier one unless you uninstall it first. Windows may show a SmartScreen warning for an unsigned EXE. Back up any device data before uninstalling. This prototype can read the signed-in rider profile, but it does not award points.

Use W / up for gas, S / down to brake, Space for hard braking, and A/D or arrows to steer on Windows. Press Escape to pause or resume. Android uses on-screen driving controls and a pause button. The pause menu offers Resume and Main Menu. The FPS counter is the native game frame rate. The engine sound is synthesized from the same waveform and RPM formula as the website; the menu sound toggle controls both engine and music.

**Important:** The prototype still does **not** encode, record, share, or play replay video. Native cross-platform video encoding and real finish footage must be implemented and measured separately; this prototype does not fake a replay from positions. There are no opponents, lap timing, networking, collision rules, championship or finished results yet. Use it to decide whether a full migration is worth pursuing, not as a replacement for the current game.

## Local build

Open `native-prototype/project.godot` with Godot 4.4.1. Install the matching export templates and Android SDK/JDK 17 in Godot editor settings, then export using the Windows and Android presets. The GitHub workflow documents a repeatable CI build.

The opening screen and soundtrack are native approximations of the web menu. Play starts the prototype immediately. Hold Space for hard braking; controls use no keyboard focus to prevent Space activating UI buttons. The camera now banks subtly with the bike as in the web game. The native Google sign-in uses your system browser and PKCE, keeping tokens only in memory and retrieving your existing rider profile; new profiles must be created in the web game. It uses an app-local callback on port 18674, so browser or device restrictions may affect it and real Windows/Android sign-in testing is required. Signing out clears the prototype's in-memory token; your browser's Google session is not signed out.
