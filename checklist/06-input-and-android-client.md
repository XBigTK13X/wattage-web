# 06 - Input Modes & Android Second-Screen Client

Seamless play via mouse/keyboard, gamepad, or Android companion devices acting as both gamepad and private second screen.

---

- [ ] **Mouse & keyboard local controls**
  - *Requirement*: Support full local play on the host using mouse clicks, hover tooltips, scroll-wheel zoom, and keyboard shortcuts across all 5 phases.
  - *Test*: Play through a full turn (Phases 1-5) on the host using only mouse and keyboard without softlocks.

- [ ] **Gamepad navigation & focus routing**
  - *Requirement*: Support full local play using a standard controller (D-pad/left stick for city/market navigation, bumpers to switch panels, face buttons for confirm/pass/bid) with clear focus highlights.
  - *Test*: Play through a full turn on the host using only a gamepad (or keyboard-emulated gamepad actions) and verify every interactive element is reachable.

- [ ] **Android client mode: second-screen dashboard**
  - *Requirement*: Build a dedicated mobile/touch UI mode when running as a client that displays the player's Elektro, owned power plants, resource storage slots, turn status, and current phase prompt.
  - *Test*: Run the project in client mode (or mobile viewport preview), connect to a host, and verify player stats and owned plants render legibly in portrait/landscape.

- [ ] **Android client mode: virtual gamepad & phase actions**
  - *Requirement*: Provide touch-friendly phase controls on the Android client: D-pad/cursor control or direct tap selection for nominating/bidding on plants, buying resources, selecting cities to build, and choosing plants to power in Bureaucracy.
  - *Test*: Execute a bid, a resource purchase, a city build, and a Bureaucracy power selection from a connected client and verify the host board updates in real time.

- [ ] **Android export preset & touch ergonomics**
  - *Requirement*: Configure Godot Android export preset (`export_presets.cfg` template), permissions (INTERNET/ACCESS_NETWORK_STATE), responsive DPI scaling, and keep-screen-on during active matches.
  - *Test*: Validate the Android export configuration in Godot and test the client scene at common mobile aspect ratios (16:9, 20:9).
