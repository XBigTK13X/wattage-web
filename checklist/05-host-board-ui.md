# 05 - Host Board UI

Main screen presentation for the host instance displaying the shared board, markets, tracks, and game flow.

---

- [ ] **Host lobby & match configuration screen**
  - *Requirement*: Build a main menu, settings menu, and match setup screen (reusing menu layout and `VW.Chrome` nine-patch `CenterContainer` dialog patterns from `airef/dredmor/script/scene/game/main_menu.gd` and `settings_menu.gd`) to select map, plant deck, player count (2-6), player names/colors, local vs remote client seat bindings, and optional Automa/expansions.
  - *Test*: Configure a match with 4 players on the Germany map, start the game, and verify the board initializes with the selected settings.

- [ ] **Interactive game map view**
  - *Requirement*: Render regions (highlighting active vs inactive regions), cities with 10/15/20 house slots, connection lines with cost badges, and pan/zoom camera controls; highlight reachable/affordable cities during Phase 4.
  - *Test*: Load the map scene, pan/zoom with mouse and gamepad, and verify city hover/focus displays connection + slot cost breakdowns.

- [ ] **Power plant market & auction overlay**
  - *Requirement*: Display the Actual Market (top row) and Futures Market (bottom row), Step 3 indicator, and a live auction overlay showing the plant on the block, current high bid, bidder, and pass status per player.
  - *Test*: Trigger Phase 2, nominate a plant, place bids from two players, and verify the market updates and shifts correctly when won.

- [ ] **Resource market & turn/payment tracks**
  - *Requirement*: Display coal, oil, garbage, and uranium bins with current unit prices and remaining stock, alongside the Phase tracker, Player Order track, and Bureaucracy payout reference.
  - *Test*: Purchase resources in Phase 3 and advance phases; verify bin counts, prices, and turn order badges update immediately.

- [ ] **Player summary strip & end-game screen**
  - *Requirement*: Show each player's public summary (built cities, owned plants, stored resources, turn status, and Elektro if visible/end-game) and an end-of-game results screen with final powered cities and tiebreaker breakdown.
  - *Test*: Complete or fast-forward a match to the end-game trigger and verify the final standings screen matches the ruleset tiebreakers.
