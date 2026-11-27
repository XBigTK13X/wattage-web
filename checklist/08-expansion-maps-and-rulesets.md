# 08 - Expansion Maps & Original Rulesets

Digitization of all remaining original (non-Recharged) expansion maps in `airef/physical/map/` along with each map's unique ruleset overrides.

---

- [ ] **Expansion rule-hook architecture**
  - *Requirement*: Extend the rules engine with clean hook points for map-specific overrides (custom starting resources, modified refill tables, special Step triggers, regional building restrictions, modified plant markets, special fuel rules).
  - *Test*: Verify a mock map with overridden refill rates and Step 2 threshold alters game behavior without modifying core engine code.

- [ ] **France & Italy**
  - *Requirement*: Digitize `france.jpg` (nuclear/cheap uranium rules, Paris multi-region rules) and `italy.jpg` (resource scarcity/market adjustments, regional layout).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **Benelux & Central Europe**
  - *Requirement*: Digitize `benelux.jpg` (ecological plant/market adjustments, smaller/faster map rules) and `central-europe.jpg` (Vienna/Prague/Warsaw regional rules, nuclear restrictions).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **Northern Europe & Europe**
  - *Requirement*: Digitize `northern-europe.jpg` (national fuel/plant rules) and `europe.jpg` (European map ruleset).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **Spain & Portugal and UK & Ireland**
  - *Requirement*: Digitize `spain-portugal.jpg` (nuclear/wind/resource market rules) and `uk-ireland.jpg` (separate grid / ferry connection rules).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **China & Korea**
  - *Requirement*: Digitize `china.jpg` (planned economy / ordered plant deck rules) and `korea.jpg` (divided North/South resource market rules).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **Brazil & Russia**
  - *Requirement*: Digitize `brazil.jpg` (biogas/garbage & hydro rules) and `russia.jpg` (restricted plant market & fuel rules).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **Japan & Australia**
  - *Requirement*: Digitize `japan.jpg` (dual-network / starting city rules) and `australia.jpg` (isolated networks & uranium export rules).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **India & South Africa**
  - *Requirement*: Digitize `india.webp` (monsoon/powering rules and regional layout) and `south-africa.jpg` (map layout and resource/coal rules).
  - *Test*: Validate city/connection graphs and run a unit test for each map's specific rule override.

- [ ] **North America, Quebec, Baden-Württemberg, and Middle East**
  - *Requirement*: Digitize `north-america.jpg`, `quebec.jpg`, `baden-wurtenberg.jpg`, and `middle-east.jpg` with their respective city graphs and map-specific rules.
  - *Test*: Validate all four city/connection graphs and run unit tests for each map's rule overrides.
