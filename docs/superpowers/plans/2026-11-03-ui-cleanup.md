# UI and Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Tidy" button in a screen-space HUD packs every loose cluster into two shuffled bands above and below the board and animates them there, drawn with the locked fonts, palette and chunky button style.

**Architecture:** `Palette` gains every locked colour role. Two OFL fonts are bundled and a script, `UiTheme.build(dark)`, makes a `Theme` from them and the palette. A pure `CleanupLayout.layout(...)` turns loose clusters' home rectangles into one offset each. `Board.cleanup()` writes those offsets into `PuzzleState`, grows the camera bounds, and moves the nodes with one `Tween`; a `Hud` `CanvasLayer` in the board scene holds the button and calls it.

**Tech Stack:** Godot 4.7.2, GDScript, Mobile renderer. Tests are plain headless scripts extending `BaseTest` or `BoardTest`.

**Spec:** `docs/superpowers/specs/2026-11-03-ui-cleanup-design.md`. Also read `INTENT.md` and `AGENTS.md`.

## Global Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies or plugins. The only network use is the one-time font download in Task 2; the app makes no network call.
- Colours only from `docs/visual-design.md` through `Palette`. Fonts only Baloo 2 and Quicksand from google/fonts, unmodified. Radii: buttons 8, panels 10, sheets 14.
- Randomness only from `SeededRng`; cleanup uses stream `-3`.
- Cleanup never joins, locks, splits or reorders anything and never touches locked pieces. Whenever no animation is running, every node's position equals `state.offset_of(piece)` exactly.
- No per-frame work when nothing animates. One tweener per cleanup, not one per piece.
- Out of scope: setup screen, slots, completion screen, settings, ghost image, effects, saving, reduced motion, a camera fit, a toast, cleanup sound or haptic.
- Run `godot --headless --import` after adding any file with a new `class_name` or any asset, then `timeout 120 godot --headless --script tests/<name>.gd`. A passing run prints `0 failure(s)` and exits 0.
- Match the surrounding code style, sparse comments that explain why. Conventional commits, one per task; include any `.uid` and `.import` files Godot creates.

## Review Focus

- Tidy pressed twice quickly: the second press completes the first animation instantly and lays out again from the exact final places with the next counter (Task 4, `_test_second_press_mid_animation`).
- A finger lands during the animation: the animation completes before the press is handled, and the press lifts the cluster now under the finger at its final place (Task 4, `_test_touch_finishes_animation`).
- The app is paused or loses focus mid-animation: nodes snap to the state at once, so a later save on pause is consistent (Task 4, `_test_pause_finishes_animation`).
- A touch on the button also reaching the board, which would start a pan or complete an animation (Task 5, `_test_button_touch_stays_in_hud`).
- One cluster wider than a whole band: it sits alone in its row, centred, and still overlaps nothing (Task 3, `_test_wide_cluster`).

---

### Task 1: The full palette

**Files:**
- Modify: `src/game/palette.gd`, `tests/test_palette.gd`

**Interfaces:**
- Produces on `Palette`, each `static func <role>(dark := is_dark()) -> Color` returning `Color.html(dark_hex if dark else light_hex)`: `page_background`, `surface`, `raised_surface`, `text`, `muted_text`, `lines`, `accent`, `text_on_accent`, `accent_shadow`, `felt`, `board`. `is_dark()`, `felt`, `board`, `accent` and `outline()` keep their current signatures and values.

| Role | Light | Dark |
|---|---|---|
| `page_background` | `#e7e9f0` | `#0b1020` |
| `surface` | `#f6f7fb` | `#131a2e` |
| `raised_surface` | `#dbdfea` | `#1c2540` |
| `text` | `#141b2d` | `#e9edf7` |
| `muted_text` | `#566079` | `#8d98b5` |
| `lines` | `#c9cfdd` | `#27314f` |
| `accent` | `#e2a41f` | `#ffc857` |
| `text_on_accent` | `#2a1d00` | `#2a1d00` |
| `accent_shadow` | `#a87612` | `#b58712` |
| `felt` | `#223a63` | `#14264a` |
| `board` | `#2c4878` | `#1c3463` |

