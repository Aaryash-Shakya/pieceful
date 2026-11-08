# Home and Pictures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app opens on a Home hub with a Resume hero and a floating tab bar, and a Pictures screen with collection tabs and a two-column grid hands the chosen picture to the existing Setup screen.

**Architecture:** `TabHost` is a screen that mounts a tab screen's body under a `FloatingNav` and routes tab presses through a `routes` table, so other tracks add Daily and Settings by adding a route. `HomeScreen` and `PicturesScreen` are code-built Controls like the existing screens. A static `BoardLaunch` is the one place that builds a `Board`, used by Home (Resume) and Setup (Start, Resume). Setup keeps its current layout (slice 3 rebuilds it) and gains an optional starting picture and pop-on-back.

**Tech Stack:** Godot 4.7.2, GDScript, headless test scripts (`timeout 120 godot --headless --script tests/<name>.gd`, pass prints `0 failure(s)`).

**Spec:** `docs/superpowers/specs/2026-11-06-ui-rebuild-design.md` (slice 2). Reference frames: `docs/prototype/ui-flow.html`, frames `home`, `home0`, `pictures`. Reference px × 1.5 = Godot px. Carry-over notes: `docs/ui-rebuild-status.md`.

## Global Constraints

- GDScript, Android only. Viewport 540×1200. No cut, save or piece-behaviour change. `SaveGame.VERSION` stays 4.
- Colours, radii, fonts come from `Palette` and `UiTheme` only. No new hex values in screens. Never set `theme = UiTheme.build()` in a new screen; `AppShell.apply_look()` reaches it.
- Hit areas at least 44 dp (66 Godot px at the reference scale of 1.5 means 44 px is the floor in Godot px too; use at least 66 where the visual is small).
- Every tab screen scrolls, with bottom padding of the nav height plus the bottom safe inset.
- Android back: Home quits, Pictures goes to Home, Setup pops.
- A save or picture that cannot load shows "Start a new one" instead of Resume. Never delete a save the game cannot use (existing `SaveFile.move_aside` rules stay).
- Daily and Settings tabs have no screen yet (tracks C): their nav buttons are disabled until a route is added.
- Match surrounding style, sparse comments that say why. Conventional commits. Tests extend `res://tests/base_test.gd` (or `board_test.gd`) by path, use `user://test_*` paths, and print no stray ERROR or WARNING lines.

## Review Focus

- Save exists but its picture fails to load, or no pictures at all: Home shows "Start a new one", never a Resume that opens the stand-in puzzle.
- Double tap on Continue, Start or a tab: only one board or screen opens.
- Android back on every new screen, including right after returning from a board.
- Board "home" returns to Home with the nav mounted, and Home shows the fresh save's Resume.
- Pictures with a collection whose pictures all fail to load: empty message, "Cut this" disabled.

## File structure

| File | Responsibility |
|---|---|
| `src/ui/board_launch.gd` (new) | Static: build a Board for a puzzle and present it; board home goes to Home. |
| `src/ui/tab_host.gd` (new) | Tab screen frame: body, `FloatingNav`, routes, safe area, scroll padding. |
| `src/ui/home_screen.gd` (new) | Home body: Resume hero or first-launch hero, Daily tile, New puzzle tile. |
| `src/ui/pictures_screen.gd` (new) | Pictures body: collection tabs, two-column grid, Cut this. |
| `src/ui/setup_screen.gd` (modify) | Optional starting picture, pop on back, launch through `BoardLaunch`. |
| `src/ui/app_shell.gd` (modify) | Default home is Home inside a TabHost. |
| `assets/icons/*.svg.import` (modify) | Nav icon scale about 1.4. |
| `tests/test_board_launch.gd`, `test_tab_host.gd`, `test_home_screen.gd`, `test_pictures_screen.gd` (new); `test_setup_flow.gd` and others (adjust) | |

---

### Task 1: BoardLaunch and Setup hand-off

**Files:**
- Create: `src/ui/board_launch.gd`
- Modify: `src/ui/setup_screen.gd` (`_launch`, `open`, `return_from_board`, `_ready`, `_notification`)
- Test: `tests/test_board_launch.gd`; adjust existing setup tests that call `return_from_board`.

