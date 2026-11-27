# 06 - Input Modes & Android Second-Screen Client

Seamless play via mouse/keyboard, gamepad, or Android companion devices acting as a private second screen and direct action interface.

---

- [ ] **Mouse & keyboard local controls**
  - *Requirement*: Support full local play on the host using mouse clicks, hover tooltips, scroll-wheel zoom, and keyboard shortcuts across all 5 phases.
  - *Test*: Play through a full turn (Phases 1-5) on the host using only mouse and keyboard without softlocks.

- [ ] **Gamepad navigation & focus routing**
  - *Requirement*: Support full local play using a standard controller (D-pad/left stick for city/market navigation, bumpers to switch panels, face buttons for confirm/pass/bid) with clear focus highlights.
  - *Test*: Play through a full turn on the host using only a gamepad (or keyboard-emulated gamepad actions) and verify every interactive element is reachable.

- [x] **Android client mode: two-view switcher & second-screen dashboard**
  - *Requirement*: Build a dedicated mobile/touch UI mode with a persistent top/bottom view switcher toggling between two views: (1) the **Dashboard & Actions** view displaying the player's Elektro, owned power plants, resource storage slots, turn status, and current phase prompt, and (2) the **Map Inspection** view.
  - *Test*: Run the project in client mode (or mobile viewport preview), connect to a host, verify player stats and owned plants render legibly in portrait/landscape, and switch cleanly between Dashboard and Map Inspection views.

- [x] **Android client mode: zoom & pan map inspection view**
  - *Requirement*: In the Android client's second view, render the synchronized board map with touch drag panning and pinch/button zoom so the player can inspect city occupancy, connection costs, active regions, and slot prices independently of the host camera (and optionally tap a city to build during Phase 4).
  - *Test*: Switch to the Map Inspection view on a connected client, pan and zoom across the map, tap a city to inspect its cost breakdown, and confirm the host display camera is unaffected.

- [x] **Android client mode: available phase actions**
  - *Requirement*: Display the player's currently available actions on the Android client's Dashboard & Actions view (no virtual gamepad/D-pad) with direct tap buttons for nominating/bidding on plants, buying resources, building cities, and choosing plants to power in Bureaucracy.
  - *Test*: Execute a bid, a resource purchase, a city build, and a Bureaucracy power selection from a connected client and verify the host board updates in real time.

- [x] **Android export preset & touch ergonomics**
  - *Requirement*: Configure Godot Android export preset (`export_presets.cfg` template), permissions (INTERNET/ACCESS_NETWORK_STATE), responsive DPI scaling, and keep-screen-on during active matches.
  - *Test*: Validate the Android export configuration in Godot and test the client scene at common mobile aspect ratios (16:9, 20:9).
