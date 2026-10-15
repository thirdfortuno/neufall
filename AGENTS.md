# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, etc.) working in this repo.

## What this is

Neufall is a tactics-battle game — a spiritual successor to LEGO's *Spybot: The
Nightfall Incident*, rebuilt from scratch. Core loop: grid-based squad combat,
player vs. AI, units made of multiple "bodies" (hit points are physical
segments on the grid, not just a number), abilities with ranges/costs, and a
simple behavior-tree-style AI.

Built in **Godot 4.6**, scripted entirely in **GDScript**. There is no C#
in this repo and no Mono/.NET setup — stale Godot-3-era `.csproj`/`.sln`
scaffolding was removed. Don't add C# code or reintroduce a `.csproj`
unless explicitly asked.

## Running / testing

There is no CLI build or test suite. To verify a change:

1. Open the project in the Godot 4.6 editor (`project.godot`), or run it
   headless: `godot --path . ` (if the `godot` binary is on PATH).
2. The main scene is `Overworld/Overworld.tscn` (`run/main_scene` in
   `project.godot`). Picking a mission sets `Game.selected_mission_id` and
   loads `Battle/Battle.tscn`; running `Battle.tscn` directly (F6) falls back
   to `DEFAULT_MISSION` in [Battle/Battle.gd](Battle/Battle.gd). Missions are
   level scenes in `Levels/` listed in `Data/Campaign.tres`; units and abilities
   are Resources (see Unit and ability data below).
   The window is resizable and nothing is stretched (the stretch mode is the default,
   disabled): one game pixel is one screen pixel, so text and art are never scaled by the
   window and stay crisp, and a bigger window simply shows more space. The base size is
   960x540, `Game._ready` sets that as the minimum window size, the window opens at
   1920x1080 (window size override) and F11 toggles fullscreen (`Game._input`). The Game
   tab of the editor embeds the running game; set its embed size mode to Fixed Size, as
   Stretch to Fit gives the game the size of the tab. Screens
   therefore anchor their pieces to the edges instead of using absolute positions:
   the battle UI, the deploy panel, the overworld and the tech tree do.
   The battle UI frame, top bar and side panels are built from slices of the
   original art in `Battle/UI/Parts/` (cut with a one-off script; the originals
   `UI_*.png` are kept but no longer used): tiled strips for the frame and top bar,
   and a header, repeating body and footer for the left panels, so any piece can be
   made longer by repeating its body.
3. Manually exercise the golden path (select unit → move → use ability →
   end turn → AI turn) and any edge case your change touches. There is no
   automated regression coverage, so say so explicitly rather than claiming
   a change is "tested."
4. `Q`/right-click deselects everything (`Battle.gd::_input`). There are no
   debug keys.

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
  If the target cannot be reached (no walking path), the unit walks to the
  reachable tile closest to it (`_path_to_closest`); if it is already there it
  shuffles onto free tiles every turn (`_unit_shuffle`), which regrows lost bodies.
  Pacing: each tile an AI unit moves without an ability landing (`move_streak`) shortens the
  waits between its moves and between units (`delay_scale`, 10% per tile down to 20%); a
  landed ability resets it, and it carries over from turn to turn.
- **Unit and ability data** — authored as Godot Resources edited in the
  Inspector: `Data/units/*.tres` (`UnitDef`), `Data/abilities/*.tres`
  (`AbilityDef`, with `EffectDef` sub-resources). The class scripts are in
  `Data/Defs/`. Every `.tres` file under `Data/units/`, including its `player/`, `enemy/` and
  `extra/` subfolders, is loaded automatically (sorted by file name, which is
  also the roster order), with no list to maintain. The folders are only for
  organizing: a unit's `side` field decides which side it defaults to, and a
  unit id is the file name, so two files with the same name in different
  folders are an error. The unit id is the file name (`hack.tres` is `"hack"`). At startup `Game.gd` converts
  each Resource into the plain dict shape the battle code reads
  (`Game.units[id]`), so runtime code stays dict-based. To add a unit: make a
  `UnitDef` in `Data/units/` and drag existing abilities into its list.
  Units and abilities both have an optional `description` (shown in the tech
  tree details panel and as tooltips on deploy roster buttons and the battle
  action buttons).
  The Def scripts use typed `@export` fields so the Inspector shows pickers;
  that is the only place typed GDScript is used.