- [ ] **Step 1: Add the failing checks to `tests/test_palette.gd`.** Keep every existing check. Add one `check` per row and mode of the table, in the form `check(Palette.surface(false) == Color.html("#f6f7fb"), "surface light")` and `check(Palette.surface(true) == Color.html("#131a2e"), "surface dark")`, for all eleven roles (the felt, board and accent lines already exist; do not duplicate them). Add `check(Palette.text() == Palette.text(Palette.is_dark()), "text follows the device mode")`.
- [ ] **Step 2: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_palette.gd`. Expected: a parse error that `page_background` (or another new role) is not found.
- [ ] **Step 3: Add the eight new functions** to `src/game/palette.gd`, in the table's order, between `is_dark` and `felt`.
- [ ] **Step 4: Run it again.** `timeout 120 godot --headless --script tests/test_palette.gd`. Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game/palette.gd tests/test_palette.gd && git commit -m "feat: add every Midnight table colour role"`

### Task 2: Bundled fonts and the theme

**Files:**
- Create: `assets/fonts/Baloo2-Variable.ttf`, `assets/fonts/Quicksand-Variable.ttf`, `assets/fonts/OFL-Baloo2.txt`, `assets/fonts/OFL-Quicksand.txt`, `assets/fonts/LICENSE.md`, `src/ui/ui_theme.gd`, `tests/test_ui_theme.gd`
- Modify: `export_presets.cfg` (`include_filter` in `[preset.0]`)

**Interfaces:**
- Consumes: Task 1's `Palette` roles.
- Produces `class_name UiTheme extends RefCounted` in `src/ui/ui_theme.gd`:
  - `const BALOO_PATH := "res://assets/fonts/Baloo2-Variable.ttf"`, `const QUICKSAND_PATH := "res://assets/fonts/Quicksand-Variable.ttf"`
  - `const BODY_WEIGHT := 600`, `BUTTON_WEIGHT := 700`, `TITLE_WEIGHT := 800`
  - `const BODY_FONT_SIZE := 20`, `BUTTON_FONT_SIZE := 22`, `TITLE_FONT_SIZE := 28`
  - `const BUTTON_RADIUS := 8`, `PANEL_RADIUS := 10`, `SHEET_RADIUS := 14`
  - `const BUTTON_DEPTH := 5`, `PRESSED_DEPTH := 1`, `BUTTON_PADDING_X := 20`, `BUTTON_PADDING_Y := 8`, `PANEL_PADDING := 12`, `SHEET_PADDING := 20`, `LINE_WIDTH := 1`
  - `const TITLE := &"Title"` (type variation of `Label`), `const SHEET := &"Sheet"` (type variation of `PanelContainer`)
  - `static func weighted(path: String, weight: int) -> FontVariation`: `base_font = load(path)`, `variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}`.
  - `static func build(dark := Palette.is_dark()) -> Theme`, with every value in the spec's table "The theme":
    - `default_font = weighted(QUICKSAND_PATH, BODY_WEIGHT)`, `default_font_size = BODY_FONT_SIZE`; `Label/font_color = Palette.text(dark)`.
    - `Title`: font `weighted(BALOO_PATH, TITLE_WEIGHT)`, font size `TITLE_FONT_SIZE`, `font_color` text.
    - `Button`: font `weighted(BALOO_PATH, BUTTON_WEIGHT)`, size `BUTTON_FONT_SIZE`; `font_color`, `font_pressed_color`, `font_hover_color`, `font_hover_pressed_color`, `font_focus_color` all `Palette.text_on_accent(dark)`.
    - `Button/normal` and `Button/hover`: `StyleBoxFlat`, `bg_color = Palette.accent(dark)`, `border_color = Palette.accent_shadow(dark)`, `border_width_bottom = BUTTON_DEPTH` (other borders 0), all corner radii `BUTTON_RADIUS`, content margins left and right `BUTTON_PADDING_X`, top `BUTTON_PADDING_Y`, bottom `BUTTON_PADDING_Y + BUTTON_DEPTH`.
    - `Button/pressed`: the same, except `border_width_bottom = PRESSED_DEPTH`, `expand_margin_top = -(BUTTON_DEPTH - PRESSED_DEPTH)`, content margin top `BUTTON_PADDING_Y + BUTTON_DEPTH - PRESSED_DEPTH`, bottom `BUTTON_PADDING_Y + PRESSED_DEPTH`.
    - `Button/focus`: `StyleBoxEmpty`.
    - `PanelContainer/panel`: `StyleBoxFlat`, `bg_color = Palette.surface(dark)`, all borders `LINE_WIDTH` in `Palette.lines(dark)`, radii `PANEL_RADIUS`, all content margins `PANEL_PADDING`. `Sheet/panel`: the same with `SHEET_RADIUS` and `SHEET_PADDING`.

