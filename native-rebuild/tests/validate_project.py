#!/usr/bin/env python3
"""Fast, dependency-free validation for the WMC Godot Stage 1 source tree.

This is intentionally not a substitute for running Godot on target hardware.
It checks the project contract that can be verified in a headless source-only
workspace, including layout calculations at supported landscape sizes.
"""
from __future__ import annotations

import configparser
import hashlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "native-rebuild"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def touch_layout(width: int, height: int) -> dict[str, tuple[float, float, float, float]]:
    shortest_side = min(width, height)
    button_size = max(64.0, min(shortest_side * 0.145, 128.0))
    margin = max(16.0, min(shortest_side * 0.035, 48.0))
    gap = max(10.0, min(shortest_side * 0.018, 22.0))
    bottom = height - margin - button_size
    return {
        "left": (margin, bottom, button_size, button_size),
        "right": (margin + button_size + gap, bottom, button_size, button_size),
        "throttle": (width - margin - button_size, bottom, button_size, button_size),
        "brake": (width - margin - button_size, bottom - button_size - gap, button_size, button_size),
    }


def intersect(first: tuple[float, float, float, float], second: tuple[float, float, float, float]) -> bool:
    ax, ay, aw, ah = first
    bx, by, bw, bh = second
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


class NativePrototypeContractTests(unittest.TestCase):
    def test_project_is_separate_landscape_compatibility_project(self) -> None:
        project_path = NATIVE / "project.godot"
        self.assertTrue(project_path.is_file())
        config = configparser.ConfigParser(interpolation=None)
        # Godot keeps config_version before the first INI section; ConfigParser
        # needs a harmless synthetic section before reading that format.
        config.read_string("[__godot_root__]\n" + project_path.read_text(encoding="utf-8"))
        self.assertEqual(config["application"]["run/main_scene"], '"res://scenes/Race.tscn"')
        self.assertEqual(config["display/window"]["handheld/orientation"], "4")
        self.assertEqual(config["display/window"]["stretch/aspect"], '"expand"')
        self.assertEqual(config["rendering"]["renderer/rendering_method"], '"gl_compatibility"')
        self.assertTrue((NATIVE / "scenes/Race.tscn").is_file())

    def test_reused_assets_are_present_and_byte_identical_to_the_supplied_sources(self) -> None:
        mapping = {
            ROOT / "bike-mobile-low.glb": NATIVE / "assets/models/bike-mobile-low.glb",
            ROOT / "marc-rider.glb": NATIVE / "assets/models/marc-rider.glb",
            ROOT / "jimgor33-loading-main-menu-145077.mp3": NATIVE / "assets/audio/menu-theme.mp3",
            ROOT / "MotoGP 2025 Session Summary Theme Music.mp3": NATIVE / "assets/audio/results-theme.mp3",
            ROOT / "assets/results/mgp/MGPDisplay-Bold.otf": NATIVE / "assets/fonts/MGPDisplay-Bold.otf",
            ROOT / "assets/results/mgp/MGPText-Bold.ttf": NATIVE / "assets/fonts/MGPText-Bold.ttf",
        }
        for source, native_copy in mapping.items():
            with self.subTest(source=source.name):
                self.assertTrue(source.is_file())
                self.assertTrue(native_copy.is_file())
                self.assertEqual(sha256(source), sha256(native_copy))
        self.assertEqual((NATIVE / "assets/models/bike-mobile-low.glb").read_bytes()[:4], b"glTF")
        self.assertEqual((NATIVE / "assets/models/marc-rider.glb").read_bytes()[:4], b"glTF")

    def test_all_six_circuits_are_ported_with_substantial_control_lines(self) -> None:
        source = (NATIVE / "scripts/circuit_data.gd").read_text(encoding="utf-8")
        expected = {
            "sepang": 100,
            "silverstone": 80,
            "assen": 100,
            "brno": 60,
            "monza": 80,
            "jerez": 100,
        }
        self.assertIn('return PackedStringArray(["sepang", "silverstone", "assen", "brno", "monza", "jerez"])', source)
        for circuit_id, minimum_points in expected.items():
            with self.subTest(circuit=circuit_id):
                match = re.search(
                    rf'"{circuit_id}": \{{(?P<body>.*?)(?=\n\t"[a-z]+": \{{|\n\}}\n\nstatic)',
                    source,
                    flags=re.DOTALL,
                )
                self.assertIsNotNone(match)
                self.assertIn('"length":', match.group("body"))
                self.assertGreaterEqual(match.group("body").count("Vector2("), minimum_points)

    def test_landscape_touch_layout_has_no_overlaps_or_offscreen_controls(self) -> None:
        # 16:9 phone, 16:9 desktop, 16:9 wide desktop, 20:9 phone landscape,
        # and 16:10 tablet/wide screen.
        for width, height in [(960, 540), (1280, 720), (1920, 1080), (2400, 1080), (1280, 800)]:
            with self.subTest(resolution=f"{width}x{height}"):
                controls = touch_layout(width, height)
                self.assertGreaterEqual(controls["left"][2], 64.0)
                self.assertLessEqual(controls["left"][2], 128.0)
                for name, (x, y, control_width, control_height) in controls.items():
                    self.assertGreaterEqual(x, 0.0, name)
                    self.assertGreaterEqual(y, 0.0, name)
                    self.assertLessEqual(x + control_width, width, name)
                    self.assertLessEqual(y + control_height, height, name)
                self.assertFalse(intersect(controls["left"], controls["right"]))
                self.assertFalse(intersect(controls["throttle"], controls["brake"]))
                self.assertFalse(intersect(controls["left"], controls["throttle"]))
                self.assertFalse(intersect(controls["right"], controls["brake"]))

    def test_multitouch_and_shared_ai_physics_paths_are_present(self) -> None:
        touch = (NATIVE / "scripts/ui/touch_controls.gd").read_text(encoding="utf-8")
        game = (NATIVE / "scripts/race_game.gd").read_text(encoding="utf-8")
        bike = (NATIVE / "scripts/race_bike.gd").read_text(encoding="utf-8")
        ai = (NATIVE / "scripts/ai_rider.gd").read_text(encoding="utf-8")
        replay = (NATIVE / "scripts/replay/replay_recorder.gd").read_text(encoding="utf-8")
        for token in ("InputEventScreenTouch", "InputEventScreenDrag", "_touches: Dictionary", "func command() -> Vector3"):
            self.assertIn(token, touch)
        self.assertIn("_player.drive(_player_command(), stable_delta)", game)
        self.assertIn("rider.drive(brain.command_for(rider, circuit), stable_delta)", game)
        self.assertIn("func drive(command: Vector3, delta: float)", bike)
        self.assertIn("func command_for(bike: WmcRaceBike, circuit: WmcCircuit)", ai)
        self.assertIn("const SAMPLE_RATE_HZ := 30.0", replay)
        self.assertIn('"transform": rider.global_transform', replay)

    def test_pc_gui_scale_modes_and_export_presets_exist(self) -> None:
        scale = (NATIVE / "scripts/ui/ui_scale.gd").read_text(encoding="utf-8")
        exports = (NATIVE / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('const NAMES := ["Default", "1", "2", "3"]', scale)
        self.assertIn('name="Windows Desktop"', exports)
        self.assertIn('name="Android"', exports)


if __name__ == "__main__":
    unittest.main(verbosity=2)