- **Levels** — each mission is a scene in `Levels/` (file name = mission id)
  listed in `Data/Campaign.tres` (its order is the overworld order). The root
  node uses `LevelDef` (`mission_name`, `company`, `mission_info`,
  `max_generation`, `victory_type`, `first_clear_reward`, `requires`
  (drag the prerequisite level scenes in; the level stays locked until all of
  them are cleared), `challenges`). Resource amounts
  (`first_clear_reward`, a challenge's `reward`, a tech node's `cost`) are
  lists of `ResourceAmount` sub-resources (a `type` dropdown and an `amount`),
  like an ability's effects; `Game.amounts_to_dict` sums them into the
  `{type: amount}` dict the game uses. To add a resource type, add its name to
  the `type` list in `Data/Defs/ResourceAmount.gd`. `company` is a `CompanyDef` resource (`company_name`,
  `tagline`, `language`, `description`; make them in `Data/companies/`) shared by levels, so it can
  later drive cosmetics as well as flavor text; both it and `mission_info`
  are optional and shown on the overworld details panel (the deploy title
  shows only the mission name). A child `Floor`
  `TileMapLayer` is the map (`LevelDef` is a `@tool` script that adds it, with
  `Levels/floor_tileset.tres` and scale 0.5, when it is the root of a scene opened in
  the editor and has none; the root's "Add Floor" button does the same for
  an older scene): painted cells are floor, empty cells are void. Tile coordinates are
  absolute from the `Floor` origin (a tile painted at 1, 1 is tile (1, 1) in
  the battle), so leaving row 0 or column 0 empty makes a void buffer on that
  side; the grid only starts above or left of the origin if tiles are painted
  at negative coordinates; it
  uses `Levels/floor_tileset.tres` (64px tiles) at scale 0.5 so cells are 32px
  like the battle grid, and the floor node stays at the origin. Direct
  children `SpawnMarker` (player spawn tiles, their count is the squad size),
  `FixedUnitMarker` (a set player `unit` that starts on its tile and cannot
  be changed or removed in the deploy phase; it counts as part of the squad
  for challenges), `EnemyMarker` (`unit`, `behavior` (defaults to a plain
  `BehaviorDef` if left empty), `is_target`) and `GoalMarker` (the
  `reach_tile` victory tile) are placed inside the cell they mean. A unit
  marker can have `BodyMarker` children that give the unit extra starting body
  tiles: they must form an adjacent chain from the unit's tile, sit on floor
  tiles of their own, and total (with the head) no more than the unit's
  `hp_max`. A scene is
  converted by `Game.level_to_dict` into the same mission dict the battle code
  reads (`Game.missions`); the dict keeps the level's `scene` path so
  cosmetics (tile art variants, a background node) can later be shown in the
  battle from the same scene. Each painted floor cell
  shows the look of the `Floor` tile set source it was painted with (`Levels/floor_tileset.tres`
  has one source per image in `Tile/Styles/`, source 0 is `normal.png`; `level_to_dict` passes the
  texture paths as `styles`, `Tile.style`). All styles behave the same, and tiles are drawn at
  60% opacity in the battle. A tile flipped on by an ability (`Tile.set_state`) always becomes the
  normal tile. Visuals must never change tile behavior.
- **Validator** — `Data/Validator.gd`, run by `Game._load_content` on every
  load. It checks units and abilities (empty names, too many abilities, no effects,
  unknown effect types, zero range, tile-only abilities without a `tile_set`
  effect), tech nodes (missing or unlisted unit, bad cost, missing or cyclic
  `requires`) and levels (needs a `Floor` with tiles, spawn and enemy markers,
  markers (including body markers) on void or sharing a tile, disconnected
  body markers, a unit marker with no unit, `reach_tile`
  needing exactly one `GoalMarker`, `kill_unit` needing an `is_target` enemy,
  challenge ids, values and tags, `requires`). Anything with errors is skipped
  rather than loaded, each error goes to `push_error` and `Game.content_errors`,
  and the Overworld shows them in red. Add a check here when adding a content
  rule.