- [ ] **Step 1: Download the fonts.** Run `git ls-remote https://github.com/google/fonts refs/heads/main` and note the commit hash `C`. Then, with `C` substituted:
  ```bash
  mkdir -p assets/fonts
  curl -fL -o assets/fonts/Baloo2-Variable.ttf "https://raw.githubusercontent.com/google/fonts/C/ofl/baloo2/Baloo2%5Bwght%5D.ttf"
  curl -fL -o assets/fonts/OFL-Baloo2.txt "https://raw.githubusercontent.com/google/fonts/C/ofl/baloo2/OFL.txt"
  curl -fL -o assets/fonts/Quicksand-Variable.ttf "https://raw.githubusercontent.com/google/fonts/C/ofl/quicksand/Quicksand%5Bwght%5D.ttf"
  curl -fL -o assets/fonts/OFL-Quicksand.txt "https://raw.githubusercontent.com/google/fonts/C/ofl/quicksand/OFL.txt"
  file assets/fonts/*.ttf && sha256sum assets/fonts/*.ttf
  ```
  Expected: both `.ttf` files reported as TrueType font data, both `.txt` files contain "SIL OPEN FONT LICENSE". If the shell blocks `git ls-remote` or `curl`, stop and report BLOCKED; the controller fetches the files.
- [ ] **Step 2: Write `assets/fonts/LICENSE.md`**, in the style of `assets/sounds/LICENSE.md`: Baloo 2 and Quicksand, each with the copyright line from the top of its `OFL-*.txt`, both under the SIL Open Font License 1.1 (`https://openfontlicense.org`), unmodified, renamed only; the google/fonts commit `C`; the four source URLs; and a line per font `sha256 <hex>  Baloo2-Variable.ttf` (and Quicksand) with the sums from Step 1. Copy the copyright lines from each `OFL.txt`, do not invent them.
- [ ] **Step 3: Ship the licence texts.** In `export_presets.cfg` set `include_filter="assets/fonts/*.txt"`. Run `godot --headless --import`; it creates the two `.ttf.import` files.
- [ ] **Step 4: Write the failing test `tests/test_ui_theme.gd`** extending `BaseTest`. `_init` runs these, then `finish()`:
  - `_test_font_files`: for both paths, `FileAccess.file_exists(path)` and `load(path) is FontFile`; `FileAccess.file_exists` for both `OFL-*.txt`, and each text contains `"SIL OPEN FONT LICENSE"`.
  - `_test_font_licence`: `LICENSE.md` exists and contains `"SIL Open Font License"`, `"Baloo 2"`, `"Quicksand"`, `"github.com/google/fonts"`, and `FileAccess.get_sha256(path)` for each `.ttf` ("recorded sums match the files").
  - `_test_fonts_ship`: a `ConfigFile` loads `res://export_presets.cfg` with `OK`; `String(get_value("preset.0", "include_filter")).contains("assets/fonts/*.txt")`.
  - `_test_weighted`: `f := UiTheme.weighted(UiTheme.QUICKSAND_PATH, 600)`: `f.base_font.resource_path == UiTheme.QUICKSAND_PATH`; `f.variation_opentype[TextServerManager.get_primary_interface().name_to_tag("wght")] == 600`.
  - `_test_theme(dark: bool)`, run for `false` then `true`, with `t := UiTheme.build(dark)`, `n := t.get_stylebox("normal", "Button") as StyleBoxFlat`, `p := t.get_stylebox("pressed", "Button") as StyleBoxFlat`:
    - `(t.default_font as FontVariation).base_font.resource_path == UiTheme.QUICKSAND_PATH` and its weight 600; `t.default_font_size == 20`; `t.get_color("font_color", "Label") == Palette.text(dark)`.
    - Button font base path `BALOO_PATH`, weight 700, `t.get_font_size("font_size", "Button") == 22`; `font_color` and `font_pressed_color` `== Palette.text_on_accent(dark)`.
    - `n.bg_color == Palette.accent(dark)`, `n.border_color == Palette.accent_shadow(dark)`, `n.border_width_bottom == 5`, `n.border_width_top == 0`, `n.corner_radius_top_left == 8` and `n.corner_radius_bottom_right == 8`.
    - `p.border_width_bottom == 1`, `p.expand_margin_top == -4` (fails if Godot clamps the margin), `p.content_margin_top - n.content_margin_top == 4`, `p.content_margin_top + p.content_margin_bottom == n.content_margin_top + n.content_margin_bottom`, `p.bg_color == n.bg_color`.
    - `t.get_stylebox("hover", "Button") is StyleBoxFlat` with `bg_color == n.bg_color`; `t.get_stylebox("focus", "Button") is StyleBoxEmpty`.
    - Panel: `PanelContainer/panel` `bg_color == Palette.surface(dark)`, `border_color == Palette.lines(dark)`, `border_width_left == 1`, `corner_radius_top_left == 10`. `t.get_type_variation_base(UiTheme.SHEET) == &"PanelContainer"`, `Sheet/panel` radius 14 and `bg_color == Palette.surface(dark)`.
    - `t.get_type_variation_base(UiTheme.TITLE) == &"Label"`, `Title` font base path `BALOO_PATH`, weight 800, size 28.
  - `_test_modes_differ`: the normal Button `bg_color` of `build(false)` differs from `build(true)`.
