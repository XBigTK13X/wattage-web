# 04 - Host/Client Networking & Messaging

Authoritative host state management with thin-client message passing for remote controllers and second-screen devices.

---

- [x] **Transport layer (Host & Client)**
  - *Requirement*: Implement LAN host server and client connection (Godot `MultiplayerAPI` / ENet or WebSocket) with lobby discovery or IP/port join and connection status indicators.
  - *Test*: Connect a second Godot instance (or headless client) on localhost to a running host and verify handshake and disconnect/reconnect events.

- [x] **Host-authoritative action protocol**
  - *Requirement*: Define a strict message schema for client-to-host action requests (`select_plant_for_auction`, `place_bid`, `pass_auction`, `buy_resource`, `build_city`, `power_plants`, `pass_phase`) where the host validates turn ownership, phase, and legality before mutating state.
  - *Test*: Send both valid and illegal action messages (wrong player, insufficient Elektro, wrong phase) from a test client and verify the host accepts valid ones and rejects invalid ones with an error code.

- [x] **State synchronization (public & private views)**
  - *Requirement*: Broadcast public board state snapshots/deltas (map occupancy, market plants, resource bins, turn order, current phase, active auction) to all clients, and send player-specific private/focused state (owned Elektro, plants, stored resources, legal actions) to each paired client.
  - *Test*: Inspect serialized state payloads received by two different clients and verify each client receives the full public board plus its own player state.

- [x] **Seat assignment & hot-swap**
  - *Requirement*: Allow the host lobby to bind connected clients (e.g., Android devices) to specific player seats, support local host-controlled players alongside remote clients, and allow rebinding if a device reconnects.
  - *Test*: Start a 3-player game with 1 local host player and 2 remote clients, disconnect one client, reconnect it, and verify it resumes control of its seat.
