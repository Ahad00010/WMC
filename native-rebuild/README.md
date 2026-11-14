# WMC native rebuild

Separate Godot 4 project, under active development. The older `native-prototype/` project remains the reference; the web game is unchanged.

## Current work

The race prototype from the separate rebuild session is the starting point. This project corrects its backwards-facing follow camera and positions riders only after they enter the scene tree. It adds textured asphalt, a new MGP-font home / mode / six-circuit selector, animated page fades, and sensor-landscape sizing. Practice currently starts a fixed three-lap race with nine AI. This is not yet feature parity.

**Not yet implemented:** actual captured race-world replay and winner presentation, full race tower, menus for settings and profile, practice configuration, pause and results flow, start lights and the rest of the original native features. Transform samples present in this prototype are not a real replay and must not be presented as one.

The earlier Intel crash and frozen-display symptoms are not yet understood or verified fixed. This new project uses Godot's compatibility renderer; it has not been validated on the affected Windows hardware. No claim of an underlying graphics fix is made.

## Development

Open `native-rebuild/project.godot` in Godot 4.4.1. For source checks run `python3 native-rebuild/tests/validate_project.py`; the separate CI workflow also imports the project and runs the race-view runtime test. These tests do not substitute for rendered and physical-device checks.

Assets and attribution are listed in `assets/SOURCE-ASSETS.md`.