- [ ] **Step 5: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_ui_theme.gd`. Expected: an error that `UiTheme` is not found.
- [ ] **Step 6: Implement `src/ui/ui_theme.gd`** as in the Interfaces block. Run `godot --headless --import`.
- [ ] **Step 7: Run it again.** `timeout 120 godot --headless --script tests/test_ui_theme.gd`. Expected: `0 failure(s)`.
- [ ] **Step 8: Commit.** `git add assets/fonts src/ui/ui_theme.gd tests/test_ui_theme.gd export_presets.cfg && git commit -m "feat: bundle the fonts and build the theme"`

### Task 3: The cleanup layout

**Files:**
- Create: `src/game/cleanup_layout.gd`, `tests/test_cleanup_layout.gd`

**Interfaces:**
- Consumes: `SeededRng.new`, `SeededRng.hash2`, `SeededRng.range_int`.
- Produces `class_name CleanupLayout extends RefCounted` in `src/game/cleanup_layout.gd`:
  - `const CLEANUP_STREAM := -3`, `const GAP_FRACTION := 0.14`, `const BOARD_GAP_FRACTION := 0.7`, `const BAND_WIDTH_FRACTION := 1.45`
  - `class Result:` with `var offsets := PackedVector2Array()` and `var extent := Rect2()`
  - `static func layout(home_bounds: Array[Rect2], board_size: Vector2, cell: float, seed_value: int, counter: int) -> Result`: `offsets[i]` belongs to `home_bounds[i]`; the placed rectangle is `Rect2(home_bounds[i].position + offsets[i], home_bounds[i].size)`.

The rules are the spec's "The layout". The algorithm, where the tests leave a choice:

```text
gap = GAP_FRACTION * cell; board_gap = BOARD_GAP_FRACTION * cell; band = BAND_WIDTH_FRACTION * board_size.x
rng = SeededRng.new(SeededRng.hash2(SeededRng.hash2(seed_value, CLEANUP_STREAM), counter))
order = [0 .. n-1]; for i from n-1 down to 1: swap order[i] with order[rng.range_int(0, i)]
area(i) = (w_i + gap) * (h_i + gap); top = shortest prefix of order with sum(area) >= total / 2; bottom = the rest
rows of a band: walk its items in order; start a new row when the row is not empty and row_width + gap + w > band
row width = sum(w) + gap * (count - 1); row height = max(h); row left = board_size.x / 2 - row_width / 2
item x = row left + widths and gaps before it; item y = row top + (row height - h) / 2
top band:    row 0 bottom = -board_gap;                 row k bottom = row k-1 top - gap
bottom band: row 0 top = board_size.y + board_gap;      row k top = row k-1 bottom + gap
offset = placed position - home position; extent = merge of every placed rect, Rect2() when n == 0
```

- [ ] **Step 1: Write the failing test `tests/test_cleanup_layout.gd`** extending `BaseTest`. Constants: `BOARD := Vector2(1536, 1024)`, `CELL := sqrt(1536.0 * 1024.0 / 400.0)`. In `_init`, `_cut_rects: Array[Rect2]` is the `bounds()` of each piece of `CutGenerator.generate_cut(1536, 1024, 400, CutGenerator.STYLE_REGULAR, 1)`. Helpers: `_placed(home: Array[Rect2], r: CleanupLayout.Result) -> Array[Rect2]`; `_squares(count: int) -> Array[Rect2]`, `count` rectangles `Rect2(Vector2(i * CELL, 0), Vector2(CELL, CELL))`. With `gap := CleanupLayout.GAP_FRACTION * CELL`, `board_gap := CleanupLayout.BOARD_GAP_FRACTION * CELL`, `band := CleanupLayout.BAND_WIDTH_FRACTION * BOARD.x`, and every test on `layout(_cut_rects, BOARD, CELL, 1, 0)` unless it says otherwise. `_init` runs these, then `finish()`:
  - `_test_empty`: `layout([], BOARD, CELL, 1, 0)`: `offsets.is_empty()`, `extent == Rect2()`.
  - `_test_every_cluster_placed`: `offsets.size() == 400`.
  - `_test_no_overlap_with_gap`: for every pair `i < j`, `not placed[i].grow(gap / 2 - 0.01).intersects(placed[j].grow(gap / 2 - 0.01))`; one `check` on the count of failing pairs being 0.
  - `_test_outside_board`: every placed `p` has `p.end.y <= -board_gap + 0.01 or p.position.y >= BOARD.y + board_gap - 0.01`.
  - `_test_two_bands_balanced`: above are those with `p.end.y <= 0`; with `a(i) = (w + gap) * (h + gap)`, `total`, `largest` the largest `a(i)`: both bands non-empty; `above_area >= total / 2`; `above_area - largest < total / 2`.
  - `_test_inside_band_width`: every placed `p` has `p.position.x >= (BOARD.x - band) / 2 - 0.01` and `p.end.x <= (BOARD.x + band) / 2 + 0.01`.
  - `_test_small_input_one_row_each`: `layout(_squares(4), ...)`: two above with `is_equal_approx(p.end.y, -board_gap)`, two below with `is_equal_approx(p.position.y, BOARD.y + board_gap)`; in each band, with `l` the left one and `r` the right one, `is_equal_approx(r.position.x - l.end.x, gap)` and `is_equal_approx((l.position.x + r.end.x) / 2, BOARD.x / 2)`.
  - `_test_bands_grow_outward`: `extent.position.y < -board_gap - 3 * CELL` and `extent.end.y > BOARD.y + board_gap + 3 * CELL` (400 pieces need several rows); the largest `end.y` among the rects above `is_equal_approx` `-board_gap`, and the smallest `position.y` among those below `is_equal_approx` `BOARD.y + board_gap` (row 0 is the one against the board).
  - `_test_wide_cluster`: input `_squares(6)` plus `Rect2(Vector2.ZERO, Vector2(2.0 * band, CELL))`: the wide one's centre x `is_equal_approx` `BOARD.x / 2`; no other placed rect overlaps its vertical span (`q.position.y < p.end.y and q.end.y > p.position.y` is false for every other `q`); the no-overlap check holds for all seven.
  - `_test_extent`: `extent` equals the merge of every placed rect and `extent.encloses(p)` for each.
  - `_test_deterministic`: two calls with the same arguments give equal `offsets`.
  - `_test_counter_and_seed_change_order`: on `_squares(10)`, where only the order can differ: counter 0 and counter 1 give different `offsets`; seed 1 and seed 2 (counter 0) give different `offsets`.
- [ ] **Step 2: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_cleanup_layout.gd`. Expected: an error that `CleanupLayout` is not found.
- [ ] **Step 3: Implement `CleanupLayout.layout`** as in the Interfaces block. Run `godot --headless --import`.
- [ ] **Step 4: Run it again.** `timeout 120 godot --headless --script tests/test_cleanup_layout.gd`. Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game/cleanup_layout.gd tests/test_cleanup_layout.gd && git commit -m "feat: lay out loose clusters in two bands"`

### Task 4: Cleanup on the board

**Files:**
- Create: `tests/test_board_cleanup.gd`
- Modify: `src/game/board.gd`, `tests/board_test.gd`, `tests/test_board_snapping.gd`

**Interfaces:**
- Consumes: Task 3's `CleanupLayout.layout` and `Result`.
- Produces on `Board`:
  - `const CLEANUP_DURATION := 0.4`
  - `var _base_bounds := Rect2(Vector2.ZERO, Vector2(IMAGE_SIZE)).grow(LOOSE_MARGIN)`; `_bounds` starts equal to it.
  - `var _cleanup_count := 0`
  - `func cleanup() -> void`: completes a running animation first; returns if `_held_root != -1`; the loose roots are `state.roots()` in ascending order without the locked ones; returns if there are none. Each root's home rect is the merge of `cut[id].bounds()` over `state.members(root)`. Calls `CleanupLayout.layout(rects, Vector2(IMAGE_SIZE), sqrt(float(IMAGE_SIZE.x) * IMAGE_SIZE.y / cut.size()), SEED, _cleanup_count)`, then `_cleanup_count += 1`, `state.move_cluster(root, offsets[k])` for each root, `_bounds = _base_bounds.merge(result.extent)`, `_set_camera_position(camera.position)`, and starts the tween. Never calls `drop`, `reparent` or `move_child`.
  - `func is_tidying() -> bool`: true while the cleanup tween runs.
  - The tween: `create_tween()`, one `tween_method` from `0.0` to `1.0` over `CLEANUP_DURATION`, `TRANS_CUBIC`, `EASE_OUT`; each step sets every moved cluster's member nodes to `from.lerp(to, t)`. Its `finished` calls a private `_finish_cleanup()`, which kills the tween, sets every moved node to exactly `state.offset_of(node.piece_id)`, and clears the bookkeeping. `_finish_cleanup()` does nothing when no tween runs.
  - `_finish_cleanup()` is also called at the top of `_on_touch` for a pressed event (before anything else) and in `_notification` for focus out and pause (before `_cancel_gesture`).
- Moves to `tests/board_test.gd`, unchanged, from `tests/test_board_snapping.gd`: `_inside_points`, `_grab_point`, `_is_loose_singleton`, `_loose_pair`, `_move_by_touch`.

- [ ] **Step 1: Move the five helpers** into `tests/board_test.gd` and delete them from `tests/test_board_snapping.gd`. Run `timeout 120 godot --headless --script tests/test_board_snapping.gd`. Expected: `0 failure(s)`.
- [ ] **Step 2: Write the failing test `tests/test_board_cleanup.gd`** extending `BoardTest`. Member recorders `_lifted: Array[Vector2i]`, `_joins := 0`, `_locks := 0`, connected in `_init`, and a member `_before: Dictionary`. `_init` awaits `process_frame`, calls `make_board()` and `_show_everything()`, joins one loose pair (`pair := _loose_pair(PackedInt32Array())`, `_move_by_touch(board.node_for(pair.x), board.node_for(pair.y).position)`), locks `_r`, the first loose singleton outside the pair with a `_grab_point` (`_move_by_touch(_r, Vector2.ZERO)`), runs the tests below in order, frees the board and calls `finish()`. Helpers: `_loose_roots() -> PackedInt32Array`, `board.state.roots()` without the locked ones, ascending; `_snapshot() -> Dictionary` of the roots, each root's `members` and `is_locked`; `_expected(counter: int) -> CleanupLayout.Result`, computed from `_loose_roots()` exactly as `cleanup()` describes; `_land()` awaits `process_frame` while `board.is_tidying()`, giving up after 2000 ms of `Time.get_ticks_msec()`; `_nodes_match_state() -> bool`, every node's `position == board.state.offset_of(piece_id)`. After the setup, reset `_joins` and `_locks` to 0.
  - `_test_ignored_while_holding`: press finger 0 at `_grab_point` of a loose singleton, record every node position, call `board.cleanup()`: `not board.is_tidying()`, `board._cleanup_count == 0`, no node moved. Release at the same point.
  - `_test_tidy_moves_state_at_once`: `_before = _snapshot()`, `e := _expected(0)`, record node positions, call `board.cleanup()`: `board.is_tidying()`; the `k`-th root of `_loose_roots()` has `board.state.offset_of(root) == e.offsets[k]`; `board._bounds == board._base_bounds.merge(e.extent)`; no node has moved yet ("the tween has not stepped").
  - `_test_tween_lands_exactly`: `await _land()`: `not board.is_tidying()`; `_nodes_match_state()`; `_r.position == Vector2.ZERO` and `_r.get_parent() == board.locked_pieces`; `_snapshot() == _before`; `_joins == 0` and `_locks == 0`; no two loose clusters' placed rects (home rect at their offset) overlap, and none intersects `Rect2(Vector2.ZERO, Vector2(Board.IMAGE_SIZE))`.
  - `_test_camera_reaches_every_cluster`: for every loose root, the centre `c` of its placed rect has `CameraRig.clamp_position(c, board._bounds) == c`.
  - `_test_touch_finishes_animation`: `e := _expected(1)`, `board.cleanup()`; `e.offsets != _expected(0).offsets`; pick a loose singleton `n`, `c := _inside_points(n)[0]`, `s := _to_screen(c + board.state.offset_of(n.piece_id))`; `_touch(0, s, true)`: `not board.is_tidying()`, `_nodes_match_state()`, `_lifted.back().x == board.state.find(n.piece_id)` ("the press lifts the cluster at its final place"). `_touch(0, s, false)`.
  - `_test_pause_finishes_animation`: `board.cleanup()`, `board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)`: `not board.is_tidying()`, `_nodes_match_state()`.
  - `_test_second_press_mid_animation`: `board.cleanup()`; `e := _expected(board._cleanup_count)`; `board.cleanup()` again: `board.is_tidying()`, each loose root's offset equals `e.offsets[k]`; `await _land()`: `_nodes_match_state()`.
  - `_test_nothing_loose_does_nothing`: lock every loose root in the state only (`board.state.move_cluster(root, Vector2.ZERO)`, `board.state.drop(root)`), record `board._cleanup_count`, `board._bounds` and every node position; `board.cleanup()`: `not board.is_tidying()`, count, bounds and positions unchanged.
- [ ] **Step 3: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_board_cleanup.gd`. Expected: an error that `cleanup` is not found on `Board`.
- [ ] **Step 4: Implement** the Interfaces block in `src/game/board.gd`.
- [ ] **Step 5: Run the board tests.** `godot --headless --import`, then `for t in test_board_cleanup test_board_snapping test_board_input test_feedback; do timeout 120 godot --headless --script "tests/$t.gd" || echo "FAILED $t"; done`. Expected: `0 failure(s)` each and no `FAILED` line.
- [ ] **Step 6: Commit.** `git add src/game/board.gd tests/board_test.gd tests/test_board_snapping.gd tests/test_board_cleanup.gd && git commit -m "feat: tidy loose clusters into bands with an animation"`