**Interfaces:**
- Produces: `class_name BoardLaunch`. `static func launch(tree: SceneTree, save_path: String, source: Collection, puzzle: SaveGame.Puzzle, resume_save: bool, quit: Callable) -> Board` builds the Board exactly as `SetupScreen._launch` does today, connects `home_requested` to a static return that opens Home (Task 4 provides `HomeScreen.open`; until it exists the return calls `SetupScreen.open`), and presents it with `AppShell.present`. Returns the Board.
- Produces: `SetupScreen.start_picture_id: String` (default ""). When set and found in the collection, `_ready` selects that picture's section and picture instead of the first.
- Setup back: `NOTIFICATION_WM_GO_BACK_REQUEST` calls `AppShell.pop()` when the shell depth is above 1, else `quit_app`.

- [ ] **Step 1: Write the failing test** `tests/test_board_launch.gd`: with a test shell (`AppShell` with `make_home` returning a plain Control), `BoardLaunch.launch(...)` returns a Board whose `start_puzzle`, `resume`, `save_path` and `collection` equal the arguments and which is the shell's top after a frame; emitting `home_requested` leaves a non-board screen on top after a frame. A second case: `SetupScreen` with `start_picture_id` set to the second bundled picture's id starts with `picture.id` equal to it; an unknown id falls back to the first picture. A third: Setup with the shell at depth 2 pops on a back request; at depth 1 calls `quit_app`.
- [ ] **Step 2: Run it, expect FAIL** (`BoardLaunch` not defined). `timeout 120 godot --headless --script tests/test_board_launch.gd`
- [ ] **Step 3: Implement** `BoardLaunch.launch` by moving the body of `SetupScreen._launch` after the `_launched` guard into it; `SetupScreen._launch` keeps its `_launched`, disabling and timer stop, then calls `BoardLaunch.launch`. Add `start_picture_id` handling and the back change. Run `godot --headless --import` first (new class_name).
- [ ] **Step 4: Run** the new test and every existing test (`for t in tests/test_*.gd; do timeout 120 godot --headless --script $t | tail -1; done`), expect all `0 failure(s)`.
- [ ] **Step 5: Commit** `feat: launch boards through one helper and let setup start on a chosen picture`

---

### Task 2: TabHost

**Files:**
- Create: `src/ui/tab_host.gd`
- Test: `tests/test_tab_host.gd`

**Interfaces:**
- Produces: `class_name TabHost extends Control`. `var routes: Dictionary` (StringName → Callable returning a Node screen). `var body: Control`. `static func make(active: StringName, body: Control, routes: Dictionary) -> TabHost`. Mounts `body` filling the host and a `FloatingNav` pinned to the bottom with the safe-area bottom inset and a 16 px side margin. `func nav_clearance() -> float` returns nav height plus bottom inset plus 16, for bodies to pad their scrolling content with. A nav button is enabled only when `routes` has its id or it is the active tab. Pressing a tab calls `AppShell.present(get_tree(), routes[id].call())` unless the tab is already active. A pressed tab is ignored while a switch is pending.
- Consumes: `FloatingNav` (`buttons`, `set_active`, `tab_pressed`), `SafeArea.current(tree)`, `AppShell.present`.

- [ ] **Step 1: Failing test:** `make(&"home", Control.new(), {&"pictures": f})` has the home button pressed, pictures enabled, daily and settings disabled; pressing pictures presents `f`'s screen (one frame later) and pressing it twice presents once; pressing the active tab does nothing; `nav_clearance()` is at least the nav's height; body fills the host.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Use `set_deferred`-free layout: anchors and offsets, the nav positioned in `_ready` from `SafeArea`. Lock the host for presses with a bool cleared when the host leaves the tree.
- [ ] **Step 4: Run** the test, expect `0 failure(s)`.
- [ ] **Step 5: Commit** `feat: add a tab host that mounts the floating nav over a screen body`

---

### Task 3: Nav icon scale

