# Board and Piece Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A 400-piece grid-cut puzzle board on which pieces drag with one finger and the camera pinch-zooms and pans, running on the desktop and on the Nothing Phone (4a), with a frame-rate counter.

**Architecture:** A pure-logic cut generator (`src/cut/`) builds a graph of vertices and faces and turns it into pieces. The game layer (`src/game/`) draws each piece as a `Polygon2D` whose texture coordinates are its outline, keeps the board and pieces in one world, and moves a `Camera2D` through small pure helpers that are unit tested. Positions: outlines are in image coordinates, and a piece node's `position` is its displacement from home, so a solved piece has `position == Vector2.ZERO`.

**Tech Stack:** Godot 4.7.2, GDScript, Mobile renderer. Tests are plain headless scripts.

**Spec:** `docs/superpowers/specs/2026-10-22-board-and-piece-movement-design.md`. Also read `INTENT.md` and `AGENTS.md`.

## Global Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android Min SDK is 29 with this renderer.
- Package name `io.github.aaryash_shakya.pieceful`. Do not change it.
- Layout: generator in `src/cut/`, board, camera and input in `src/game/`, UI in `src/ui/`, tests in `tests/`.
- Generation is deterministic. Use the project's own `SeededRng`, never the engine's global random. Round generated points to a fixed precision.
- The generator exposes `generate_cut(width, height, target_count, style, seed)` and has no dependency on scenes or nodes.
- Every style produces a graph of vertices and shared edges, with pieces as the faces between them. No separate pipeline per style.
- Never store piece geometry. Only image, style, count and seed identify a cut.
- Pieces are drawn with `Polygon2D`. Hit-testing uses `Geometry2D.is_point_in_polygon`. Pieces never rotate.
- Piece outline: dark, about 2.3 px wide, 80% opacity. Palette values come from `docs/visual-design.md`.
- 400 pieces must hold 60 fps while dragging and while pinch-zooming and panning on the Nothing Phone (4a). Record the refresh rate for each check.
- No new dependencies, analytics or network calls. Match the style of the surrounding code and keep comments sparse.
- Commit after each task using conventional commit messages.

## Review Focus

- Generator with `target_count` 1, a count larger than the pixel grid allows, or an extreme shape such as 10000 by 100: still valid pieces, no zero-area piece (Task 2).
- A second finger lands while a piece is being dragged: the piece stays where it is, nothing is stuck held, no jump (Task 7).
- One finger lifts during a pinch: the remaining finger must not pan or jump the camera until all fingers are up (Task 7).
- Panning or zooming far beyond the loose area: the camera clamps and the board can never be lost (Tasks 4 and 7).
- A cancelled touch (a system gesture or notification during a drag) is treated as a release and leaves no piece held (Task 7).

---

### Task 1: Test harness and seeded random generator

**Files:**
- Create: `tests/base_test.gd`, `tests/test_seeded_rng.gd`, `src/cut/seeded_rng.gd`

**Interfaces:**
- Produces: `BaseTest extends SceneTree` with `check(condition: bool, message: String) -> void` and `finish() -> void` (prints the failure count, calls `quit(1)` if any failed, else `quit(0)`). Every later test extends it and calls `finish()` at the end of `_init()`.
- Produces: `SeededRng extends RefCounted` with `_init(seed_value: int)`, `next_u32() -> int`, `next_float() -> float` (in [0, 1)), `range_float(from: float, to: float) -> float`, `range_int(from: int, to_inclusive: int) -> int`.