### Task 5: The HUD and its Tidy button

**Files:**
- Create: `src/ui/hud.gd`, `tests/test_hud.gd`
- Modify: `src/game/board.tscn`, `docs/technical-notes.md`

**Interfaces:**
- Consumes: `UiTheme.build()`, `UiTheme.BALOO_PATH`; `Board.cleanup()`, `Board.is_tidying()`; `FpsCounter.MARGIN_TOP`.
- Produces `class_name Hud extends CanvasLayer` in `src/ui/hud.gd`:
  - `const LAYER := 10`, `const CLEANUP_TEXT := "Tidy"`, `const BUTTON_SIZE := Vector2(120, 64)`, `const MARGIN_RIGHT := 16.0`, `const MARGIN_TOP := FpsCounter.MARGIN_TOP`
  - `@export var board: Board`; `var root_control: Control`; `var cleanup_button: Button`
  - `_ready`: `layer = LAYER`; `root_control` fills the viewport (`PRESET_FULL_RECT`), `mouse_filter = MOUSE_FILTER_IGNORE`, `theme = UiTheme.build()`; `cleanup_button` is its child, text `CLEANUP_TEXT`, `mouse_filter = MOUSE_FILTER_STOP`, `focus_mode = FOCUS_NONE`, anchored to the top right with its rect `BUTTON_SIZE` big, its right edge `MARGIN_RIGHT` from the viewport's right and its top at `MARGIN_TOP`; then `attach(board)` when `board` is set.
  - `attach(target: Board) -> void`: sets `board` and connects `cleanup_button.pressed` to `target.cleanup`.
