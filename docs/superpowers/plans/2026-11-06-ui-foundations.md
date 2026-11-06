# UI Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app starts inside one `AppShell` that holds a screen stack, and every colour, radius and accent comes from player settings, so later slices can add screens that all restyle together.

**Architecture:** `Settings` gains four look fields and a process-wide current instance. `Palette` keeps its function names but reads its values from a new `PaletteThemes` table through the current settings. `UiTheme.build` scales its radii by the roundness setting. `AppShell` is the new main scene: it owns the stack (push, pop, replace), the theme and the clear colour. `SetupScreen` and `Board` keep working and are only re-pointed so their screen swaps go through the shell when there is one. Two small helpers land for later slices: `SafeArea` and `FloatingNav`.

**Tech Stack:** Godot 4.7.2, GDScript, Mobile renderer. Tests are plain headless scripts extending `res://tests/base_test.gd`.

**Spec:** `docs/superpowers/specs/2026-11-06-ui-rebuild-design.md` (slice 1). Reference design: `docs/prototype/ui-flow.html`. Also read `INTENT.md`, `AGENTS.md` and `docs/visual-design.md`.

## Global Constraints

- Godot 4.7.2, GDScript, Mobile renderer, Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies, plugins or network calls.
- Midnight table with Baloo 2 and Quicksand stays the default and every default value stays exactly as `docs/visual-design.md` locks it. All existing tests must keep passing unchanged unless a task says otherwise.
- Palette function names and signatures (`Palette.accent(dark := is_dark())` and the rest) do not change.
- Viewport 540 by 1200 portrait. Reference pixels times 1.5 give Godot pixels.
- Settings stay in `user://settings.cfg`, apart from the save. A missing, unreadable or foreign value means its default, never a crash.
- No per-frame work added. Cut output, save format (`SaveGame.VERSION` stays) and piece behaviour do not change.
- Tests: `godot --headless --import` after adding a file with a new `class_name` or an asset. Run with `timeout 120 godot --headless --script tests/<name>.gd`. A pass prints `0 failure(s)`. Tests use their own `user://test_*` paths and never touch the real save or settings. Test helpers have no `class_name`.
- Match the surrounding code style: tabs, sparse comments that explain why. Conventional commits, one per task, including any `.uid` and `.import` files Godot creates.

## Review Focus

- A settings file with a wrong type or an unknown value (theme `"neon"`, mode `5`, accent `"red"`, roundness `900`) loads as defaults or clamps, and never errors (Task 1, `_test_bad_values`).
- A light custom accent must give dark text on it and a dark accent white text, in both modes (Task 2, `_test_accent_contrast`).
- Roundness 0 gives square corners everywhere, including the slider grabber, and 250 keeps a pressed button's height unchanged (Task 3, `_test_roundness_zero`, `_test_roundness_max_keeps_footprint`).
- Popping the only screen does nothing and says so; replacing leaves no orphan node; pushing the screen that is already on top is ignored (Task 4, `_test_pop_at_root`, `_test_replace_frees_old`, `_test_push_same_screen`).
- A desktop with no safe area reports zero insets, and a safe rect larger than the window is clamped (Task 5, `_test_no_safe_area`, `_test_oversized_safe_rect`).

---

### Task 1: Look settings

**Files:**
- Modify: `src/game/settings.gd`
- Create: `tests/test_settings_look.gd`

