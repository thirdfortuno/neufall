# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, etc.) working in this repo.

## What this is

Neufall is a tactics-battle game — a spiritual successor to LEGO's *Spybot: The
Nightfall Incident*, rebuilt from scratch. Core loop: grid-based squad combat,
player vs. AI, units made of multiple "bodies" (hit points are physical
segments on the grid, not just a number), abilities with ranges/costs, and a
simple behavior-tree-style AI.

Built in **Godot 4.1**, scripted entirely in **GDScript**. There is no C#
in this repo and no Mono/.NET setup — stale Godot-3-era `.csproj`/`.sln`
scaffolding was removed. Don't add C# code or reintroduce a `.csproj`
unless explicitly asked.

## Running / testing

There is no CLI build or test suite. To verify a change:

1. Open the project in the Godot 4.1 editor (`project.godot`), or run it
   headless: `godot --path . ` (if the `godot` binary is on PATH).
2. The main scene is `Overworld/Overworld.tscn` (`run/main_scene` in
   `project.godot`). Picking a mission sets `Game.selected_mission_id` and
   loads `Battle/Battle.tscn`; running `Battle.tscn` directly (F6) falls back
   to `DEFAULT_MISSION` in [Battle/Battle.gd](Battle/Battle.gd). Missions are
   level scenes in `Levels/` listed in `Data/Campaign.tres`; units and abilities
   are Resources (see Unit and ability data below).
3. Manually exercise the golden path (select unit → move → use ability →
   end turn → AI turn) and any edge case your change touches. There is no
   automated regression coverage, so say so explicitly rather than claiming
   a change is "tested."
4. Useful debug keys wired up in `Battle.gd::_input`: `Q`/right-click
   deselects everything, `E` damages the selected unit, `R` prints its
   `active`/`click_state`.

If you add real automated tests, GUT (Godot Unit Test) is the conventional
choice for GDScript — but none exists yet, so don't assume it's installed.

## Architecture

- **`Battle/Battle.gd`** — the orchestrator. Owns the grid state
  (`grid_tiles`, `grid_units`), turn/phase state (`active_player`,
  `click_state`), selection state, and all the `_handle_*` methods that
  mutate the battle. Almost everything routes through this node via
  `get_parent()` from children, or direct calls from `AI.gd`.
- **`Battle/Grid.gd`** — a flat-array 2D grid helper (`class_name Grid`).
  Used for both tile grids and unit-occupancy grids. Has two constructors
  (from a 2D input array, or from explicit width/height) dispatched manually
  in `_init` since GDScript has no overloading.
- **`Battle/AI.gd`** — enemy turn logic: search → peace/war decision →
  target selection → pathfinding (multi-source BFS, see `_path_to_target`) →
  move → use ability. Driven by a per-unit `behavior` dict (see
  `Game.behavior_to_dict`, built from a `BehaviorDef` in `Data/behaviors/`:
  `search`/`peace`/`war` method lists, versioned via `behavior.version`).
- **Unit and ability data** — authored as Godot Resources edited in the
  Inspector: `Data/units/*.tres` (`UnitDef`), `Data/abilities/*.tres`
  (`AbilityDef`, with `EffectDef` sub-resources), listed in
  `Data/UnitLibrary.tres`. The class scripts are in `Data/Defs/`. The unit id
  is the file name (`hack.tres` is `"hack"`). At startup `Game.gd` converts
  each Resource into the plain dict shape the battle code reads
  (`Game.units[id]`), so runtime code stays dict-based. To add a unit: make a
  `UnitDef`, drag existing abilities into its list, and add it to the library.
  The Def scripts use typed `@export` fields so the Inspector shows pickers;
  that is the only place typed GDScript is used.
- **Levels** — each mission is a scene in `Levels/` (file name = mission id)
  listed in `Data/Campaign.tres` (its order is the overworld order). The root
  node uses `LevelDef` (name, `max_generation`, `victory_type`,
  `first_clear_reward`, `requires`, `challenges`). A child `Floor`
  `TileMapLayer` is the map: painted cells are floor, empty cells are void; it
  uses `Levels/floor_tileset.tres` (64px tiles) at scale 0.5 so cells are 32px
  like the battle grid, and the floor node stays at the origin. Direct
  children `SpawnMarker` (player spawn tiles, their count is the squad size),
  `EnemyMarker` (`unit`, `behavior` (defaults to a plain `BehaviorDef` if left empty), `is_target`) and `GoalMarker` (the
  `reach_tile` victory tile) are placed inside the cell they mean. A scene is
  converted by `Game.level_to_dict` into the same mission dict the battle code
  reads (`Game.missions`); the dict keeps the level's `scene` path so
  cosmetics (tile art variants, a background node) can later be shown in the
  battle from the same scene. Until then every tile uses the default sprite
  from `Tile/Tile.tscn`, and visuals must never change tile behavior.