**Files:**
- Modify: `assets/icons/home.svg.import`, `image.svg.import`, `cal.svg.import`, `set.svg.import` (`svg/scale`)
- Test: extend `tests/test_floating_nav.gd`

- [ ] **Step 1: Failing test:** each nav icon texture is at least 30 px wide and at most 36 px wide (reference icon at 1.5 is about 33).
- [ ] **Step 2: Run, expect FAIL** (icons are about 24).
- [ ] **Step 3:** Set `svg/scale=1.4` in the four `.import` files, then `godot --headless --import`. Commit the `.import` changes.
- [ ] **Step 4: Run** `test_floating_nav.gd` and any test that measures icons, expect `0 failure(s)`.
- [ ] **Step 5: Commit** `fix: size the nav icons to the design`

---

### Task 4: HomeScreen

**Files:**
- Create: `src/ui/home_screen.gd`
- Test: `tests/test_home_screen.gd`

**Interfaces:**
- Produces: `class_name HomeScreen extends Control`. `const SCENE`-free: built with `HomeScreen.new()`. Vars: `save_path`, `collection`, `quit_app` (same defaults and meaning as Setup). `static func open(tree: SceneTree, path: String, source: Collection, quit: Callable) -> HomeScreen` presents a `TabHost` whose body is the HomeScreen and returns the HomeScreen (routes: `pictures` → `PicturesScreen.open`-style factory from Task 5; Daily and Settings absent). `static func summary(path: String, source: Collection) -> Dictionary` returns `{}` when `SetupScreen.resumable` is null or the picture texture fails to load, else `{title, piece_count, style_name, saved}` plus `progress` (locked pieces over piece count) and `played` (mm:ss) only if the Snapshot carries those fields (check `SaveGame.Snapshot`; omit what it does not have). Widgets: `continue_button`, `new_button`, `daily_tile` (disabled, caption "Coming soon"), `title_label`, `empty_note`. With a resumable save: the picture as a hero behind a fade into `Palette.page_background()`, eyebrow "Resume", picture title, progress bar if known, Continue. Without one: hero from the first bundled picture, eyebrow "Free · no ads · works offline", "Let's make a puzzle", and "Pick a picture" as the primary button; if a save file exists but cannot be used, an extra line "Start a new one". Continue calls `BoardLaunch.launch(..., resume_save = true)` with a fresh `cut_seed`; New puzzle and Pick a picture present Pictures. A bool guards double presses. Back request: `quit_app`.
- Consumes: Task 1 `BoardLaunch`, Task 2 `TabHost`, `SetupScreen.resumable`, `Collection.load_texture`.

