# 02 - Data Schemas & Clean-Room Assets

Structured JSON/Resource schemas for maps, plants, and game rules, plus original clean-room visual and audio assets.

---

- [ ] **Map & graph data schema**
  - *Requirement*: Define a structured data format (JSON or custom Godot `Resource`) representing regions, `region_connections`, cities (region ID, name, coordinates), bidirectional `connections` with compass directions and costs, `start_resources`, and `player_count_info` (matching the structure in `airef/automa/src/board/germany.py` and `united_states_of_america.py`), indexed through a database singleton modeled on `airef/dredmor/script/singleton/database.gd` and `load.gd`.
  - *Test*: Load a sample map file through the database loader (verified via a `dev/database_test` scene modeled on `airef/dredmor/script/scene/dev/database_test.gd`) and assert all cities, regions, `region_connections`, and connection costs parse into typed objects with symmetric adjacency.

- [ ] **Power plant & deck data schema**
  - *Requirement*: Define a structured schema for power plant cards (number/cost, fuel type, fuel capacity, cities powered, special flags like Step 3 or ecological/hybrid) and deck sets (`base_game`, `new_plants_1`, `new_plants_2`), referencing `airef/automa/src/plant_deck/` for values and registering lookups in `VW.Database`.
  - *Test*: Run a loader check in `dev/database_test` that parses all three plant decks and verifies card counts, costs, and Step 3 card presence.

- [ ] **Original clean-room UI & board graphics**
  - *Requirement*: Create original vector/procedural/custom Godot assets (theme, nine-patch panels using `airef/dredmor/script/singleton/chrome.gd` `PanelContainer`/`StyleBoxTexture` patterns, player house tokens in 6 colors, coal/oil/garbage/uranium resource icons, plant card frames, city node markers) without using any scanned retail images.
  - *Test*: Open a `dev/ui_test` showcase scene (modeled on `airef/dredmor/script/scene/dev/ui_test.gd`) displaying all 6 player colors, 4 resource types, city slots (10/15/20), and a sample plant card, and verify clean rendering at 1080p and 720p.

- [ ] **Original audio cues**
  - *Requirement*: Add clean-room SFX cues (bid placed, auction won, resource bought, city built, phase change, turn alert) using the pooled SFX player and bus-volume pattern from `airef/dredmor/script/singleton/audio.gd` and `settings.gd`.
  - *Test*: Trigger each cue from a `dev/audio_test` scene (modeled on `airef/dredmor/script/scene/dev/audio_test.gd`) and verify playback and mute toggle behavior.