- **Validator** — `Data/Validator.gd`, run by `Game._load_content` on every
  load. It checks units and abilities (empty names, no abilities, no effects,
  unknown effect types, zero range, tile-only abilities without a `tile_set`
  effect), tech nodes (missing or unlisted unit, bad cost, missing or cyclic
  `requires`) and levels (needs a `Floor` with tiles, spawn and enemy markers,
  markers on void or sharing a tile, an enemy marker with no unit, `reach_tile`
  needing exactly one `GoalMarker`, `kill_unit` needing an `is_target` enemy,
  challenge ids, values and tags, `requires`). Anything with errors is skipped
  rather than loaded, each error goes to `push_error` and `Game.content_errors`,
  and the Overworld shows them in red. Add a check here when adding a content
  rule.
- **Tech tree** — `Data/TechTree.tres` (`TechTreeDef`) lists nodes in
  `Data/tech/*.tres` (`TechNodeDef`: the `unit` it unlocks, a resource `cost`
  dict, `requires` nodes, and a graph `position`). The node id is the file
  name. A unit with `starts_unlocked` is available from the start, and its node
  (cost empty) shows as already unlocked, so starting units appear in the
  graph; any other player unit needs its node researched. `Game.gd` holds `unlock_node`,
  `node_state` (`unlocked`/`available`/`locked`), `can_afford`, and
  `available_units(max_generation)`, which the deploy roster uses. Researched
  nodes are saved in the profile as `unlocked_nodes`.
- **Deployment** (`Battle.gd` `_init_deploy`, `Battle/UI/DeployUI.tscn`) — a
  battle starts in a deploy phase: enemies are already placed, the mission's
  `spawn_tiles` are highlighted, and the player picks a roster unit then a
  spawn tile to place it. The number of spawn tiles is the squad limit. The
  roster is `Game.available_units(max_generation)`: unlocked `side: "player"`
  units with `generation` at or below the mission's `max_generation`. Clicking a placed unit removes it. "Start
  Battle" ends deployment.
- **`Game/Game.gd`** — the one autoload (`Game`, registered in
  `project.godot`). Holds the saved `profile` (`resources`, `cleared_missions`,
  `completed_challenges`), saves to `user://save.dat` with `store_var`, and
  `record_victory` grants the first-clear reward plus any newly completed
  challenge rewards (each only once). Resources are a dict of type to amount
  (placeholder types `data` and `bandwidth`). Keep it free of node references.
- **Screens** — `Overworld/` is the main scene: it lists every mission in
  `Game.missions` (disabled until the missions in its `requires` list are
  cleared), shows details, and starts the chosen one through
  `Game.start_mission`. It is meant to become a pannable graph of mission
  nodes later. The mission itself is `Battle/Battle.tscn`, and the results
  screen's "Overworld" button returns to the overworld. `UI/TopBar.tscn` is
  the shared bar (resource totals plus screen buttons) instanced on
  out-of-battle screens; a screen calls `$TopBar.set_current("name")` so its
  own button is disabled. Its "Refresh Data" button asks for confirmation, then
  calls `Game.new_save()`: it resets the profile to a fresh save, writes it,
  re-reads the unit library and tech tree `.tres` files from disk (bypassing
  the resource cache), and reloads the screen. Missions are still a script and
  need a restart to pick up edits. `TechTree/` is the tech tree screen: a pannable
  graph (`UI/PanView.tscn`, drag empty space to pan) of one button per node
  from `Game.tech_nodes`, with lines to prerequisites and a details panel with
  a Research button that calls `Game.unlock_node`. A main menu is planned but
  not built.
- **`Battle/BattleTracker.gd`** — child of the battle node. `Battle.gd` calls
  `tracker.check()` when a unit dies; it checks defeat (no player units) and
  the mission's `victory` type (table of checks: `eliminate_all`,
  `reach_tile` with `x`/`y` for the data packet tile, `kill_unit` with `enemy`
  matching an enemy entry's `id`; Battle also calls `check()` after each move),
  then emits `battle_finished(result)`. It also counts turns and player units
  lost, records the deployed squad, and on a win checks the mission's
  `challenges` (table of checks: `win_within_turns`, `no_unit_lost`,
  `max_generation`, `max_units`, `only_tag`, `require_tag`). `Battle.gd` sets `battle_over`, stops
  the AI loop and input, and shows `Battle/UI/ResultsUI.tscn`.
- **`Unit/Unit.gd`** — a unit is a collection of `Body` nodes
  ([Unit/Body/Body.gd](Unit/Body/Body.gd)); damage/heal pop/push bodies
  rather than decrementing an HP int. Movement, ability costs, and
  animation delays all live here.
- **`Tile/Tile.gd`** — a single grid cell: visuals (base/selection/tag
  sprite layers) and click → `selected` signal.
