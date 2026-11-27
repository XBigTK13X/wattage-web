# 09 - Persistence, Testing & Polish

Save/load support, automated verification suites, and UX polish for host and client experiences.

---

- [ ] **Persistent game library, auto-save & host suspend/resume**
  - *Requirement*: Maintain a persistent library of games on disk (e.g., `user://games/*.json`, following `airef/dredmor/script/scene/game/load_game_menu.gd` and `script/scene/dev/save_test.gd`) storing complete host game state (game ID, title/map, timestamp, RNG seed, step, phase, turn order, markets, players, history). Enforce that only one game session is active on the host at a time, automatically persist state on phase/action commits and on clean shutdown or return-to-main-menu, and restore any stored game on host restart while re-syncing reconnecting clients.
  - *Test*: Play Game A into Phase 3, shut down the host completely, restart the host, verify Game A appears in the host library and resumes with identical state, then return to the main menu to start Game B and confirm Game A remains stored and resumable later.

- [ ] **Headless Godot automated test suite & `testing/` docs**
  - *Requirement*: Add a `testing/` runner script executable via `godot --headless` (plus `testing/*.md` verification guides paired with `script/scene/dev/*.gd` scenes, following `airef/dredmor/testing/README.md`) that runs all rules-engine, map-graph, and host/client protocol tests and exits non-zero on failure.
  - *Test*: Run the headless test command from the terminal and verify all test cases pass.

- [ ] **In-game rules reference & turn log**
  - *Requirement*: Add a clean-room action log and quick-reference panel (payment table, refill rates, current map's special rules) accessible on both host and client.
  - *Test*: Open the reference panel during a match and verify values dynamically reflect the active player count and map rules.

- [ ] **Connection resilience & UX polish**
  - *Requirement*: Add graceful handling for mid-game client disconnects, phase transition banners, undo/confirmation prompts for irreversible purchases, and responsive window resizing.
  - *Test*: Resize the host window across aspect ratios and drop/rejoin a client during Phase 2 without crashing or stalling the turn.