- **Tech tree** — every `.tres` under `Data/tech/` (`TechNodeDef`) is a node
  and is loaded automatically, with no list to maintain (the `unit` it unlocks, a resource `cost`
  dict and `required_units` (units that must already be unlocked) with a
  `requires_mode` of `all` or `any`). The node id is the file name, and only
  one node may unlock a given unit. Node positions are not authored: after
  loading, `Game/TechLayout.gd` lays the graph out top to bottom (a node's
  row is one below its deepest prerequisite, and nodes in a row are ordered by
  their prerequisites' positions to limit crossings). The graph draws a solid
  line from a prerequisite unit's node for ALL, a dashed line for ANY (green
  once that prerequisite is unlocked), and shows "Needs ALL/ANY of N" on the
  node. A unit with `starts_unlocked` is available from the start, and its node
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
  units with `generation` at or below the mission's `max_generation` (0 means
  any generation). Each unit has a `memory` cost (default 1) and a level's
  `max_memory` (0 means no limit) caps the total memory of the squad, fixed
  units included: the deploy panel (`DeployUI.tscn`, a `SidePanel` in the same right-hand slot as the
  objective and log panels, which are hidden until the battle starts) shows the total, and
  Start Battle is disabled
  while it is over the limit. Clicking a placed unit removes it. "Start
  Battle" ends deployment.
- **`Game/Game.gd`** — the one autoload (`Game`, registered in
  `project.godot`). Holds the saved `profile` (`resources`, `cleared_missions`,
  `completed_challenges`), saves to `user://save.dat` with `store_var`, and
  `record_victory` grants the first-clear reward plus any newly completed
  challenge rewards (each only once). Resources are a dict of type to amount
  (placeholder types `data` and `bandwidth`). Keep it free of node references.
- **Screens** — `Overworld/` is the main scene: a pannable graph of mission
  nodes (the same `UI/PanView.tscn` and automatic layout as the tech tree,
  with `Game/TechLayout.gd` placing missions by their `requires` list). Nodes
  are green when cleared, white when available and grey when locked (a mission
  is locked until every mission in its `requires` is cleared); selecting one
  shows details, and Start runs it through `Game.start_mission`. The mission itself is `Battle/Battle.tscn`, and the results
  screen's "Overworld" button returns to the overworld. `UI/TopBar.tscn` is
  the shared bar (resource totals plus screen buttons) instanced on
  out-of-battle screens; a screen calls `$TopBar.set_current("name")` so its
  own button is disabled. Its "Refresh Data" button asks for confirmation, then
  calls `Game.new_save()`: it resets the profile to a fresh save, writes it,
  re-reads the unit, tech tree and level files from disk (bypassing the
  resource cache), and reloads the screen. `TechTree/` is the tech tree screen: a pannable
  graph (`UI/PanView.tscn`: drag empty space or use the mouse wheel, shift
  for sideways, to pan; it stays within the graph's bounds and has a Recenter
  button) of one button per node
  from `Game.tech_nodes`, with lines to prerequisites and a details panel with
  a Research button that calls `Game.unlock_node`. A main menu is planned but
  not built.