- **`Battle/UI/`** — HUD scripts/scenes for unit info, tile info, and the
  action bar (move/ability/end-turn/undo buttons).

Data flow is signal-driven (`unit.connect("damaged", ...)` etc., Godot 4
`Callable` style) plus a lot of direct `get_parent()` reaching-up from
children to `Battle.gd`. When adding new interactions, follow the existing
pattern (signal up, direct call down) rather than introducing a new
pattern (autoload singleton, event bus, etc.) unless asked.

## Code style — match the author's style, not your own default

**Hard rule: when editing this codebase, mimic the surrounding code's
style exactly, even where it conflicts with "best practice" or whatever
style an agent would otherwise default to.** This is a small, single-author
project — stylistic consistency with the existing code matters more than
any individual stylistic improvement. If you think something should be
done differently, say so and ask rather than silently writing it your way.

- **Indentation: tabs**, not spaces. Every `.gd` file in this repo uses
  tabs — don't let an editor silently convert them.
- `snake_case` for variables/functions, `PascalCase` only for class names
  (`class_name Grid`) and node references (`$BattleUI`).
- Godot 4 syntax: `@export`, `@onready`.
- **Signal connection/emission style is not uniform across the repo —
  match the file you're editing, not a repo-wide rule**: older gameplay
  code (`Battle.gd`, `Unit.gd`, `Tile.gd`) uses the Godot-3-holdover style
  (`.connect("selected", Callable(self, "_on_tile_select"))`,
  `emit_signal("damaged", self)`), while newer UI code (`BattleUI.gd`)
  uses the modern Godot 4 callable-literal style (`move_button_pressed.emit()`).
  Extending an existing file: follow that file's existing style. Writing a
  brand new file: the modern style (`signal_name.emit()`, direct
  `node.signal_name.connect(method)`) is preferred, but ask if unsure.
- Untyped GDScript throughout (no `: int`, `-> void` annotations). Match
  this; don't introduce static typing piecemeal into files that don't use
  it.
- Dictionaries with string keys (`data["hp_max"]`, `ability["targets"]`)
  are the data shape the runtime code reads (units and abilities are authored
  as Resources and converted by `Game.gd`). Abilities list their `targets` (`enemy`/`ally`/`self`, or
  `tile` for an empty tile) and an
  `effects` list; each effect `type` maps to a handler in
  `Battle.gd`'s `effect_handlers` table, so a new effect type is one new
  `_effect_*` function plus one table entry (current types: `damage`, `heal`,
  `hp_max_add`, `moves_max_add`, `drain`, `tile_set`). Range shape is optional:
  `targeting` is `manhattan` (default), `rook`, `bishop` or `queen`, and
  `blockers` is a list of `tile` (void tiles) and/or `unit` (other units) that
  stop a shot past them (default none). Range is computed in
  `Battle.gd`'s `_ability_get_range_from`, which the AI also uses.
- Section-divider comments (`#################\n# SECTION NAME #\n#################`)
  are used in `Battle.gd` to break up large files — follow that convention
  if a file grows to need it, rather than splitting into new files
  unprompted.
- Leave `# TODO:` comments as markers of known gaps rather than silently
  "fixing" them with unrelated scope creep.
- Before writing new code in a file, skim a sibling file (or the rest of
  the same file) for the pattern you're about to use — this codebase has
  some genuine drift between older and newer files (see signal style
  above), so "what does this specific file already do" beats "what did I
  see elsewhere in the repo."

## Art

**Never create or edit art assets** (sprites, textures, icons, animations).
The author does all art. Units without sprites show a small text label from
their `abbr` field instead, so new placeholder units need no art. Unit
definitions also carry `side` (`player` or `enemy`, the default side only: any
unit can be placed on either side).

## Git workflow

- Base/integration branch is **`development`**, not `main`/`master`.
- Feature branches follow `Pio/<Short-Description>` (e.g.
  `Pio/Fix-Move-Anim`, `Pio/AI-Anim-Bug`). Merged via PR (squash history
  shows `Merge pull request #N from thirdfortuno/Pio/...`).
- Commit messages: short, imperative, capitalized, no period
  (`Fix AI moving during animations`, `Add Heal and Damage delay animations`).
  Mirror this for any commits you create.

## Working with AI on this project

- This is a small, single-contributor project — prefer direct, minimal
  diffs over introducing new abstractions, frameworks, or build tooling.
- Since there's no test suite, be explicit in summaries about what you did
  and didn't manually verify in the editor.
- `.godot/`, `.import/`, `.mono/`, `data_*/` are gitignored editor/build
  artifacts — never hand-edit or commit them.
- `.tscn`/`.tres` files are Godot's text scene/resource format and are
  technically hand-editable, but prefer making structural scene changes
  (adding nodes, wiring signals) in the Godot editor when possible; hand-edits
  are fine for small tweaks (e.g. a texture path, an export value) if you're
  careful about the format.
