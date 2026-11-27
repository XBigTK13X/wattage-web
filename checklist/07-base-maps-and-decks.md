# 07 - Base Maps & Original Plant Decks

Complete digitization of the base game maps and original power plant decks using `airef/automa/` and `airef/physical/` as references.

---

- [ ] **Base plant decks (`base_game`, `new_plants_1`, `new_plants_2`)**
  - *Requirement*: Digitize all power plant cards from `airef/automa/src/plant_deck/base_game_plants.py`, `new_plants_1.py`, and `new_plants_2.py`, including ecological, hybrid, coal, oil, garbage, and nuclear plants.
  - *Test*: Run a verification script comparing every plant card's cost, resource type, resource amount, and power output against the Python reference tables.

- [ ] **Germany map**
  - *Requirement*: Copy and convert the Germany map data from `airef/automa/src/board/germany.py` (`cities`, `connections`, `region_connections`, `start_resources`, `player_count_info`, `automa_start_cities`) and cross-check city coordinates against `airef/physical/map/germany.jpg` for all 42 cities across 6 color regions.
  - *Test*: Run a graph validation test verifying city count (42), region count (6), `region_connections`, connected components, and exact edge weights against `airef/automa/src/board/germany.py`.

- [ ] **United States map**
  - *Requirement*: Copy and convert the United States map data from `airef/automa/src/board/united_states_of_america.py` (`cities`, `connections`, `region_connections`, `start_resources`, `player_count_info`, `automa_start_cities`) and cross-check city coordinates against `airef/physical/map/united-states.jpg` for all 42 cities across 6 color regions.
  - *Test*: Run a graph validation test verifying city count (42), region count (6), `region_connections`, connected components, and exact edge weights against `airef/automa/src/board/united_states_of_america.py`.
