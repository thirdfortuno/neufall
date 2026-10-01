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
2. The main scene is `Battle/Battle.tscn` (`run/main_scene` in
   `project.godot`), which boots straight into a hardcoded battle defined by
   `grid_input` / `unit_input` in [Battle/Battle.gd](Battle/Battle.gd).
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
  target selection → pathfinding (Dijkstra-ish, see `_path_to_target`) →
  move → use ability. Driven by a per-unit `behavior` dict (see
  `unit_input` in `Battle.gd` for the shape: `search`/`peace`/`war` method
  lists, versioned via `behavior.version`).
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

## Code style (match existing code exactly)

- **Indentation: tabs**, not spaces. Every `.gd` file in this repo uses
  tabs — don't let an editor silently convert them.
- `snake_case` for variables/functions, `PascalCase` only for class names
  (`class_name Grid`) and node references (`$BattleUI`).
- Godot 4 syntax: `@export`, `@onready`, `Callable(self, "method")` for
  signal connections (this repo does not use the newer `unit.damaged.connect(_on_damaged)`
  callable-literal style — stay consistent with what's there unless doing a
  deliberate cleanup pass).
- Untyped GDScript throughout (no `: int`, `-> void` annotations). Match
  this; don't introduce static typing piecemeal into files that don't use
  it.
- Dictionaries with string keys (`u["data"]["type"]`, `ability.has('damage')`)
  are the default data shape for unit/ability definitions, not Resources
  or custom classes. Keep new unit/ability data in this shape unless asked
  to refactor it.
- Section-divider comments (`#################\n# SECTION NAME #\n#################`)
  are used in `Battle.gd` to break up large files — follow that convention
  if a file grows to need it, rather than splitting into new files
  unprompted.
- Leave `# TODO:` comments as markers of known gaps rather than silently
  "fixing" them with unrelated scope creep.

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