**Interfaces:**
- Produces, all in `Settings`:
  - `const THEMES: Array[String] = ["midnight", "orchard", "berry", "slate"]`
  - `const MODES: Array[String] = ["auto", "light", "dark"]`
  - `const ROUNDNESS_MIN := 0`, `const ROUNDNESS_MAX := 250`, `const ROUNDNESS_DEFAULT := 100`
  - `var theme := "midnight"`, `var mode := "auto"`, `var accent := ""` (empty means the theme's own, else lowercase `#rrggbb`), `var roundness := 100`
  - `static func current() -> Settings` returns the process-wide instance, a plain `Settings.new()` until `use` is called
  - `static func use(settings: Settings) -> void`
  - `static func is_valid_accent(value: Variant) -> bool`

- [ ] **Step 1: Write `tests/test_settings_look.gd`**, using `user://test_settings_look.cfg`, deleted at start and end. Tests, each with the assertions listed:
  - `_test_defaults`: a missing file loads `theme == "midnight"`, `mode == "auto"`, `accent == ""`, `roundness == 100`; `sound` and `vibration` stay true.
  - `_test_round_trip`: set `theme = "berry"`, `mode = "dark"`, `accent = "#6fdc97"`, `roundness = 160`, `sound = false`, save, load: all five equal what was set.
  - `_test_bad_values`: write a file with `ConfigFile` holding `look/theme = "neon"`, `look/mode = 5`, `look/accent = "red"`, `look/roundness = 900`. Load: `theme == "midnight"`, `mode == "auto"`, `accent == ""`, `roundness == 250`. A second file with `roundness = -4` loads as `0`; one with `roundness = "wide"` loads as `100`.
  - `_test_accent_normalised`: `"#FFC857"` loads as `"#ffc857"`; `is_valid_accent("#ffc85")` is false, `is_valid_accent("#ffc857")` is true, `is_valid_accent(3)` is false.
  - `_test_current`: `Settings.current()` is not null and returns the same object twice; after `Settings.use(s)` it returns `s`. End the test with `Settings.use(Settings.new())` so no state leaks.

- [ ] **Step 2: Run it, expect FAIL** (`THEMES` not declared): `timeout 120 godot --headless --script tests/test_settings_look.gd`

- [ ] **Step 3: Implement in `src/game/settings.gd`.** Look fields live in a new config section `look`; the existing `feedback` section is untouched. `load_from` validates each field: theme in `THEMES` else default; mode in `MODES` else default; accent through `is_valid_accent` then lowercased else `""`; roundness an int or float clamped to the min and max, anything else the default. `save_to` writes the four new keys. `current()` keeps a `static var _current: Settings`.

- [ ] **Step 4: Run it, expect `0 failure(s)`.** Also run `tests/test_settings_sheet.gd` and `tests/test_feedback.gd`, both must still pass.

- [ ] **Step 5: Commit** `feat: add theme, mode, accent and roundness to the settings`

---

### Task 2: Data-driven palette

**Files:**
- Create: `src/game/palette_themes.gd`
- Modify: `src/game/palette.gd`, `tests/test_palette.gd`

**Interfaces:**
- Consumes: `Settings.current()`, `Settings.THEMES` (Task 1).
- Produces:
  - `class_name PaletteThemes extends RefCounted` with `enum Role { PAGE, SURFACE, RAISED, TEXT, MUTED, LINES, ACCENT, ON_ACCENT, ACCENT_SHADOW, FELT, BOARD }` and `static func color(theme_id: String, dark: bool, role: Role) -> Color` (an unknown id falls back to `"midnight"`).
  - `Palette.is_dark() -> bool` now follows `Settings.current().mode`: `"dark"` is true, `"light"` is false, `"auto"` is the device mode as before.
  - `Palette.luminance(color: Color) -> float`, the relative luminance with the sRGB curve (`v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)`, weights 0.2126, 0.7152, 0.0722).
  - Every existing `Palette` function keeps its name and signature and reads `PaletteThemes.color(Settings.current().theme, dark, role)`, except these three when `Settings.current().accent` is not empty: `accent(dark)` returns that colour; `accent_shadow(dark)` returns it with r, g and b each multiplied by 0.62; `text_on_accent(dark)` returns `#1c1400` when `luminance(accent) > 0.35`, else white.
  - `Palette.outline()` is unchanged.

- [ ] **Step 1: Extend `tests/test_palette.gd`.** Keep every existing check. Before them, call `Settings.use(Settings.new())`. Add:
  - `_test_themes`: for each of `orchard`, `berry`, `slate` and `midnight`, in light and dark, all eleven roles equal the values of the reference's `THEMES` array in `docs/prototype/ui-flow.html` (`L` is light, `D` is dark, order bg, surf, raise, text, mute, line, acc, onacc, accsh, felt, board). Read them from that file's array when writing the test and write them out as `Color.html` literals.
  - `_test_unknown_theme`: `PaletteThemes.color("nope", false, PaletteThemes.Role.ACCENT) == Color.html("#e2a41f")`.
  - `_test_settings_drive_palette`: after `Settings.use(s)` with `theme = "berry"`, `Palette.accent(true) == Color.html("#ff7ac8")` and `Palette.felt(false)` is berry's light felt. Reset with `Settings.use(Settings.new())`.
  - `_test_mode`: with `mode = "dark"`, `Palette.is_dark()` is true; with `"light"`, false. (Do not assert on `"auto"`, it depends on the machine.)
  - `_test_accent_override`: `accent = "#6fdc97"` gives `Palette.accent(false) == Color.html("#6fdc97")`, `accent_shadow(false)` with each channel within 0.001 of 0.62 times the accent's, and the same accent in dark mode.
  - `_test_accent_contrast`: `accent = "#ffc857"` gives `text_on_accent(false) == Color.html("#1c1400")`; `accent = "#7a1fd6"` gives `text_on_accent(false) == Color.white`; the same two in dark mode. With `accent = ""`, `text_on_accent` is `#2a1d00` again.

- [ ] **Step 2: Run it, expect FAIL**: `timeout 120 godot --headless --import` then `timeout 120 godot --headless --script tests/test_palette.gd`

- [ ] **Step 3: Implement.** `PaletteThemes` holds one constant per theme with two `PackedStringArray`s of eleven hex strings and converts with `Color.html`. Rewrite `palette.gd`'s functions as one-line lookups. Keep the doc comment, updated to say the colours follow the current settings.

- [ ] **Step 4: Run the palette test, then `tests/test_ui_theme.gd` and `tests/test_slot_tray.gd` and `tests/test_hud.gd`.** All print `0 failure(s)`.

- [ ] **Step 5: Commit** `feat: make the palette follow the theme, mode and accent settings`

---

### Task 3: Roundness in the theme

**Files:**
- Modify: `src/ui/ui_theme.gd`, `tests/test_ui_theme.gd`

**Interfaces:**
- Consumes: `Settings.current().roundness` (Task 1).
- Produces:
  - `UiTheme.scaled(base: int, roundness: int) -> int` is `roundi(base * roundness / 100.0)`.
  - `UiTheme.build(dark := Palette.is_dark(), roundness := Settings.current().roundness) -> Theme`. The radius constants (`BUTTON_RADIUS`, `PANEL_RADIUS`, `SHEET_RADIUS`, `OPTION_RADIUS`, `SLIDER_RADIUS`) stay as the base values at 100 percent; every use goes through `scaled`.

- [ ] **Step 1: Extend `tests/test_ui_theme.gd`.** Keep every existing check (they run at the default). Add, calling `UiTheme.build(false, r)`:
  - `_test_scaled`: `scaled(8, 100) == 8`, `scaled(8, 0) == 0`, `scaled(10, 250) == 25`, `scaled(9, 150) == 14`.
  - `_test_roundness_zero`: at 0 the button, panel, sheet and option styleboxes have corner radius 0, the slider track radius is 0, and the grabber's pixel `(0, 0)` has alpha 1.0 (a square tile, not the half-transparent corner an unguarded radius 0 would paint).
  - `_test_roundness_max`: at 250 button radius is 20, panel 25, sheet 35, option 22.
  - `_test_roundness_max_keeps_footprint`: at 250 the pressed button's `content_margin_top + content_margin_bottom` still equals the normal one's.
  - `_test_roundness_default`: `UiTheme.build(false)` equals `UiTheme.build(false, 100)` in button radius, with `Settings.use(Settings.new())` set first.

- [ ] **Step 2: Run it, expect FAIL**: `timeout 120 godot --headless --script tests/test_ui_theme.gd`

- [ ] **Step 3: Implement.** Thread `roundness` through `_button_box`, `_panel_box`, `_add_option`, `_add_slider`, `_flat` and `_rounded_tile`. `_rounded_tile` returns the solid filled image when the radius is 0 or less.

- [ ] **Step 4: Run `test_ui_theme.gd`, `test_setup_screen.gd`, `test_settings_sheet.gd`.** All print `0 failure(s)`.

- [ ] **Step 5: Commit** `feat: scale the theme's corner radii by the roundness setting`

---

### Task 4: AppShell and the screen stack

**Files:**
- Create: `src/ui/app_shell.gd`, `src/ui/app_shell.tscn`, `tests/test_app_shell.gd`
- Modify: `src/ui/setup_screen.gd` (lines 140-145 `open`, 275-276 `_launch`), `project.godot` (`run/main_scene`)

**Interfaces:**
- Consumes: `Settings.use`, `Settings.load_from` (Task 1), `Palette.page_background()` (Task 2), `UiTheme.build()` (Task 3).
- Produces, in `class_name AppShell extends Control`:
  - `signal look_applied`
  - `var settings_path := Settings.DEFAULT_PATH`
  - `var make_home := Callable()` returns the root screen (`Node`); the default, when invalid, instantiates `SetupScreen.SCENE`
  - `func push(screen: Node) -> void`: does nothing if `screen` is already the top; otherwise takes the current top out of the tree but keeps it, then adds `screen`
  - `func pop() -> bool`: at depth 1 does nothing and returns false; otherwise frees the top, puts the previous screen back and returns true
  - `func replace(screen: Node) -> void`: frees the top (`queue_free`) and adds `screen` in its place; depth is unchanged
  - `func top() -> Node` (null when empty), `func depth() -> int`
  - `func apply_look() -> void`: sets the clear colour to `Palette.page_background()`, rebuilds `theme` with `UiTheme.build()`, emits `look_applied`
  - `static func find(tree: SceneTree) -> AppShell`: the first node in group `"app_shell"` or null
  - `static func present(tree: SceneTree, screen: Node) -> void`: `find(tree).replace(screen)` when a shell exists, else `tree.change_scene_to_node(screen)`
- A pushed or replacing `Control` screen gets full-rect anchors. A `Node2D` screen (the board) is added as is.
- `_ready` adds the shell to the `"app_shell"` group, sets full-rect anchors, calls `Settings.use(Settings.load_from(settings_path))`, then `apply_look()`, then pushes the home screen.

- [ ] **Step 1: Write `tests/test_app_shell.gd`.** It builds shells with `settings_path = "user://test_app_shell.cfg"` (deleted at start and end) and `make_home` returning a fresh `Control`. Tests:
  - `_test_ready`: after adding to `root`, `depth() == 1`, `top()` is the home control and is in the tree, `AppShell.find(self)` returns the shell, and `Settings.current()` is the loaded one (write a file with `theme = "berry"` first and check `Settings.current().theme == "berry"`).
  - `_test_push_pop`: push a second control: `depth() == 2`, the home control is not in the tree but is not freed, `top()` is the new one. `pop()` returns true, the new one is freed, the home control is back in the tree.
  - `_test_pop_at_root`: `pop()` returns false, `depth() == 1`, home still in the tree.
  - `_test_push_same_screen`: pushing the current top leaves `depth() == 1`.
  - `_test_replace_frees_old`: replace home with a new control: `depth() == 1`, `top()` is the new one, and after `await process_frame` the old one is freed (`is_instance_valid` false) and the shell has exactly one child besides internal ones.
  - `_test_node2d_screen`: replacing with a `Node2D` works and is a child of the shell.
  - `_test_apply_look`: set `Settings.current().theme = "orchard"`, call `apply_look()`, the signal fired once, and `theme.get_stylebox("normal", "Button").bg_color == Palette.accent()`.
  - `_test_present`: with a shell in the tree `AppShell.present(self, node)` replaces the top; with the shell freed, `present` calls `change_scene_to_node` (assert `current_scene == node`).
  - End by freeing everything and `Settings.use(Settings.new())`.

- [ ] **Step 2: Run it, expect FAIL**: `timeout 120 godot --headless --import` then `timeout 120 godot --headless --script tests/test_app_shell.gd`

- [ ] **Step 3: Implement `AppShell` and `app_shell.tscn`** (one `Control` node with the script). In `setup_screen.gd` replace both `tree.change_scene_to_node(...)` calls with `AppShell.present(tree, ...)`. Set `run/main_scene` to `res://src/ui/app_shell.tscn`. Nothing else in `setup_screen.gd` or `board.gd` changes: both keep their own back handling.

- [ ] **Step 4: Run the new test, then the whole existing suite.** Run every `tests/test_*.gd` in a loop: `for t in tests/test_*.gd; do echo $t; timeout 120 godot --headless --script $t 2>&1 | tail -1; done`. Every line must say `0 failure(s)`. `tests/test_setup_flow.gd` and `tests/test_board_save.gd` are the ones that prove the screen swap still works without a shell.

- [ ] **Step 5: Run the app headless for two seconds with the shell as main scene** (`timeout 5 godot --headless --quit-after 120`) and confirm the output holds no `ERROR` or `WARNING` line.

- [ ] **Step 6: Commit** `feat: start the app in an AppShell with a screen stack`

---

### Task 5: Safe area

**Files:**
- Create: `src/ui/safe_area.gd`, `tests/test_safe_area.gd`
- Modify: `src/ui/app_shell.gd`

**Interfaces:**
- Produces, in `class_name SafeArea extends RefCounted`:
  - `static func insets(window_size: Vector2i, safe_rect: Rect2i, viewport_size: Vector2) -> Vector4` returns (left, top, right, bottom) in viewport units: each side's gap between the window and the safe rect, scaled by `viewport_size / window_size`. An empty safe rect or an empty window gives `Vector4.ZERO`. A safe rect that extends past the window is clamped to it, so no inset is negative.
  - `static func current(tree: SceneTree) -> Vector4` calls `insets` with the real `DisplayServer` window size, `DisplayServer.get_display_safe_area()` and the root viewport's visible rect size.
- `AppShell` gains `func safe_insets() -> Vector4` returning `SafeArea.current(get_tree())`.

- [ ] **Step 1: Write `tests/test_safe_area.gd`.**
  - `_test_notch`: window 1080 by 2400, safe rect `(0, 90, 1080, 2250)`, viewport 540 by 1200 gives `Vector4(0, 45, 0, 30)`.
  - `_test_sides`: window 1080 by 2400, safe rect `(40, 0, 1000, 2400)` gives `Vector4(20, 0, 10, 0)`.
  - `_test_no_safe_area`: an empty safe rect gives `Vector4.ZERO`; so does a zero-size window.
  - `_test_oversized_safe_rect`: safe rect `(-50, -50, 2000, 3000)` in the same window gives `Vector4.ZERO`.
  - `_test_current_is_not_negative`: `SafeArea.current(self)` has every component at or above 0.

- [ ] **Step 2: Run it, expect FAIL**: `timeout 120 godot --headless --import` then `timeout 120 godot --headless --script tests/test_safe_area.gd`

- [ ] **Step 3: Implement `SafeArea` and `AppShell.safe_insets`.** No screen consumes it yet; slices 3 and 4 replace the fixed 56-unit top insets with it.

- [ ] **Step 4: Run `test_safe_area.gd` and `test_app_shell.gd`.** Both `0 failure(s)`.

- [ ] **Step 5: Commit** `feat: add a safe-area helper in viewport units`

---

### Task 6: Floating nav

**Files:**
- Create: `src/ui/floating_nav.gd`, `assets/icons/home.svg`, `assets/icons/image.svg`, `assets/icons/cal.svg`, `assets/icons/set.svg`, `assets/icons/LICENSE.md`, `tests/test_floating_nav.gd`
- Modify: `src/ui/ui_theme.gd` (add the `NAV` variation)

**Interfaces:**
- Consumes: `UiTheme.OPTION`, `UiTheme.scaled`, `Settings.current().roundness`.
- Produces:
  - `UiTheme.NAV := &"Nav"`, a `PanelContainer` variation with the surface fill, the line colour, content margin 5 and corner radius `scaled(SHEET_RADIUS * 2, roundness)`.
  - `class_name FloatingNav extends PanelContainer` with `const TABS := [[&"home", "Home"], [&"pictures", "Pictures"], [&"daily", "Daily"], [&"settings", "Settings"]]`, `signal tab_pressed(id: StringName)`, `var buttons: Dictionary` (id to `Button`), `var active := &""`, `func set_active(id: StringName) -> void` (an id not in `TABS` is ignored).
  - Four equal-width toggle buttons in a `HBoxContainer`, in one `ButtonGroup`, theme variation `UiTheme.OPTION`, each showing its icon above its label. The active one shows the accent look. A press emits `tab_pressed` once, and `set_active` does not emit.
  - Icons are the four SVGs, drawn white with a 2.4 stroke in a 24 by 24 view box, tinted by the button's icon colours. The path data comes from the `P` object in `docs/prototype/ui-flow.html` (`home`, `image`, `cal`, `set`). `LICENSE.md` says they are the project's own work, CC BY 4.0.

- [ ] **Step 1: Write `tests/test_floating_nav.gd`.**
  - `_test_tabs`: four buttons in the order Home, Pictures, Daily, Settings, each with a non-null icon and the label as its text.
  - `_test_set_active`: `set_active(&"daily")` makes only that button `button_pressed`, `active == &"daily"`, and no signal fired; `set_active(&"nope")` changes nothing.
  - `_test_press_emits_once`: `buttons[&"pictures"].pressed.emit()` through a real press (`button_pressed = true` emits `toggled`; use `buttons[&"pictures"]._pressed()` or `emit_signal("pressed")`, whichever the existing `test_slot_tray.gd` uses for buttons) fires `tab_pressed` with `&"pictures"` exactly once.
  - `_test_theme`: with a built theme applied, the panel's stylebox is the `Nav` one with the surface fill.

- [ ] **Step 2: Run it, expect FAIL**: `timeout 120 godot --headless --import` then `timeout 120 godot --headless --script tests/test_floating_nav.gd`

- [ ] **Step 3: Implement.** Add the `NAV` variation to `UiTheme` (and one assertion for it to `tests/test_ui_theme.gd`). The nav is not mounted on any screen in this slice.

- [ ] **Step 4: Run `test_floating_nav.gd` and `test_ui_theme.gd`.** Both `0 failure(s)`.

- [ ] **Step 5: Commit** `feat: add the floating tab bar control`

---

### Task 7: Whole-slice check

**Files:**
- Modify: `docs/v2-status.md` is not touched. Create `docs/ui-rebuild-status.md`.

- [ ] **Step 1: Run the whole suite** (`godot --headless --import` first, then the loop from Task 4 Step 4). Every file prints `0 failure(s)`. Any other `ERROR` or `WARNING` line that is not one of the deliberate ones the tests capture is a failure.

- [ ] **Step 2: Run the app in a window for a manual check** (`godot --path .`): the setup screen appears as before, Start opens a board, Home returns, and nothing prints an error. Switch `theme` to `"berry"` in `user://settings.cfg`, relaunch and confirm the colours change.

- [ ] **Step 3: Write `docs/ui-rebuild-status.md`**: one paragraph on what slice 1 built, a table of slices with their state (slice 1 built, the rest not started), and the calls made while building it that the owner can overturn.

- [ ] **Step 4: Commit** `docs: record the state of the UI rebuild after slice 1`
