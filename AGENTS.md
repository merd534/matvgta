# AGENTS.md — MatvGTA (Godot 4.6 / GDScript)

## Project overview

3D stealth/open-world game with procedural city generation. "Shadows of Doubt"-style immersive sim with neon visual style, multi-story buildings, ventilation networks, and full stealth/combat systems.

## Engine & tooling

- Godot 4.6, GDScript, Forward Plus renderer
- No external package manager — all deps are scene/script autoloads
- Localization via CSV (`localization/game.csv`) → `.translation` files (ru default, en)

## Entry points

- `scenes/main.tscn` → `scripts/systems/MainScene.gd` — root scene, orchestrates everything
- `scripts/world/WorldGenerator3D.gd` — procedural city generation entry
- `scripts/player/Player3D.gd` — first/third-person controller

## Autoloads (singletons)

- `SettingsManager` — graphics presets (Potato→Ultra), FSR 2.2, save/load settings
- `Localization` — language switching, `Localization.translate("KEY")`

## Directory structure

| Path | Purpose |
|------|---------|
| `scripts/systems/` | AI (Guard, Citizen), HUD, dialogue, save, audio, inventory, blackmail, hacking, cameras, alarms, police |
| `scripts/player/` | Player3D, StealthSystem, StealthCombat3D, NoiseSystem, EMPGadget, BodyDisposalSystem |
| `scripts/world/` | WorldGenerator3D, ChunkGenerator, BuildingGenerator, VentilationGenerator, NavigationBaker, DistrictPlanner, LootTable/Spawner |
| `scenes/` | Only `main.tscn` currently |
| `localization/` | CSV + .translation files |
| `data/dialogues/` | JSON dialogue trees |

## Initialization order (critical)

MainScene enforces this sequence to avoid `_ready()` race conditions:
1. `WorldGenerator3D` generates city (chunks → buildings → vents → nav bake)
2. `Player3D` instantiated and positioned
3. Simulation spawns (citizens, cameras, terminals)
4. HUD / UI created last

**Do not reorder.** `MainScene._cleanup_game_state()` resets everything between games.

## Dependency resolution

Project has `DependencyResolver` at `scripts/systems/DependencyResolver.gd` — audits cyclic `class_name` references. Use dynamic `get_node()` or Autoload singletons instead of direct class coupling.

## Performance caps (hardcoded)

- Citizens: max 15 (spawned per building)
- Security cameras: max 20 (30% chance per building)
- Hacking terminals: max 10 (40% chance per building)

## World generation

- Chunk-based spiral generation from center outward
- District types: Regular (neon) and Wealthy (taller, denser security)
- `ChunkMeshMerger` combines static meshes per chunk for performance
- `AsyncNavigationBaker` runs `NavigationServer3D.region_bake_navigation_mesh()` off main thread

## Localization

- Default language: Russian (`ru`)
- Keys are UPPERCASE_SNAKE_CASE (e.g., `GENERATING_WORLD`, `NAV_BAKING`)
- CSV at `localization/game.csv`, imports generate `.translation` files

## Gameplay systems

- **Stealth**: light-based visibility via RayCast3D, noise radius (walk=0, run=alert), crouch/vent states
- **Combat**: `StealthCombat3D` — takedowns, body disposal via `BodyDisposalSystem`
- **Pickpocket**: behind NPC in stealth, success rate check
- **Hacking**: terminals disable cameras 30s, EMP gadget disables cameras in 4m radius
- **Police**: 1-5 wanted stars, `PoliceDirector3D` spawns officers/vehicles
- **Black Market**: sell stolen items, dynamic pricing, buy lockpicks/EMP
- **Dialogue**: branching conversations, bribery, fake ID checks

## Settings

- 5 presets: Potato / Low / Medium / High / Ultra
- FSR 2.2 modes: Ultra Quality (77%) → Performance (50%)
- Saved to `user://settings.cfg`

## Common pitfalls

- Do not use `class_name` across scripts without checking for cycles — use `get_node()` or Autoloads
- `WorldGenerator3D.set_script(null)` is called before re-initialization — scripts are loaded dynamically
- `Player3D._ready()` is called manually after script assignment — not automatic
- Navigation bake is async — do not assume nav meshes exist immediately after chunk creation