- [ ] **Step 1: Write `tests/base_test.gd` and the failing test `tests/test_seeded_rng.gd`.** Assertions: `SeededRng.new(1).next_u32() == 270369`; two `SeededRng.new(42)` produce the same first 5 `next_u32()` values; 1000 draws of `SeededRng.new(7).next_float()` are all `>= 0.0` and `< 1.0`; `range_int(3, 5)` over 1000 draws only returns 3, 4 or 5 and returns all three.
- [ ] **Step 2: Build the class cache and run the test, expecting failure.** Run: `godot --headless --import` then `godot --headless --script tests/test_seeded_rng.gd`. Expected: errors about `SeededRng` not found. Repeat the `--import` whenever a file with a new `class_name` is added.
- [ ] **Step 3: Implement `SeededRng`.** Use xorshift32 (shifts 13, 17, 5) with the state masked to 32 bits after every step, because GDScript ints are signed 64-bit. A seed of 0 becomes 1. `next_float()` is `next_u32() / 4294967296.0`.
- [ ] **Step 4: Run again.** Expected: `0 failure(s)`, exit code 0.
- [ ] **Step 5: Commit.** `git add tests src/cut && git commit -m "test: add headless test harness and seeded random generator"`

### Task 2: Cut generator, grid style

**Files:**
- Create: `src/cut/cut_piece.gd`, `src/cut/cut_graph.gd`, `src/cut/cut_generator.gd`, `tests/test_cut_generator.gd`

