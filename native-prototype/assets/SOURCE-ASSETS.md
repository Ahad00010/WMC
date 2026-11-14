# Native asset provenance

The new Godot project uses copies of the supplied repository assets so it can be opened as a self-contained project. The source web game remains untouched.

| Godot asset | Existing repository source | Current use |
| --- | --- | --- |
| `models/bike-mobile-low.glb` | `/bike-mobile-low.glb` | Player and AI bike model |
| `models/marc-rider.glb` | `/marc-rider.glb` | Player and AI rider model |
| `audio/menu-theme.mp3` | `/jimgor33-loading-main-menu-145077.mp3` | Low-level race ambience |
| `audio/results-theme.mp3` | `/MotoGP 2025 Session Summary Theme Music.mp3` | Reserved for results stage |
| `fonts/MGPDisplay-Bold.otf` | `/assets/results/mgp/MGPDisplay-Bold.otf` | Race HUD display type |
| `fonts/MGPText-Bold.ttf` | `/assets/results/mgp/MGPText-Bold.ttf` | Race HUD and control type |
| `graphics/*.png` | `/assets/results/*.png` | Reserved for future results/race-tower UI |
| `scripts/circuit_data.gd` | `/index.html` and `/circuits.js` | Native port of Sepang, Silverstone, Assen, Brno, Monza, and Jerez centre lines |

No new third-party art, rider, circuit, audio, or font asset was substituted for these supplied files.
