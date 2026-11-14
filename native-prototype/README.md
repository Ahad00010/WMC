# WMC native race prototype

A clean Godot 4 rebuild for Windows and Android. This is a separate project under `native-prototype/`; it does not load, edit, embed, or otherwise change the existing web game.

## Stage 1 — implemented

- A playable **three-lap practice race** with a player rider and **nine AI riders**.
- Shared bike movement for player and AI: throttle, braking, steering, lean, kerb/runoff grip loss, barriers, and rider-to-rider contact pushes. AI has no teleport or speed bypass.
- Native, generated track surfaces and barriers using the supplied centre-line data for **all six circuits**: Sepang, Silverstone, Assen, Brno, Monza, and Jerez. Use **F1–F6** to switch during this prototype stage.
- Keyboard driving: **WASD** or **arrow keys**; **Space** brakes; **R** resets the bike.
- Landscape-first multitouch controls. Touch zones are independently held, so a rider can steer and accelerate/brake simultaneously. The controls and HUD are constrained for 960×540, 1280×720, 1920×1080, 2400×1080, and 1280×800 layouts by the project validation tests.
- A new in-race HUD using the supplied MGP fonts. On PC, **F7** cycles the persistent GUI Scale setting: **Default → 1 → 2 → 3**. The settings menu that exposes this choice visually is still pending.
- Reused supplied bike, rider, circuit-data, audio, graphics, and MGP font assets; see [`assets/SOURCE-ASSETS.md`](assets/SOURCE-ASSETS.md).
- Compatibility renderer is selected as the project default to keep the first build conservative on older hardware. **This has not been tested on Intel HD Graphics 4600 and is not claimed to fix the earlier Windows freeze.**
- The live transforms of every rider are recorded at 30 Hz as a foundation for replay. There is **no replay viewer or video-footage export yet**; no reconstruction-based replacement has been introduced.

## Not implemented yet

The following existing-native targets remain deliberately out of this first race-loop stage:

- Main menu, circuit picker UI, settings UI, profiles, accessibility/settings persistence beyond GUI Scale.
- Race tower, timing/sector UI, complete results flow, championship/progression.
- Qualifying and other practice modes beyond the three-lap race loop.
- Replay camera/viewer and genuine recorded replay-footage capture/export showing other riders.
- Final circuit scenery, polished physics/audio, localization, device tuning, and performance profiling.
- Windows and Android release validation on physical devices, including the reported Intel HD Graphics 4600 case.

## Run locally

1. Install **Godot 4.3 or newer** with export templates.
2. Open `native-prototype/project.godot` in Godot.
3. Run the project. The first opening imports the copied GLB, font, and MP3 assets.

The project starts directly in the race loop for Stage 1; this is intentional while the new menu UI is still being built.

## Export

`export_presets.cfg` contains `Windows Desktop` and `Android` targets. With the appropriate Godot export templates, Android SDK, and JDK configured in Godot:

```sh
godot --headless --path native-prototype --export-release "Windows Desktop" native-prototype/build/windows/WMC-Race.exe
godot --headless --path native-prototype --export-release "Android" native-prototype/build/android/WMC-Race.apk
```

The repository workflow `.github/workflows/native-prototype.yml` validates the source then produces both artifacts on GitHub Actions. Until that workflow completes, there is no verified Windows EXE or Android APK to claim as a tested build.

## Validation

Run the repository-independent checks from the repository root:

```sh
python3 native-prototype/tests/validate_project.py
```

They validate the project shape, supplied assets, six circuit definitions, responsive HUD/touch geometry at the listed landscape sizes, multitouch input implementation, GUI-scale modes, and the shared player/AI physics path. If Godot is installed, also run:

```sh
godot --headless --path native-prototype --editor --quit
```

## Reference-project note

No prior `native-prototype/` directory or `project.godot` was present in the supplied checkout or the default-branch history available to this workspace. This folder is therefore a clean rebuild rather than a deletion or edit of an old native project. If the separate old project exists outside this checkout, add it separately as a read-only reference before attempting feature-parity work.
