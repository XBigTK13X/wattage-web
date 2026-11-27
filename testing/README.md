# Wattage Web Testing & Verification Guide

## Headless Automated Suite

Run all core rules, map graph, database, and networking seat tests from the project root:

```bash
godot --headless --script res://testing/run_tests.gd
```

Exits with code `0` when all assertions pass and `1` on any failure.

## Interactive `dev/` Verification Scenes

Set `var FIRST_SCENE = <SCENE_CONST>` in `script/singleton/scenes.gd` and launch Godot to inspect a specific subsystem:

- `FRAMEWORK_TEST` (`script/scene/dev/framework_test.gd`): `VW` singleton wiring, `EventLog`, `Settings`, `Chrome` panels, and `Scenes.goto()`.
- `INPUT_TEST` (`script/scene/dev/input_test.gd`): Keyboard, mouse, and gamepad action map + focus-ring switching.
- `DATABASE_TEST` (`script/scene/dev/database_test.gd`): `germany`, `united_states`, `sample_map`, and all 3 plant decks.
- `UI_TEST` (`script/scene/dev/ui_test.gd`): Clean-room 6-color house tokens, resource icons, city slot markers, and plant cards.
- `AUDIO_TEST` (`script/scene/dev/audio_test.gd`): All synthesized SFX cues and mute toggle.
- `NETWORK_TEST` (`script/scene/dev/network_test.gd`): Host/client protocol validation, public/private state isolation, and seat hot-swap.
- `CLIENT_PREVIEW` (`script/scene/dev/client_preview.gd`): Android two-view client (Dashboard & Actions + Zoom/Pan Map Inspection).
- `RULES_TEST` (`script/scene/dev/rules_test.gd`): Setup scaling, Phases 1-5, Dijkstra pathfinding, and Frida/Robots automa turns.
- `SAVE_TEST` (`script/scene/dev/save_test.gd`): Persistent game library, suspend/resume between multiple matches, and state equality checks.
