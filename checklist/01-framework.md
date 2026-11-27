# 01 - Framework & Project Setup

Foundational Godot project structure, clean-room boundaries, and core singletons/routing adapted directly from `airef/dredmor`.

---

- [x] **Initialize Godot project from `airef/dredmor` baseline**
  - *Requirement*: Port the base Godot 4.x configuration (`project.godot`, `.gitignore`, `default_bus_layout.tres`, `default_env.tres`, `debug.sh`) and directory layout (`scene/Bootstrap/`, `script/singleton/`, `script/scene/game/`, `script/scene/dev/`, `script/instance/`, `asset/`, `data/`, `testing/`) from `airef/dredmor` without copying any copyrighted Dredmor or `airef/physical/` assets.
  - *Test*: Launch the project headless or in the Godot editor and confirm zero missing resource or parse errors in the console.

- [x] **Port root autoload (`VW`) & scene router (`scenes.gd`)**
  - *Requirement*: Adapt `airef/dredmor/script/singleton/od.gd` (as `VW`) and `airef/dredmor/script/singleton/scenes.gd` + `scene/Bootstrap/Bootstrap.tscn` so `VW.reset()` wires child singletons and `Scenes.goto()` / `FIRST_SCENE` dynamically mounts `init_container()` scenes under `/root/Container`.
  - *Test*: Set `FIRST_SCENE` to a minimal `dev/` verification scene, run the project, and verify it boots directly into that scene and can transition via `VW.Scenes.goto()`.

- [x] **Reuse core utility singletons from `airef/dredmor`**
  - *Requirement*: Port and adapt applicable singletons from `airef/dredmor/script/singleton/` (`log.gd`, `math.gd`, `data_structure.gd`, `event_log.gd`, `loading.gd`, `audio.gd`, `chrome.gd`, `settings.gd`, `asset_cache.gd`, `action_queue.gd`), stripping Dredmor-specific logic while preserving the architecture and nine-patch `Chrome` helpers.
  - *Test*: Run a smoke-test scene that exercises `VW.Log`, `VW.Settings` save/load, `VW.Chrome` nine-patch panel creation, and `VW.EventLog` without errors.

- [x] **Unified input action map**
  - *Requirement*: Configure Godot `InputMap` actions in `project.godot` for navigation (`ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, `ui_cancel`), tab/panel cycling, zoom/pan, and quick-bid/confirm shortcuts supporting mouse, keyboard, and standard gamepads.
  - *Test*: Open a `dev/input_test` scene via `FIRST_SCENE` and verify keyboard, mouse click, and gamepad D-pad/face buttons all trigger the expected logical actions.
