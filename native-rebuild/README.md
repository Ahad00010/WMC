# WMC native rebuild

Separate Godot 4 project, under active development. The older `native-prototype/` project remains the reference; the web game is unchanged.

## Current work

The race prototype from the separate rebuild session is the starting point. This project corrects its backwards-facing follow camera and positions riders only after they enter the scene tree. It adds textured asphalt, a new MGP-font home / mode / six-circuit selector, animated page fades, and sensor-landscape sizing. Practice exposes lap count, speed and an optional AI grid. The native race flow includes tower, rider map, pause/settings, a results sequence with the posed rider, a separate championship page, real viewport-frame capture, and a winner graphic. The practice championship page does not invent standings or record points. Replay is recorded from a camera rendering the live race world, not reconstructed from transforms.

**Remaining limitations:** online multiplayer and qualifying are intentionally disabled; the native online-authoritative championship and leader-device replay sharing are not implemented. Browser sign-in/profile, mobile touch/audio, exact replay end-frame timing and the full results presentation still need target-device validation.

The Windows build uses the earlier reviewed Godot 4.4.1 Windows canvas-upload mitigation (`glBufferSubData` instead of the mapped upload at the observed crash site), statically linked ANGLE, and crash symbols. This mitigation addresses that observed crash site but does not prove the cause of the separate frozen-display symptom. The rebuild has not been validated on the affected Intel Windows system. No claim of an underlying graphics fix is made. Race diagnostics include FPS, GPU accounting estimates, readback time, capture backoff, and rider counts in `WMC-diagnostics.txt` beside the Windows executable when writable, otherwise under `user://`; engine logs are under `user://logs`. GPU accounting values can overcount failed allocations and are not proof of real allocations.

## Development

Open `native-rebuild/project.godot` in Godot 4.4.1. For source checks run `python3 native-rebuild/tests/validate_project.py`; the separate CI workflow also imports the project and runs the race-view runtime test. These tests do not substitute for rendered and physical-device checks.

Assets and attribution are listed in `assets/SOURCE-ASSETS.md`.
