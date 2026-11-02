# Cut Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One deterministic cut pipeline with explicit shared edges that produces the Grid, Regular and Irregular styles, a list of valid piece counts for the slider, and Regular pieces on the 400-piece board.

**Architecture:** `CutGraph` gains `CutEdge` objects with stable ids, and faces list directed edge references. A style only places vertices (`build_grid_graph`, `build_irregular_graph`). One common step, `CutGenerator.shape_edges`, gives each interior edge its tab from a `TabShape` and a generator seeded by `hash2(seed, edge_id)`, and `CutGraph.to_pieces` walks each face's edges into a closed outline. The board and piece node are unchanged apart from the style constant.

**Tech Stack:** Godot 4.7.2, GDScript, Mobile renderer. Tests are plain headless scripts extending `BaseTest`.

**Spec:** `docs/superpowers/specs/2026-11-02-cut-styles-design.md`. Also read `INTENT.md` and `AGENTS.md`.

## Global Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- `src/cut/` has no dependency on scenes or nodes. The entry point stays `CutGenerator.generate_cut(width: int, height: int, target_count: int, style: String, seed: int) -> Array[CutPiece]`.
- Deterministic: only the project's `SeededRng`, never `randf`, `randi` or `RandomNumberGenerator`. Every generated point is snapped to `CutGenerator.PRECISION` (0.001).
- Shared edges are generated once. The neighbouring face walks the same points reversed.
- Each edge's random choices come only from `SeededRng.new(SeededRng.hash2(seed, edge_id))`.
- Face winding: positive signed area in image coordinates (clockwise on screen).
- Regular and Irregular outlines have at most `CutGenerator.MAX_OUTLINE_POINTS` (104) points.
- Out of scope: Wild, the setup screen, clusters, snapping, locking, sound, save. Do not change input handling in `board.gd`.
- Run `godot --headless --import` after adding any file with a new `class_name`, then `godot --headless --script tests/<name>.gd`. A passing run prints `0 failure(s)` and exits 0.
- Match the surrounding code style, sparse comments that explain why. Conventional commits, one per task.

## Review Focus

- A count that is not in `valid_counts`, such as 54 on a square image or a stale save: `generate_cut` still returns a valid cut using `grid_split`'s fallback (Tasks 3 and 4, the 1000 by 1000 shape in `SHAPES` with count 54).
- Cells too small for a tab (160 by 120 at 400 pieces, 10 by 10 at 100000): edges stay straight and every check still passes (Tasks 3 and 4).
- Extreme image shapes (10000 by 100 at 50, 1000 by 3000 at 400): the fallback split gives non-square cells, and tabs still fit their room (Tasks 3 and 4).
- A finger landing on a knob or inside a notch: the hit goes to the piece that owns that area, not to the cell's rectangle (Task 5, concave hit test).
- `valid_counts` with `min_count > max_count` or an image too small for any listed split: an empty array, no error (Task 2).

---

### Task 1: Explicit edges in the cut graph and the shared pieces step

**Files:**
- Create: `src/cut/cut_edge.gd`, `tests/test_cut_graph.gd`
- Modify: `src/cut/cut_graph.gd` (replace `faces` contents and `edge_use_counts`), `src/cut/cut_generator.gd` (`build_grid_graph`, `generate_cut`, new `build_graph`), `tests/test_cut_generator.gd` (rewrite the helper)