- **Battlefield camera** — `Battle/BattleCamera.gd` is a `Camera2D` child of
  the battle node (anchor mode fixed top-left, so position (0, 0) at zoom 1 is the
  original picture). Middle-mouse drag pans, with a soft limit (the camera may
  leave the map, but 64 screen pixels of it must stay in the visible field) and
  moving in steps of 8 world pixels (`STEP`) to keep the pixel art aligned, and the mouse wheel
  steps the zoom between 1x and 3x around the pointer (board only).
  `BattleUI`, `SelectedTileUI` and the deploy panel live under the `UI`
  `CanvasLayer` so they stay fixed; tiles and units stay children of the battle
  node. `Battle/UI/Minimap.gd` draws the map in the top-left panel from code (floor,
  units by team color, spawn and goal tiles, and the camera's view outline); a
  click or drag on it calls `camera.center_on`. When deployment starts, and when
  an AI unit acts, `camera.ensure_visible` moves the camera only if that spot is
  hidden (off screen or behind the side panels), so maps that fit never move.
- **Resolving abilities** — `Battle.gd` `_handle_unit_ability` awaits every
  effect (damage, heal, drain...) and any `size_cost` before it ends the
  unit's turn and calls `_check_if_turn_done`, so effects finish, and any
  kill-triggered win or loss happens, before the turn changes. While it runs
  `resolving` is true and clicks, keys and action buttons are ignored. New
  effect handlers that take time must `await` their work.
- **One unit at a time** — on the player's turn, when a player unit makes a
  move (`Battle.gd` `_handle_unit_move`), any other player unit that has already
  moved (`unit.moved`) has its turn ended by `_finish_moved_units`. Selecting
  units, or moving one and undoing it, ends nobody. A unit whose turn is
  done (`active` false) shows a small "✓" label (`Unit.done_mark`, text, no art),
  for both sides; each side's marks are hidden when the other side's turn
  begins.
  The top bar's "End Turn" button (`BattleUI` `end_all_button_pressed`,
  `Battle.gd` `_on_EndAllButton_pressed`) ends every player unit's turn at once;
  the per-unit button in the unit panel only ends the selected unit.
- **Sound** — `Battle/Sfx.gd` (`battle.sfx`, a child of the battle node) plays
  sounds through a small pool of players on the `SFX` bus (buses `SFX` and
  `Music` live in `default_bus_layout.tres`). Audio files are `AudioStream`
  fields on the Resources; `Game.gd` passes their paths through the dicts and a
  missing sound is silent. An effect's `sound` is its default; an ability's
  `sound` overrides it (the ability plays once on use instead of each effect
  playing its own as it lands). Units have `sound_move` (once per tile
  stepped, in `Unit.move_to`; a unit without one plays a random one of the default steps in `SFX/` (`unit_move1.ogg`, `unit_move2.ogg`), listed in `Sfx.UNIT_MOVE`), `sound_hurt` and `sound_death` (in
  `Unit.damage`, death when the damage is at least the unit's remaining
  bodies).
- **Turn banner** — `Battle/UI/TurnBanner.tscn` shows "Your Turn" or "Enemy
  Turn" for about a second whenever `_swap_active_player` changes sides and
  when the battle starts; the AI waits `DELAY_TURN_BANNER` before its first
  unit acts so the banner can be read.
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
  rather than decrementing an HP int. Each body tints itself from its unit's
  team (`Unit.body_tint()`: the unit's `primary_bg_color` when it is on the side it
  belongs to (`side`), its `secondary_bg_color` when it is on the other, and blue for player
  units or red for enemies for a color left black, which means unset), so the
  body tiles read as friend or foe; the unit's own sprite is not tinted. Movement, ability costs, and
  animation delays all live here.
- **`Tile/Tile.gd`** — a single grid cell: visuals (base/selection/tag
  sprite layers) and click → `selected` signal. `set_ui` picks the tag sprite:
  `moveable`, `damageable`, or `arrow_up`/`arrow_right`/`arrow_down`/`arrow_left`
  (`tile_movearrow.png`, drawn pointing up and rotated). On the player's move
  display, tiles directly next to the unit's head (the move range's `adjacent`
  list) get the arrow pointing away from the head and the rest of the range
  keeps `moveable`; the AI's range display still uses `moveable` only.