**Interfaces:**
- Consumes: nothing (the grid style needs no randomness yet).
- Produces: `CutPiece extends RefCounted` with `id: int` (index in the returned array), `outline: PackedVector2Array` (closed implicitly, image coordinates), `home: Vector2` (centre of the outline's bounding rectangle), `neighbours: PackedInt32Array`, `area() -> float` (shoelace), `bounds() -> Rect2`.
- Produces: `CutGraph extends RefCounted` with `vertices: PackedVector2Array`, `faces: Array[PackedInt32Array]` (vertex indices, the same winding for every face so a shared edge is traversed in opposite directions), `edge_use_counts() -> Dictionary` (key `Vector2i(min_index, max_index)`, value how many faces use that edge).
- Produces: `CutGenerator` with `const STYLE_GRID := "grid"`, `static grid_split(width: int, height: int, target_count: int) -> Vector2i` (x = columns, y = rows), `static build_grid_graph(width: int, height: int, columns: int, rows: int) -> CutGraph`, `static generate_cut(width: int, height: int, target_count: int, style: String, seed: int) -> Array[CutPiece]`.

- [ ] **Step 1: Write the failing test `tests/test_cut_generator.gd`.** A helper `check_cut(pieces, w, h, count_hint)` asserts: summed `area()` equals `w * h`; every piece's area is at least half of `w * h / pieces.size()`; neighbour lists are symmetric and never contain the piece itself; in the graph for the same split every edge count is 1 or 2, and the number of edges with count 1 equals `2 * (columns + rows)`. Run it for counts 1, 12, 54, 150 and 400 at 1536 by 1024. Also assert: `grid_split(1500, 1000, 54) == Vector2i(9, 6)` and `grid_split(1500, 1000, 150) == Vector2i(15, 10)`; for 400 at 1536 by 1024 the product is within 40 of 400 and the cell aspect ratio is between 0.8 and 1.25; `generate_cut(10000, 100, 50, "grid", 1)` passes `check_cut`; two calls with the same inputs give equal outlines and neighbours; an unknown style, a width of 0 and a `target_count` of 0 each return an empty array.
- [ ] **Step 2: Run it.** `godot --headless --import` then `godot --headless --script tests/test_cut_generator.gd`. Expected: FAIL, classes not found.
- [ ] **Step 3: Implement the three classes.** Grid boundaries are integers (`roundi(i * width / float(columns))`) so areas sum exactly. `grid_split` picks the rows and columns whose product is closest to `target_count` among splits with near-square cells. `generate_cut` is `grid_split` then `build_grid_graph` then a conversion of faces to pieces, with neighbours found from edges shared between two faces. Round every point to 3 decimals with `snappedf`. For invalid input call `push_error` and return an empty array. The `seed` parameter name follows `AGENTS.md`. Rename it if the shadowing warning is treated as an error.
- [ ] **Step 4: Run again.** Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/cut tests && git commit -m "feat: add grid cut generator with graph of shared edges"`

### Task 3: Scatter

**Files:**
- Create: `src/game/scatter.gd`, `tests/test_scatter.gd`

**Interfaces:**
- Consumes: `CutPiece.bounds()`, `SeededRng`.
- Produces: `Scatter.scatter(pieces: Array[CutPiece], image_size: Vector2, margin: float, seed: int) -> PackedVector2Array`, one displacement per piece in array order, to be used as the piece node's `position`.

- [ ] **Step 1: Write the failing test.** With 400 pieces from `generate_cut(1536, 1024, 400, "grid", 1)`, `image_size` (1536, 1024), margin 768: result size equals piece count; for each piece, its bounds moved by its displacement do not intersect `Rect2(0, 0, 1536, 1024)` and are enclosed by that rect grown by 768; the same seed twice gives equal results; seeds 1 and 2 differ.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_scatter.gd`.
- [ ] **Step 3: Implement `Scatter.scatter`.** Pieces may overlap each other. Use a `SeededRng` for positions. The algorithm is the builder's choice, for example random points in the outer rectangle with rejection of those that overlap the board.
- [ ] **Step 4: Run again.** Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game tests && git commit -m "feat: add deterministic scatter of loose pieces around the board"`

### Task 4: Camera helpers

**Files:**
- Create: `src/game/camera_rig.gd`, `tests/test_camera_rig.gd`

**Interfaces:**
- Produces: `CameraRig` with `const MIN_ZOOM := 0.15`, `const MAX_ZOOM := 3.0`, `static clamp_zoom(zoom: float) -> float`, `static clamp_position(position: Vector2, bounds: Rect2) -> Vector2`, `static zoom_about(camera_position: Vector2, old_zoom: float, new_zoom: float, anchor_offset: Vector2) -> Vector2` (returns the new camera position that keeps the world point under the anchor fixed, where `anchor_offset` is the anchor's screen position minus the viewport centre), `static edge_pan_velocity(screen_position: Vector2, viewport_size: Vector2, margin: float, max_speed: float) -> Vector2` (screen pixels per second, pointing toward the edge being approached, zero beyond `margin` from every edge, `max_speed` at the edge, linear in between).

- [ ] **Step 1: Write the failing test.** `zoom_about(Vector2(100, 50), 1.0, 2.0, Vector2(40, 20)) == Vector2(120, 60)`; `clamp_zoom(0.01) == CameraRig.MIN_ZOOM` and `clamp_zoom(99.0) == CameraRig.MAX_ZOOM`; `clamp_position(Vector2(500, -500), Rect2(-100, -100, 200, 200)) == Vector2(100, -100)`; for a 540 by 1200 viewport, margin 48, max speed 600: `edge_pan_velocity(Vector2(5, 600), ...)` has x close to -537.5 and y 0, `Vector2(270, 600)` gives `Vector2.ZERO`, and `Vector2(535, 1195)` has both components positive.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_camera_rig.gd`.
- [ ] **Step 3: Implement the four static functions.** The zoom formula is `camera_position + anchor_offset * (1.0 / old_zoom - 1.0 / new_zoom)`.
- [ ] **Step 4: Run again.** Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game tests && git commit -m "feat: add camera zoom, clamp and edge-pan helpers"`

### Task 5: Piece node

**Files:**
- Create: `src/game/piece_node.gd`, `tests/test_piece_node.gd`

**Interfaces:**
- Consumes: `CutPiece`.
- Produces: `PieceNode extends Node2D` with `piece_id: int`, `setup(piece: CutPiece, texture: Texture2D, outline_color: Color) -> void`, `contains_point(world_point: Vector2) -> bool`, `set_held(held: bool) -> void`. Children: a `Polygon2D` with `polygon` and `uv` both set to the outline and the full image as texture, a closed `Line2D` outline 2.3 world units wide and antialiased, and a hidden shadow `Polygon2D` (black at about 35% opacity, offset a few units down and right) shown only while held.

- [ ] **Step 1: Write the failing test.** Build a `CutPiece` with the square outline (0,0), (10,0), (10,10), (0,10), create a `PieceNode`, call `setup(piece, GradientTexture2D.new(), Color.BLACK)`, add it with `root.add_child` (`to_local` needs the node in the tree), set `position = Vector2(100, 0)`. Assert `contains_point(Vector2(105, 5))` is true and `contains_point(Vector2(5, 5))` is false, and `set_held(true)` then `set_held(false)` runs without error.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_piece_node.gd`.
- [ ] **Step 3: Implement `PieceNode`.** `contains_point` uses `Geometry2D.is_point_in_polygon(to_local(world_point), outline)`.
- [ ] **Step 4: Run again.** Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game tests && git commit -m "feat: add piece node with outline, shadow and hit test"`

### Task 6: Board scene with palette and scattered pieces

**Files:**
- Create: `src/game/palette.gd`, `src/game/board.gd`, `src/game/board.tscn`, `tests/test_palette.gd`

**Interfaces:**
- Consumes: `CutGenerator.generate_cut`, `Scatter.scatter`, `PieceNode`.
- Produces: `Palette` with `static is_dark() -> bool` (false when `DisplayServer.is_dark_mode_supported()` is false), and `static felt(dark := is_dark()) -> Color`, `board(dark := is_dark())`, `accent(dark := is_dark())`, `outline() -> Color` (dark tone at 80% alpha). Values: felt light `#223a63`, dark `#14264a`; board light `#2c4878`, dark `#1c3463`; accent light `#e2a41f`, dark `#ffc857`.
- Produces: `Board extends Node2D` with constants `IMAGE_SIZE := Vector2i(1536, 1024)`, `PIECE_COUNT := 400`, `SEED := 1`, `LOOSE_MARGIN := 768.0`; children `Camera` (`Camera2D`) and `Pieces` (`Node2D` holding one `PieceNode` per piece, in id order). The board rectangle is `Rect2(Vector2.ZERO, IMAGE_SIZE)`.

- [ ] **Step 1: Write the failing test `tests/test_palette.gd`.** Assert the six colour values above with `Color.html` equality for both modes.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_palette.gd`.
- [ ] **Step 3: Implement `Palette`.** Run the test and expect `0 failure(s)`.
- [ ] **Step 4: Implement `Board` and `board.tscn`.** The texture is a `GradientTexture2D` sized `IMAGE_SIZE` with a diagonal rainbow gradient, which needs no image file. The scene sets the clear colour to `Palette.felt()`, draws the board rectangle in `Palette.board()` with a thin outline, calls `generate_cut`, creates one `PieceNode` per piece, applies `Scatter.scatter` displacements as positions, and centres the camera on the board at a zoom that fits the board width with a small border. This is also the board for Task 7.
- [ ] **Step 5: Run the scene on the desktop.** Run: `godot --path . res://src/game/board.tscn` (or F6 in the editor). Expected: navy felt, the board rectangle, 400 pieces scattered around it, no errors in the Output panel.
- [ ] **Step 6: Commit.** `git add src tests && git commit -m "feat: add board scene with palette and scattered pieces"`

### Task 7: Input and camera control

**Files:**
- Modify: `src/game/board.gd`

**Interfaces:**
- Consumes: `CameraRig`, `PieceNode.contains_point`, `PieceNode.set_held`, `Palette`.
- Produces: no new public API. Behaviour is the state machine below. Handle `InputEventScreenTouch` and `InputEventScreenDrag` only, so `emulate_touch_from_mouse` (Task 8) covers the desktop. Also zoom on the mouse wheel as a desktop stand-in for pinch.

State machine, tracked per touch index:

| State | Event | Result |
|---|---|---|
| Idle | first touch down on a piece (topmost hit, iterate `Pieces` children in reverse) | Dragging: move the piece to the last child, `set_held(true)` |
| Idle | first touch down on empty space | Panning |
| Dragging, Panning | second touch down | Pinching: release any held piece in place |
| Dragging | drag | `piece.position += relative / camera.zoom.x` |
| Panning | drag | camera position `-= relative / camera.zoom.x`, clamped |
| Pinching | drag | zoom by the ratio of finger distance to previous distance, about the midpoint, clamped |
| any | touch up for the last finger, or `canceled` | Idle, `set_held(false)` |
| Pinching | one finger up, one left | stay Pinching-ended (no pan, no jump) until every finger is up |

While Dragging, each `_process` frame moves the camera by `CameraRig.edge_pan_velocity(...)` converted to world units (divide by zoom) with margin 48 and max speed 600 screen pixels per second, then clamps it. Camera bounds are the board rectangle grown by `LOOSE_MARGIN`.

- [ ] **Step 1: Implement the state machine in `board.gd`.**
- [ ] **Step 2: Check on the desktop with `godot --path . res://src/game/board.tscn`.** Expected: dragging a piece with the mouse moves it and keeps it on top after release; dragging empty space pans; the wheel zooms about the cursor so the point under it stays fixed; zooming and panning far out stops at the limits and the board stays reachable; dragging a piece close to the window edge pans the camera; no errors in Output.
- [ ] **Step 3: Check the touch cases on the phone in Task 9.** Pin these there: a second finger landing during a drag leaves the piece where it was and does not jump; lifting one finger of a pinch does not pan or jump the camera; a notification pulled down mid-drag does not leave a piece lifted.
- [ ] **Step 4: Commit.** `git add src/game && git commit -m "feat: add piece dragging, pan, pinch zoom and edge pan"`

### Task 8: Frame-rate counter and project settings

**Files:**
- Create: `src/ui/fps_counter.gd`, `src/ui/fps_counter.tscn`
- Modify: `src/game/board.tscn` (add the counter), `project.godot`
- Delete: `test.tscn`

**Interfaces:**
- Consumes: `Palette.accent()`.
- Produces: `FpsCounter extends CanvasLayer` showing `"<fps> fps  <hz> Hz"` from `Engine.get_frames_per_second()` and `DisplayServer.screen_get_refresh_rate()`, in the accent colour at a screen corner clear of the status bar, and calling `queue_free()` in `_ready` unless `OS.is_debug_build()`.

- [ ] **Step 1: Implement the counter and add it to `board.tscn`.**
- [ ] **Step 2: Set the project settings.** Main scene `res://src/game/board.tscn` (replacing the test scene's entry), portrait orientation (`display/window/handheld/orientation`), viewport 540 by 1200 (`display/window/size/viewport_width` and `viewport_height`), and `input_devices/pointing/emulate_touch_from_mouse=true`. Leave the Android pan-and-scale gesture setting off, since touches are handled raw.
- [ ] **Step 3: Delete `test.tscn`** (the throwaway scene from the setup run, never committed, so there is nothing to stage for it).
- [ ] **Step 4: Run `godot --path .`.** Expected: the board opens as the main scene in a portrait window with the counter showing a frame rate, and the Task 7 desktop checks still pass.
- [ ] **Step 5: Commit.** `git add src project.godot && git commit -m "feat: add frame-rate counter and project settings"`

### Task 9: Run on the phone and record results

**Files:**
- Modify: `docs/engine-decision.md`

- [ ] **Step 1: Deploy.** Unlock the Nothing Phone (4a), then click Remote Deploy and Play. Expected: the board opens in portrait with the counter visible.
- [ ] **Step 2: Measure at 400 pieces and write down the numbers.** Drag a piece continuously for 10 seconds, then pinch-zoom and pan continuously for 10 seconds. Note the lowest frame rate and the refresh rate shown for each.
- [ ] **Step 3: Check the edge and touch cases.** Edges look clean (if jagged, try 2D MSAA in Project Settings, Rendering, Anti Aliasing, and note the effect on frame rate); pinch and pan work reliably; the three touch cases from Task 7 Step 3 behave as described.
- [ ] **Step 4: Record the results** in a new "Board and piece movement results" section of `docs/engine-decision.md`: date, device, refresh rate, the lowest fps for each check, and whether the edges and gestures passed.
- [ ] **Step 5: If any frame-rate check is below 60, stop and report to the owner.** Switching to pre-baked sprites or reopening the engine choice changes an architecture rule, so it needs their decision.
- [ ] **Step 6: Commit.** `git add docs && git commit -m "docs: record board and piece movement results on the Nothing Phone (4a)"`
