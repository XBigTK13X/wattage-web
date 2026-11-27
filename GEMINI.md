## Overarching Goal
- **Volt Web** is a clean-room Godot implementation of the original (non-Recharged) board game *Power Grid* and all of its original maps and rulesets.
- Supported control schemes:
  - Mouse and keyboard
  - Standard gamepad
  - Android device running in client mode (acting as both a gamepad and a private second screen)
- **Host/Client Architecture**:
  - **Host mode**: Runs the game, renders the main board, accepts local input, and allows remote clients to join. All authoritative board game state is kept and managed exclusively on the host instance.
  - **Client mode**: Thin client (including Android devices) that sends action messages to the host to commit game actions and receives state views from the host to display the second screen and controller UI.

## Checklist Workflow
- Project action items are tracked in `checklist/*.md` in numerical order (e.g., `checklist/01-framework.md`, `checklist/02-data-and-assets.md`, ...).
- Before starting implementation work, check `checklist/` to find the earliest ordered file with unchecked `[ ]` items and work on the top-most unchecked item.
- Each checklist item defines both the requirement to complete and how to test that it is complete and ready for verification.
- When an item is completed and verified, check it off (`[x]`) and report how to verify it.

## Requirements
- Do not use any of the real life board game images in this version of the game
- Instead translate the game details into a new implementation

## Code Standards
- Don't abbreviate words to make variable names shorter. For example, use "texture" instead of "tex"

## Retail Game Inspection (`airef/`)
- `airef/physical/map` contains photos of the real board game maps
- `airef/physical/component` contains various photos of game components
- `airef/automa` contains a mostly correct implementation of many rules of the game in python for the base game maps.
- `airef/dredmor` contains a reference godot game implementation to borrow code from and serve as an architecture example