- **Font** — the project theme (`UI/theme.tres`, set in `project.godot` `gui/theme/custom`)
  uses monogram (`Fonts/monogram-extended.ttf`, a CC0 pixel font by datagoblin) at a
  default size of 32. It is drawn crisply at 16 px and multiples of 16 (32, 48); its
  import settings have antialiasing, hinting and subpixel positioning off. Side panels
  (`SidePanel.tscn`, which the objective, log, event and deploy panels use) have their own
  theme (`UI/panel_theme.tres`) at size 16. UI roots and the labels the code draws use the nearest
  texture filter (`texture_filter = 1`) and the font imports use oversampling 1.0, so the
  pixel font and the stretched panel art have no blur or fading edges; the project default texture
  filter is nearest (`rendering/textures/canvas_textures/default_texture_filter`), except the two
  overlay sprites in `Tile.tscn` (selection, tag), which are 64 px art drawn at half size and use
  the linear filter until they are redrawn at 32 px, because nearest shrinking drops every
  other pixel and breaks their 1 px lines (the base tile itself uses nearest). Text that the
  code draws on tiles (unit abbreviations, path numbers, the outcome readout) stays at 16
  so it fits a 32 px tile. Text at other sizes, or when the window scale is not a whole
  number, can look uneven.
- **`Battle/UI/`** — HUD scripts/scenes for unit info, tile info, and the
  action bar (move/ability/end-turn/undo buttons). The right column
  (`RightColumn.tscn`, built from the reusable collapsible `SidePanel.tscn`, which draws the
  panel art from `Parts/panel_stitched.png` as a 9-patch so it can be any size) shows after
  deployment: an objective panel (mission name, objective, the target enemy's name for
  `kill_unit`, and the turn and side: `Battle._update_status`) and a log panel (newest
  first, `Battle._log`: abilities used, units destroyed, turn changes, enemy moves). The
  event panel at the bottom left takes no space while empty: `Battle.show_event(title,
  text)` queues an event, shown one at a time until the player presses Continue
  (`hide_event()` dismisses the current one); the level's `mission_info` is shown as the
  first event, and the camera's `bottom_inset` / `right_inset` keep units out from
  under these panels. Tiles emit
  `hovered`/`unhovered`; hovering any unit shows it in the unit panel read-only
  (`BattleUI.show_unit(unit, true)`: buttons disabled), and leaving restores the
  selected unit. Hovering an ability button previews its range
  (`ability_hovered`/`ability_unhovered`) and leaving restores whatever range was
  showing. The top bar's Menu button opens `BattleMenu.tscn` (a dialog:
  Resume and Back to Overworld,
  which asks first and then calls `Game.go_to_overworld` without recording anything); it does
  not pause the battle, so the AI keeps playing behind it. The top bar's End Turn asks for confirmation when any active unit
  has not moved or acted (`BattleUI.ask_end_all`). UI plans are in the plan
  file. While choosing where to move, hovering a tile inside the move range numbers
  the walking path to it (`_update_path_preview`, a text label per tile via
  `Tile.set_step`) that keeps as much of the path already traced as it can
  (`_hover_move_path`: it extends or trims the previous path before re-routing);
  clicking a tile in the move range walks the unit along that path
  one tile at a time (`_walk_unit`: each step is an ordinary `_handle_unit_move`, a tenth of a
  second apart, with clicks blocked while it walks; a step that is refused stops the walk). Hovering an
  enemy (in the default and unit-select states and during deploy, never while
  an ability or move range is showing) tints the tiles it can move to (its
  `moves_max`) with the `enemy_move` tile tag, the normal move sprite tinted red,
  and leaving restores the previous tags (`_refresh_range_tags`). Selecting any unit,
  an enemy too, and hovering one of its ability buttons shows that ability's range
  from the unit's tile; the panel buttons of a non-player unit are read-only. With an ability selected, hovering a legal target flashes the tiles that would
  change (`_update_outcome_preview`, `Tile.set_flash`): red on the tail bodies a unit
  would lose, green on the free tiles it could grow onto (the tail-most body with a
  free neighbor, as in `Unit.heal`), and a tile that would turn on or off; fainter
  flashes are tiles that only change in some outcomes. Max size and move
  changes and any chance below 100% are a small text readout above the unit. Every effect type has a preview function in `effect_previews`, next to
  its `effect_handlers` entry, that updates a low/high range and a chance instead of
  running the effect, so a random effect can show its odds later (a new effect type needs
  both functions). The preview assumes a heal has room to grow.

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
