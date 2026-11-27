# 03 - Core Game State & Rules Engine

Host-authoritative state machine implementing the original (non-Recharged) Power Grid ruleset.

---

- [ ] **Game setup & player count scaling**
  - *Requirement*: Implement match initialization for 2-6 players using the `player_count_info` and `start_resources` tables (as structured in `airef/automa/src/board/germany.py` and `src/model/plant.py` / `resource.py`): starting Elektro (50), region selection based on player count, initial plant market (3-10), plant deck trimming, Step 3 card placement at bottom, and initial resource market fill.
  - *Test*: Run unit tests for 2, 3, 4, 5, and 6 players verifying active region counts, removed plant counts, and starting resource bin quantities.

- [ ] **Phase 1: Determine Player Order**
  - *Requirement*: Sort players descending by number of built cities, breaking ties by highest-numbered owned power plant (and random order on Turn 1 before Phase 2).
  - *Test*: Unit test with tied city counts and differing highest plants to confirm exact turn order output.

- [ ] **Phase 2: Auction Power Plants**
  - *Requirement*: Implement the full auction loop: turn-order player selects a plant from the Actual Market (or passes for the round), active bidders raise or pass, winner pays Elektro, replaces plant if at max capacity (3 plants, or 4 in 2p), and draws/sorts replacement card (handling Step 3 reveal and Turn 1 lowest-plant discard rule).
  - *Test*: Unit test a multi-player auction sequence including passes, outbidding, 3-plant discard replacement, and Turn 1 removal of the lowest plant if nobody buys.

- [ ] **Phase 3: Buy Resources**
  - *Requirement*: Implement reverse turn-order resource purchasing from the coal, oil, garbage, and uranium markets (referencing `airef/automa/src/model/resource.py` for bin pricing `[1..8, 10, 12, 14, 16]`, bin capacities, and max stock), enforcing player plant storage limits (2x capacity per plant, hybrid coal/oil flexibility).
  - *Test*: Unit test buying across price tiers, attempting to exceed storage capacity, and hybrid plant allocation.

- [ ] **Phase 4: Building Cities**
  - *Requirement*: Implement reverse turn-order city building: cheapest shortest-path connection cost (Dijkstra/BFS over map edges) plus slot cost (10 in Step 1, 15 in Step 2, 20 in Step 3), enforcing step slot limits and discarding any market plants with number <= max cities owned by any player.
  - *Test*: Unit test pathfinding connection costs for first city (0 connection cost) and subsequent cities, Step 1/2/3 occupancy limits, and automatic low-plant removal.

- [ ] **Phase 5: Bureaucracy**
  - *Requirement*: Implement powering cities (player chooses which plants to fire and which resources to spend, up to built cities), Elektro payout from the payment track, market resource restock by player count and current Step, and high-plant cycling (highest plant moved to bottom of deck in Step 1/2, or discarded in Step 3).
  - *Test*: Unit test payout values for 0-21 cities, resource consumption, restock tables for 2-6 players across Steps 1-3, and market cycling.

- [ ] **Step transitions & end-game scoring**
  - *Requirement*: Trigger Step 2 when a player reaches the Step 2 city threshold (and remove lowest plant), trigger Step 3 when the Step 3 card enters the market (and shrink market to 6), and trigger end-game after Phase 4 when a player reaches the end-game city threshold; determine winner by most powered cities in final Bureaucracy, then most Elektro, then most built cities.
  - *Test*: Unit test Step 2, Step 3, and end-game tiebreaker scenarios end-to-end.

- [ ] **Automa opponents: Frida & Official Robots**
  - *Requirement*: Implement AI/automa seat controllers for any non-human table seats (2-6 total seats): **Frida** (the print-and-play automa translated from `airef/automa/src/model/automa.py`, `src/automa_card_info.py`, `card/powergrid.csv`, and `automa_start_cities`) and **Robots** (the official *Power Grid: The Robots* modular robot ruleset).
  - *Test*: Run simulated matches filling empty seats with Frida and with Robots across 2-player and multi-player tables without rule violations or deadlocks.