**Interfaces:**
- Produces: `CutEdge extends RefCounted` with `id: int`, `from_vertex: int`, `to_vertex: int`, `face_a: int` (the face that walks `from_vertex` to `to_vertex`), `face_b: int = -1` (the face that walks it backwards, -1 on the border), `points: PackedVector2Array` (starts at `from_vertex`'s position, ends at `to_vertex`'s; a straight edge holds just those two), `is_border() -> bool`.
- Produces: `CutGraph` with `vertices: PackedVector2Array`, `edges: Array[CutEdge]`, `faces: Array[PackedInt32Array]` (directed edge refs: `2 * id` forward, `2 * id + 1` backward), `static edge_key(a: int, b: int) -> Vector2i` (kept), `static ref_edge(ref: int) -> int`, `static ref_reversed(ref: int) -> bool`, `add_face(corners: PackedInt32Array) -> int`, `corner_area(face: int) -> float` (signed shoelace of the face's corner vertices), `edge_room(edge_id: int) -> float`, `to_pieces() -> Array[CutPiece]`. `edge_use_counts` is removed.
- Produces: `CutGenerator.MAX_OUTLINE_POINTS := 104` (four tabbed edges of `TabShape.POINTS_PER_EDGE - 1` points, written as a literal until Task 3 adds `TabShape`).
- Produces: `CutGenerator.build_graph(width: int, height: int, target_count: int, style: String, seed: int) -> CutGraph` (null after `push_error` on invalid input or unknown style). `generate_cut` becomes `build_graph(...).to_pieces()`, or an empty array when that is null. `build_grid_graph(width, height, columns, rows) -> CutGraph` keeps its signature and builds faces with `add_face`, row by row, corners `[top_left, top_left + 1, top_left + stride + 1, top_left + stride]`.

- [ ] **Step 1: Write the failing test `tests/test_cut_graph.gd`.** Fixture: two unit squares, `vertices = [(0,0), (1,0), (2,0), (0,1), (1,1), (2,1)]`, `add_face([0, 1, 4, 3])` then `add_face([1, 2, 5, 4])`. Assert:
  - the two calls return 0 and 1; `edges.size() == 7`; six edges have `is_border()`.
  - `faces[0] == PackedInt32Array([0, 2, 4, 6])` and `faces[1] == PackedInt32Array([8, 10, 12, 3])`.
  - `edges[1]`: `from_vertex == 1`, `to_vertex == 4`, `face_a == 0`, `face_b == 1`, `points == PackedVector2Array([Vector2(1, 0), Vector2(1, 1)])`.
  - `ref_edge(3) == 1`, `ref_reversed(3)`, `not ref_reversed(2)`; `corner_area(0) == 1.0`; `edge_room(1) == 1.0`.
  - `to_pieces()`: piece 0 outline `[(0,0), (1,0), (1,1), (0,1)]`, piece 1 outline `[(1,0), (2,0), (2,1), (1,1)]`, neighbours `[1]` and `[0]`, ids 0 and 1.
  - After `edges[1].points = PackedVector2Array([Vector2(1, 0), Vector2(1.2, 0.5), Vector2(1, 1)])`, `to_pieces()` gives piece 0 outline `[(0,0), (1,0), (1.2,0.5), (1,1), (0,1)]` and piece 1 outline `[(1,0), (2,0), (2,1), (1,1), (1.2,0.5)]`, and the two areas sum to 2.0.
- [ ] **Step 2: Rewrite `tests/test_cut_generator.gd` around a shared helper.** It replaces the old `check_cut` and is extended by Tasks 3 and 4:

```gdscript
const SHAPES: Array[Vector2i] = [Vector2i(1536, 1024), Vector2i(1024, 1536), Vector2i(1000, 1000), Vector2i(2048, 900)]
const COUNTS: Array[int] = [12, 54, 150]
const MIN_AREA_FRACTION := {"grid": 0.5, "regular": 0.5, "irregular": 0.25}

# Asserts, each labelled "<style> <w>x<h> count <n> seed <s>: ...":
# graph: build_graph is not null and pieces.size() == graph.faces.size() > 0; piece.id == index
# graph: every edge's 2*id ref appears exactly once across all faces, in faces[face_a]
# graph: an interior edge's 2*id+1 ref appears exactly once, in faces[face_b]; a border edge's never
# graph: border edge count == 2 * (split.x + split.y) with split = grid_split(w, h, n)
# graph: edge.points[0] == vertices[from_vertex] and edge.points[-1] == vertices[to_vertex]
# pieces: absf(sum of area() - w * h) <= 1e-6 * w * h
# pieces: min area() >= MIN_AREA_FRACTION[style] * w * h / pieces.size()
# pieces: signed_area(outline) > 0, outline_is_simple(outline),
#         Geometry2D.triangulate_polygon(outline).size() == (outline.size() - 2) * 3
# pieces: every point has 0 <= x <= w and 0 <= y <= h; outline.size() <= CutGenerator.MAX_OUTLINE_POINTS
# pieces: outline.size() == sum over the face's refs of (edge.points.size() - 1)
# pieces: neighbours symmetric, never self, no duplicates
func check_cut(w: int, h: int, count: int, style: String, seed_value: int) -> void
func same_cut(a: Array[CutPiece], b: Array[CutPiece]) -> bool   # equal sizes, outlines and neighbours
func signed_area(outline: PackedVector2Array) -> float
# False if two non-adjacent segments meet (Geometry2D.segment_intersects_segment != null, after a
# bounding-box reject) or two consecutive points are equal.
func outline_is_simple(outline: PackedVector2Array) -> bool
```

  Keep every existing assertion, now through `check_cut(..., "grid", 1)`: counts 1, 12, 54, 150 and 400 at 1536 by 1024; every shape in `SHAPES` with every count in `COUNTS`; 10000 by 100 at 50; 10 by 10 at 100000 (plus `size() <= 100`); all `grid_split` pins; same inputs twice give `same_cut`; unknown style, width 0 and target 0 give an empty array. Add: `generate_cut(1500, 1000, 54, "grid", 1)[0].outline == PackedVector2Array([Vector2(0, 0), Vector2(167, 0), Vector2(167, 167), Vector2(0, 167)])` (grid output unchanged) and `CutGenerator.build_graph(1536, 1024, 54, "bogus", 1) == null`.
- [ ] **Step 3: Run both tests, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_cut_graph.gd` and `godot --headless --script tests/test_cut_generator.gd`. Expected: errors about `CutEdge`, `add_face` or `build_graph` not found.
- [ ] **Step 4: Implement `CutEdge`, the new `CutGraph` and the grid path.** `add_face` looks each corner pair up by `edge_key` in a private dictionary: a new pair creates an edge with the next id, `face_a` set and straight `points`, and appends `2 * id`; a pair that exists, was walked the other way and has `face_b == -1` sets `face_b` and appends `2 * id + 1`. Any other case is a builder bug: `push_error` and return -1. `edge_room(id)` is `minf(L, minf(corner_area(face_a), corner_area(face_b)) / L)` with `L` the distance between the end vertices, for interior edges only. `to_pieces` appends each referenced edge's points (reversed for a backward ref) without its last point, sets `home` to `bounds().get_center()`, and fills neighbours from the face's interior edges in ref order.
- [ ] **Step 5: Run both tests again.** Expected: `0 failure(s)` each. Also run `godot --headless --script tests/test_scatter.gd` and `tests/test_board_input.gd`: `0 failure(s)`.
- [ ] **Step 6: Commit.** `git add src/cut tests && git commit -m "refactor: give the cut graph explicit shared edges"`

### Task 2: Valid piece counts that agree with the grid split

**Files:**
- Create: `tests/test_cut_counts.gd`
- Modify: `src/cut/cut_generator.gd` (`grid_split`, new `valid_counts` and `_exact_split`)

**Interfaces:**
- Produces: `CutGenerator.MAX_ASPECT_ERROR := 0.18`; `static valid_counts(width: int, height: int, min_count: int, max_count: int) -> PackedInt32Array` (ascending, no duplicates, may be empty); private `static _exact_split(width: int, height: int, count: int) -> Vector2i` (`Vector2i.ZERO` when none).
- Changes: `grid_split` returns `_exact_split(...)` when it is not zero, else its current scoring unchanged.

- [ ] **Step 1: Write the failing test `tests/test_cut_counts.gd`.** Assert:
  - `valid_counts(1536, 1024, 12, 400)`: size 67, first five `[12, 15, 24, 28, 35]`, last `400`; contains 54, 96, 150, 300 and 400; does not contain 200 or 250.
  - `valid_counts(1024, 1536, 12, 400).size() == 67`; `valid_counts(1000, 1000, 12, 400)`: size 43, first 16, last 400; `valid_counts(10000, 100, 12, 400)[0] == 84`.
  - Each list is strictly ascending.
  - Agreement, for each of 1536 by 1024, 1024 by 1536, 1000 by 1000, 2048 by 900 and 10000 by 100: every `n` in `valid_counts(w, h, 12, 400)` has `grid_split(w, h, n).x * grid_split(w, h, n).y == n` and that split's cell aspect `(w / x) / (h / y)` within `[exp(-0.18), exp(0.18)]`.
  - `valid_counts(1536, 1024, 400, 12).is_empty()` and `valid_counts(3, 2, 12, 400).is_empty()`.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --script tests/test_cut_counts.gd`. Expected: error, `valid_counts` not found.
- [ ] **Step 3: Implement.** `_exact_split` tries rows from 1 to `mini(height, count)` that divide `count` with `columns = count / rows <= width`, keeps the smallest `roundi(absf(log(cell_aspect)) * SCORE_SCALE)` (rows ascend, so a tie goes to fewer rows), and returns it only if that score is `<= roundi(MAX_ASPECT_ERROR * SCORE_SCALE)`. `valid_counts` is every `n` in `maxi(1, min_count)..max_count` with a non-zero `_exact_split`, which makes the agreement hold by construction.
- [ ] **Step 4: Run `tests/test_cut_counts.gd` and `tests/test_cut_generator.gd`.** Expected: `0 failure(s)` each. The existing `grid_split` pins (9x6, 15x10, square 7x7, 5x4, 6x5, 4x3, 3x2) must still pass unchanged.
- [ ] **Step 5: Commit.** `git add src/cut tests && git commit -m "feat: list valid piece counts and prefer exact grid splits"`

### Task 3: Classic tabs and the Regular style

**Files:**
- Create: `src/cut/tab_shape.gd`, `tests/test_tab_shape.gd`
- Modify: `src/cut/seeded_rng.gd` (add `hash2`), `src/cut/cut_generator.gd` (`STYLE_REGULAR`, `shape_edges`, `build_graph` branch), `tests/test_seeded_rng.gd`, `tests/test_cut_generator.gd`

**Interfaces:**
- Consumes: `CutGraph.edges`, `CutGraph.edge_room`, `CutEdge`, `CutGenerator.build_grid_graph`, `check_cut`, `same_cut` from Task 1.
- Produces: `static SeededRng.hash2(a: int, b: int) -> int` (in `0..MASK`).
- Produces: `TabShape extends RefCounted` with `const SEGMENTS: Array[int] = [8, 10, 8]`, `const POINTS_PER_EDGE := 27`, `const MIN_ROOM := 8.0`, `var size: float`, `var size_jitter: float`, `var shift: float`, `var wobble: float`, `_init(size_value: float, size_jitter_value: float, shift_value: float, wobble_value: float)`, `static for_style(style: String) -> TabShape` (null for `grid` and unknown styles), `edge_points(from: Vector2, to: Vector2, room: float, rng: SeededRng) -> PackedVector2Array`.
- Produces: `CutGenerator.STYLE_REGULAR := "regular"`, `static shape_edges(graph: CutGraph, tabs: TabShape, seed_value: int) -> void` (sets `points` of every interior edge to `tabs.edge_points(from, to, graph.edge_room(id), SeededRng.new(SeededRng.hash2(seed_value, id)))`; border edges stay straight).

Values for `for_style`: Regular `TabShape.new(0.10, 0.05, 0.03, 0.02)`, Irregular `TabShape.new(0.10, 0.10, 0.04, 0.02)`.

The tab, in this order of random draws (this order is the contract; do not reorder):

```text
L = from.distance_to(to); u = (to - from) / L
flip = 1 if rng.next_float() < 0.5 else -1;  n = u.orthogonal() * flip
t = size * room * (1 + rng.range_float(-size_jitter, size_jitter))
m = L * (0.5 + rng.range_float(-shift, shift))
w = wobble * room;  a, c, d, e = four draws of rng.range_float(-w, w), in that order
P(x, y) = from + u * x + n * y
q0 P(0, 0)        q1 P(0.2 L, a)      q2 P(m + d, -t + c)       q3 P(m - t, t + c)
q4 P(m - 2t - d, 3t + c)              q5 P(m + 2t - d, 3t + c)  q6 P(m + t, t + c)
q7 P(m + d, -t + c)                   q8 P(0.8 L, e)            q9 P(L, 0)
cubics (q0 q1 q2 q3), (q3 q4 q5 q6), (q6 q7 q8 q9), sampled at i / segments for i = 1..segments
points = [from] + samples, each snapped to PRECISION; then points[0] = from and points[-1] = to exactly
```

When `room < MIN_ROOM`, `edge_points` returns `PackedVector2Array([from, to])` with no draws.

- [ ] **Step 1: Add the failing `hash2` assertions to `tests/test_seeded_rng.gd`.** `SeededRng.hash2(1, 2) == 3749358279`, `SeededRng.hash2(7, 0) == 3190417882`, `SeededRng.hash2(-5, 3) == 3280828902`, `SeededRng.hash2(1, -1) == 3238652418`; for `a` in 0..99 and `b` in 0..9, every result is in `0..SeededRng.MASK`.
- [ ] **Step 2: Write the failing test `tests/test_tab_shape.gd`.** With `shape := TabShape.for_style("regular")`, `pts := shape.edge_points(Vector2(0, 0), Vector2(100, 0), 100.0, SeededRng.new(3))`:
  - `pts.size() == TabShape.POINTS_PER_EDGE`, `pts[0] == Vector2(0, 0)`, `pts[-1] == Vector2(100, 0)`.
  - every point has `0.0 <= x <= 100.0` and `absf(y) <= 40.0`; `absf(pts[13].y) >= 12.0` (the knob apex is real).
  - every coordinate is within `1e-4` of `snappedf(value, 0.001)`.
  - a second call with `SeededRng.new(3)` returns an equal array.
  - over seeds 1..200, `pts[13].y > 0` and `pts[13].y < 0` each happen at least 50 times.
  - the same bounds hold for `TabShape.for_style("irregular")` with seed 3.
  - `shape.edge_points(Vector2(0, 0), Vector2(100, 0), 7.9, SeededRng.new(3)).size() == 2`.
  - `TabShape.for_style("grid") == null` and `TabShape.for_style("bogus") == null`.
- [ ] **Step 3: Add the Regular cases to `tests/test_cut_generator.gd`.** `check_cut(w, h, n, "regular", 1)` for every shape in `SHAPES` and count in `COUNTS`; `check_cut(1536, 1024, 400, "regular", 1)`; `check_cut` at 160 by 120 with 400, 10 by 10 with 100000, 10000 by 100 with 50 and 1000 by 3000 with 400; `check_cut(1536, 1024, 54, "regular", s)` for `s` in 0, -5 and 7. Also assert: two `generate_cut(1536, 1024, 54, "regular", 7)` calls give `same_cut`; seeds 7 and 8 do not; `generate_cut(1536, 1024, 400, "regular", 1)` has some outline with more than 4 points; and for every interior edge `k` of `build_graph(1536, 1024, 54, "regular", 7)`, `edges[k].points == TabShape.for_style("regular").edge_points(vertices[from_vertex], vertices[to_vertex], graph.edge_room(k), SeededRng.new(SeededRng.hash2(7, k)))` (each edge depends only on its own id).
- [ ] **Step 4: Run the three tests, expecting failure.** `godot --headless --import`, then `godot --headless --script tests/test_seeded_rng.gd`, `tests/test_tab_shape.gd` and `tests/test_cut_generator.gd`. Expected: `hash2`, `TabShape` or the regular style not found.
- [ ] **Step 5: Implement `hash2`.** GDScript ints are signed 64-bit, so every multiply keeps one side below 2^31 and the other masked to 32 bits:

```gdscript
var h := ((a & MASK) * 0x27d4eb2d + (b & MASK)) & MASK
h ^= h >> 15
h = (h * 0x2c1b3c6d) & MASK
h ^= h >> 12
h = (h * 0x297a2d39) & MASK
h ^= h >> 15
```

- [ ] **Step 6: Implement `TabShape` and the Regular branch.** `build_graph` for `regular` is `build_grid_graph` then `shape_edges(graph, TabShape.for_style(style), seed)`.
- [ ] **Step 7: Run the three tests again.** Expected: `0 failure(s)` each, and `tests/test_cut_generator.gd` finishes in under 30 seconds. If it does not, run `outline_is_simple` only for counts up to 150 and for the single 1536 by 1024 run at 400; keep every other assertion everywhere.
- [ ] **Step 8: Commit.** `git add src/cut tests && git commit -m "feat: add classic tabs and the regular cut style"`

### Task 4: The Irregular style

**Files:**
- Modify: `src/cut/cut_generator.gd` (`STYLE_IRREGULAR`, lattice constants, `build_irregular_graph`, `build_graph` branch), `tests/test_cut_generator.gd`

**Interfaces:**
- Consumes: `TabShape.for_style("irregular")`, `shape_edges`, `SeededRng.hash2`, `CutGraph.add_face`, `check_cut`, `same_cut`.
- Produces: `CutGenerator.STYLE_IRREGULAR := "irregular"`, `const IRREGULAR_UNEVEN := 0.25`, `const IRREGULAR_CORNER_JITTER := 0.08`, `const LATTICE_STREAM := -1`, `static build_irregular_graph(width: int, height: int, columns: int, rows: int, rng: SeededRng) -> CutGraph`. `build_graph` for `irregular` passes `SeededRng.new(SeededRng.hash2(seed, LATTICE_STREAM))`, then calls `shape_edges` like Regular. Same vertex order and faces as `build_grid_graph`, so edge ids match for the same split.

The lattice, in this order of draws:

```text
cw[c] = 1 + rng.range_float(-IRREGULAR_UNEVEN, IRREGULAR_UNEVEN) for c in columns, then rh[r] the same for r in rows
xs[c] = width * (cw[0] + ... + cw[c-1]) / sum(cw), with xs[0] = 0 and xs[columns] = width exactly; ys the same with height
for r in 0..rows, for c in 0..columns (row-major):
    x = xs[c], y = ys[r]
    if 0 < r < rows and 0 < c < columns:
        x += rng.range_float(-j, j) with j = IRREGULAR_CORNER_JITTER * minf(cw[c-1], cw[c]) / sum(cw) * width
        y += rng.range_float(-j, j) with j = IRREGULAR_CORNER_JITTER * minf(rh[r-1], rh[r]) / sum(rh) * height
    vertex = (x, y) snapped to PRECISION
```

- [ ] **Step 1: Add the failing Irregular cases to `tests/test_cut_generator.gd`.** The same `check_cut` calls as Regular in Task 3 Step 3 with `"irregular"`, the same determinism and seed-change assertions, plus a helper `check_four_sided(graph, w, h, label)` asserting for `build_graph(w, h, n, "irregular", s)` over every shape in `SHAPES`, count in `COUNTS` and `s` in 1 and 2:
  - every face has exactly 4 refs, and its 4 corners form a strictly convex quad (all 4 consecutive cross products `> 0`).
  - every vertex in row 0 has `y == 0`, in the last row `y == h`, in column 0 `x == 0`, in the last column `x == w`.
  - top-row column widths are not all equal, and at least one interior vertex has an `x` different from the top-border vertex in its column.
- [ ] **Step 2: Run it, expecting failure.** `godot --headless --script tests/test_cut_generator.gd`. Expected: FAIL, unknown style `irregular`.
- [ ] **Step 3: Implement `build_irregular_graph` and the Irregular branch.**
- [ ] **Step 4: Run it again.** Expected: `0 failure(s)`, under 30 seconds.
- [ ] **Step 5: Commit.** `git add src/cut tests && git commit -m "feat: add the irregular cut style"`

### Task 5: Regular pieces on the board, and the phone check

**Files:**
- Modify: `src/game/board.gd` (style constant only), `tests/test_piece_node.gd`, `docs/technical-notes.md` (piece counts section), `docs/engine-decision.md`

**Interfaces:**
- Consumes: `CutGenerator.STYLE_REGULAR`, `PieceNode.contains_point`.
- Produces: `Board.STYLE := CutGenerator.STYLE_REGULAR`, passed to `generate_cut` in `_ready`. No other change to `board.gd`.

- [ ] **Step 1: Add the concave hit test to `tests/test_piece_node.gd`.** A second piece with the notched outline `(0,0), (10,0), (10,10), (6,10), (6,4), (4,4), (4,10), (0,10)` set up like the first and added with `root.add_child`, at `position = Vector2.ZERO`: `contains_point(Vector2(5, 8))` (inside the notch) is false, `contains_point(Vector2(2, 8))` and `contains_point(Vector2(5, 2))` are true.
- [ ] **Step 2: Run it.** `godot --headless --script tests/test_piece_node.gd`. Expected: `0 failure(s)` (this pins behaviour that already works).
- [ ] **Step 3: Switch the board to Regular.** Add `STYLE` and use it in the `generate_cut` call.
- [ ] **Step 4: Run every test.** `godot --headless --import`, then `for t in tests/test_*.gd; do godot --headless --script "$t" || echo "FAILED $t"; done`. Expected: `0 failure(s)` for each file and no `FAILED` line.
- [ ] **Step 5: Check on the desktop.** `godot --path . res://src/game/board.tscn`. Expected: 400 pieces with knobs, clean outlines round the knobs, a tap on a knob picks up the piece the knob belongs to, dragging, panning and zooming behave as before, no errors in the output.
- [ ] **Step 6: Correct the piece-count note in `docs/technical-notes.md`.** Replace the sentence about the daily ramp with: on a 3:2 picture, 54, 96, 150, 300 and 400 are valid grid splits; 200 and 250 are not, which only works because those are Wild days; on a square picture none of 54, 96, 150 and 300 is valid and the smallest valid count is 16.
- [ ] **Step 7: Run on the phone (the owner or the session with the phone connected).** Remote Deploy to the Nothing Phone (4a). At `MIN_ZOOM` with all 400 pieces visible, drag a piece for 10 seconds, then pinch-zoom and pan for 10 seconds. Note the lowest frame rate, the worst frame time and the refresh rate for each.
- [ ] **Step 8: Record the results** in a new "Cut styles results" section of `docs/engine-decision.md`: date, device, style Regular, 400 pieces, up to 104 points per outline, refresh rate and lowest fps per check. If either check is below 60, stop and report to the owner with the fallback in the spec ("What happens if it is too slow").
- [ ] **Step 9: Commit.** `git add src/game tests docs && git commit -m "feat: cut the board with regular tabs"`