- In `src/game/board.tscn`: an `ext_resource` for `res://src/ui/hud.gd` and a child `[node name="Hud" type="CanvasLayer" parent="." node_paths=PackedStringArray("board")]` with that script and `board = NodePath("..")`, after `Feedback`.

- [ ] **Step 1: Write the failing test `tests/test_hud.gd`** extending `BoardTest`. `_init` awaits `process_frame`, calls `make_board()`, sets `hud := board.get_node("Hud") as Hud`, awaits `process_frame` (so layout has run), runs these in order, frees the board and calls `finish()`; `b := hud.cleanup_button`, `r := b.get_global_rect()`:
  - `_test_hud_is_screen_space`: `hud is CanvasLayer`; `hud.layer == Hud.LAYER`; `hud.layer < (board.get_node("FpsCounter") as CanvasLayer).layer`; `hud.board == board`; `hud.root_control.mouse_filter == Control.MOUSE_FILTER_IGNORE`; `b.mouse_filter == Control.MOUSE_FILTER_STOP`; `b.text == "Tidy"`.
  - `_test_button_uses_theme`: `(b.get_theme_font("font") as FontVariation).base_font.resource_path == UiTheme.BALOO_PATH`; `b.get_theme_font_size("font_size") == UiTheme.BUTTON_FONT_SIZE`; `(b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Palette.accent()` and its `border_color == Palette.accent_shadow()`; `b.get_theme_color("font_color") == Palette.text_on_accent()`.
  - `_test_button_placement`: `r.size.is_equal_approx(Hud.BUTTON_SIZE)`; `is_equal_approx(r.end.x, viewport_size.x - Hud.MARGIN_RIGHT)`; `is_equal_approx(r.position.y, FpsCounter.MARGIN_TOP)` (clears the status bar); `r.end.y <= viewport_size.y * 0.25` (the bottom stays free for slots); when `board.get_node("FpsCounter")._label` is not null, its global rect does not intersect `r`.
  - `_test_button_does_not_zoom`: set `camera.zoom = camera.zoom * 2.0` and `camera.position += Vector2(300, 200)`, await `process_frame`: `b.get_global_rect() == r`.
  - `_test_button_touch_stays_in_hud`: `root.push_input` an `InputEventScreenTouch` (index 0, pressed, at `r.get_center()`), then the same released: `board._touches.is_empty()` and `board._mode == Board.Mode.IDLE` after the press ("a touch on the button never reaches the board").
  - `_test_press_tidies`: `b.pressed.emit()`: `board.is_tidying()`; then `board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)`: `not board.is_tidying()`.
  - `_test_hud_without_board`: `h := Hud.new()`, `root.add_child(h)`: `h.board == null`, `h.cleanup_button != null`, `h.cleanup_button.pressed.get_connections().is_empty()`; `h.free()`.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --import`, then `timeout 120 godot --headless --script tests/test_hud.gd`. Expected: an error that `Hud` or the `Hud` node is not found.
- [ ] **Step 3: Implement `Hud`** as in the Interfaces block and add it to `src/game/board.tscn`.
- [ ] **Step 4: Run it again.** `godot --headless --import`, then `timeout 120 godot --headless --script tests/test_hud.gd`. Expected: `0 failure(s)`. If only `_test_button_touch_stays_in_hud` fails, Godot is passing touches on a stopping control through to `_unhandled_input`: stop and report BLOCKED with the output instead of working around it in the board.
- [ ] **Step 5: Record the defaults.** In `docs/technical-notes.md`, after the "The cleanup button packs..." bullet add: "**default** `CleanupLayout` puts a gap of 0.14 cell between clusters and 0.7 cell between the board and the first row; each band is 1.45 board widths wide and grows outward from the board. The order is shuffled from the cut seed and a press counter. Clusters animate over 0.4 s (`Board.CLEANUP_DURATION`); a touch or app pause completes the animation at once. The camera bounds grow to cover the bands. The button is \"Tidy\", top right." Then, after the "Haptics:" group, add: "**default** The Godot theme is built by `UiTheme.build()` from `Palette` and the bundled fonts in `assets/fonts/` (SIL Open Font License): Quicksand 600 at 20 for body, Baloo 2 700 at 22 for buttons and 800 at 28 for titles, in viewport units."
- [ ] **Step 6: Run every test.** `godot --headless --import`, then `for t in tests/test_*.gd; do timeout 120 godot --headless --script "$t" || echo "FAILED $t"; done`. Expected: `0 failure(s)` for each file and no `FAILED` line.
- [ ] **Step 7: Commit.** `git add src/ui/hud.gd src/game/board.tscn tests/test_hud.gd docs/technical-notes.md && git commit -m "feat: add the HUD with a Tidy button"`

---

## Owner checks

These need eyes, hands or the phone, so they are not task steps. Run them after Task 5.

1. **Desktop:** `godot --path . res://src/game/board.tscn`. The Tidy button sits at the top right in Baloo 2 on amber with a darker band under it; pressing it with the mouse moves the face down and thins the band, and the text moves with the face. Releasing tidies: pieces glide into two bands above and below the board, nothing overlaps, locked pieces stay. Zooming and panning never move the button. Switch the desktop between light and dark and restart: the button colours follow.
2. **Phone, Nothing Phone (4a):** export and install the APK. With 400 loose pieces, tap Tidy: the frame-rate counter stays at the target during the 0.4 s animation; every tidied piece can be reached by panning; the button clears the status bar and camera cutout, does not cover the frame-rate counter, reads clearly and is easy to hit; the press feels physical. Touch a piece mid-animation: it is picked up at once from its final place. Tap Tidy again: a different arrangement. While one finger holds a piece, a second-finger tap on Tidy does nothing.
3. **Judge the look:** are the 8, 10 and 14 radii right in the app's units, and is the button size right? Record any changed constant in `docs/technical-notes.md`.
4. **Judge repeated tidies:** each Tidy press reshuffles every parked cluster, including big ones the player has built up and placed, and there is no undo. Say if that feels wrong.
