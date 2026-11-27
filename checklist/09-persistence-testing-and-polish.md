# 09 - Persistence, Testing & Polish

Save/load support, automated verification suites, and UX polish for host and client experiences.

---

- [ ] **Save/Load & deterministic state serialization**
  - *Requirement*: Serialize complete host game state (RNG seed, map, step, phase, turn order, markets, players, history) to JSON on disk and restore a playable match including re-syncing connected clients, following the save/load scene patterns in `airef/dredmor/script/scene/game/load_game_menu.gd` and `script/scene/dev/save_test.gd`.
  - *Test*: Save a mid-game match in Phase 3, reload from disk (and verify via `dev/save_test`), and confirm all Elektro, plant ownership, resource bins, and built cities match identically.

- [ ] **Headless Godot automated test suite & `testing/` docs**
  - *Requirement*: Add a `testing/` runner script executable via `godot --headless` (plus `testing/*.md` verification guides paired with `script/scene/dev/*.gd` scenes, following `airef/dredmor/testing/README.md`) that runs all rules-engine, map-graph, and host/client protocol tests and exits non-zero on failure.
  - *Test*: Run the headless test command from the terminal and verify all test cases pass.

- [ ] **In-game rules reference & turn log**
  - *Requirement*: Add a clean-room action log and quick-reference panel (payment table, refill rates, current map's special rules) accessible on both host and client.
  - *Test*: Open the reference panel during a match and verify values dynamically reflect the active player count and map rules.

- [ ] **Connection resilience & UX polish**
  - *Requirement*: Add graceful handling for mid-game client disconnects, phase transition banners, undo/confirmation prompts for irreversible purchases, and responsive window resizing.
  - *Test*: Resize the host window across aspect ratios and drop/rejoin a client during Phase 2 without crashing or stalling the turn.