- [ ] **Step 1: Failing tests:** (a) with no save, `summary` is `{}`, the first-launch hero text shows and `continue_button` is null or hidden; (b) with a real save written through `SaveFile` for a bundled picture, `summary` has the right title and count and Continue is visible; (c) a save naming a missing picture leaves Home in first-launch form and logs at most the existing single warning, and the save file is untouched; (d) pressing Continue twice opens one board (`resume` true, `start_puzzle.image_id` equal to the save's); (e) New puzzle presents a TabHost-hosted Pictures screen; (f) back calls `quit_app`; (g) the screen has no child wider than the viewport at 540 and its scroll content is padded by the host's `nav_clearance()`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** (layout from reference frame `home`, sizes ×1.5, text roles via existing `UiTheme` variations; amber text uses the accent shadow role if `Palette` has one, else `Palette.accent()`).
- [ ] **Step 4: Run** the test and the full suite, expect `0 failure(s)`.
- [ ] **Step 5: Commit** `feat: add the Home screen with resume and a first-launch state`

---

### Task 5: PicturesScreen

**Files:**
- Create: `src/ui/pictures_screen.gd`
- Test: `tests/test_pictures_screen.gd`

**Interfaces:**
- Produces: `class_name PicturesScreen extends Control`. Vars: `save_path`, `collection`, `quit_app`, `sections: Array[Collection]`, `section_index`, `pictures`, `picture`, `tab_buttons`, `tiles: Array[Button]`, `cut_button`, `empty_label`. `static func open(tree, path, source, quit) -> PicturesScreen` presents a TabHost (active `pictures`, routes `home` → `HomeScreen.open`). `func select_collection(index: int)`, `func select_picture(index: int)`, `func cut() -> SetupScreen` (pushes Setup with `start_picture_id = picture.id` using `AppShell.push` when a shell exists so back pops here, else `AppShell.present`; returns the Setup; ignores a second call). Tabs: one per section (`collection.parts`, or the collection itself), hidden when there is one. Grid: two fixed columns of thumbnail tiles (`Collection.load_thumbnail`, tiles that fail to load are skipped), the selected tile shows a tick and an accent outline, "Cut {title}" is the primary button, disabled with no picture. A "More pictures" pill is shown disabled with the note "Coming soon" (Store is slice 8). Back request: go Home (`HomeScreen.open`). Taps that were scrolls must not select (reuse the TAP_SLOP idea from `SetupScreen`; do not duplicate its code: lift the swipe tracking into a small `TapGuard` RefCounted in the same task if both screens need it, otherwise keep it local).
- Consumes: Tasks 1, 2, 4; `Collection`, `CollectionLibrary.load_bundled`.

- [ ] **Step 1: Failing tests:** tabs match sections; selecting a tab changes the tiles and picks its first picture; `cut()` leaves a `SetupScreen` on top (after a frame) whose `picture.id` equals the chosen id and whose `start_picture_id` was honoured; second `cut()` returns null; Android back from Setup (depth 2) returns to this screen with the same selection; a collection whose pictures all fail shows `empty_label` and disables `cut_button`; back from Pictures presents Home.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** (layout from reference frame `pictures`).
- [ ] **Step 4: Run** test and full suite, expect `0 failure(s)`.
- [ ] **Step 5: Commit** `feat: add the Pictures screen and carry the chosen picture into setup`

---

### Task 6: Open on Home, board returns Home

**Files:**
- Modify: `src/ui/app_shell.gd` (default home), `src/ui/board_launch.gd` (return target), `src/ui/setup_screen.gd` (`return_from_board` removed or forwarding), existing tests that expected Setup as the first or returned screen (`test_setup_flow.gd`, `test_app_shell.gd`, board-home tests).
- Test: `tests/test_home_flow.gd`

**Interfaces:** The default `make_home` builds `HomeScreen.open`'s screen. Board `home_requested` presents Home (via `BoardLaunch`'s static return, which now calls `HomeScreen.open`). `SetupScreen.return_from_board` is deleted if nothing else uses it.

- [ ] **Step 1: Failing test:** start an `AppShell` with defaults and a test save path: the first screen is a `TabHost` with a `HomeScreen` body. Full flow with no scene changes: Home → New puzzle → Pictures → Cut → Setup → Start → Board → `home_requested` → Home shows Resume for that puzzle; Home → Continue → Board. Back at each step per the Global Constraints (Setup pops to Pictures, Pictures to Home, Home calls `quit_app`).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Update old tests to the new flow rather than deleting them.
- [ ] **Step 4: Run the full suite; expect every file `0 failure(s)` and no stray ERROR or WARNING lines.** Then run the app headless-with-window checks: `godot --path . --resolution 540x1200 --write-movie /tmp/home.png --quit-after 30` and look at the Home, Pictures and Setup frames against the reference at 540×1200.
- [ ] **Step 5: Commit** `feat: open on Home and return to it from the board`

---

### Task 7: Status and phone checklist

**Files:**
- Modify: `docs/ui-rebuild-status.md`

- [ ] **Step 1:** Mark slice 2 built; record calls made; add to "What only a phone can settle": nav bar clearance above the gesture bar and status bar, thumb reach, icon tint in light and dark, Home hero fade legibility at a large system font, Android back on Home, Pictures and Setup, double tap on Continue. Note for tracks B and C: `TabHost.routes` is where Daily and Settings attach; the nav buttons enable themselves.
- [ ] **Step 2: Commit** `docs: record the Home and Pictures slice`
