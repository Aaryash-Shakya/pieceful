# Cut styles: second slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes only the cut-styles slice of version 1 in `docs/version-plan.md`. The previous slice is `docs/superpowers/specs/2026-10-22-board-and-piece-movement-design.md`.

## Intent

The board slice cut the picture into plain rectangles. A jigsaw needs real pieces: classic knobs that interlock, and a harder style where the grid itself is uneven. This slice turns the generator into the one pipeline that `AGENTS.md` rules 1 to 5 describe. Every style builds a graph of vertices and shared edges, and one common step adds tabs and walks each piece's outline. Wild (version 3) must later fit into the same pipeline by building a different graph, with no new outline code.

The cut is never stored. Saves and the daily puzzle will hold only the image, style, count and seed, so the same inputs must give the same pieces on every phone, and a change to one edge must never ripple into another.

## What the slice delivers

1. **Explicit edges in the cut graph.** `CutGraph` holds vertices, a list of edges with stable ids, and faces. Each edge has its two end vertices, the face on each side (or -1 on the image border) and its point list. Faces list their edges with a direction, so a shared edge exists once and the neighbouring piece walks it reversed.
2. **One common step from graph to pieces.** Adding tabs to interior edges and building each piece's closed outline by walking its edges. Styles differ only in how they place the vertices and which tab parameters they pass.
3. **Three styles.** `grid` (tab-less, the internal development aid and test fixture, unchanged output), `regular` (even grid, classic tabs, each tab pointing a random way) and `irregular` (uneven row and column sizes, jittered interior corners, varied tab size and position, every piece still four-sided).
4. **Per-edge seeding.** Each edge's random choices come from the project's `SeededRng`, seeded by a hash of the cut seed and the edge id. The irregular corner jitter has its own stream from the same hash.
5. **Valid piece counts.** `CutGenerator.valid_counts(width, height, min_count, max_count)` lists the counts the slider may offer for Regular and Irregular. `grid_split` returns an exact split for every listed count.
6. **Regular on the board.** The board uses `regular` by default, still 400 pieces. Drawing and hit-testing already handle concave polygons.
7. **Generator tests** for every style over a range of counts and aspect ratios.

## Goals

- The `AGENTS.md` generator checks pass for every style: piece areas sum to the image area, every interior edge belongs to exactly two pieces and is walked in opposite directions, no piece is below a minimum area, and the same seed gives identical output twice.
- Also: no outline crosses itself, every outline triangulates (so `Polygon2D` draws it), tabs stay inside the image, neighbour lists are symmetric, Irregular faces have four corners forming a convex quad, and a different seed gives a different cut.
- A piece outline has at most 104 points, so 400 Regular pieces still hold 60 frames per second on the Nothing Phone (4a).
- Each listed count maps back through `grid_split` to a split with exactly that many pieces.

## Non-goals for this slice

- Wild, and any Voronoi code.
- The setup screen, the slider and the live preview. `valid_counts` is ready for them, nothing draws it yet.
- Snapping, locking, clusters, sound, vibration and saving.
- Any change to input handling, the camera or the piece node.

## Anti-goals

- A separate outline pipeline per style.
- A tab computed twice, once for each neighbour. A shared edge is generated once.
- Randomness that flows from edge to edge, so that changing one edge's shape shifts every later edge.
- Clamping tab points to the image border to hide a shape that pokes out. Tabs are sized so they stay inside by construction.
- Use of the engine's global random or any other per-device source of numbers.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- The generator lives in `src/cut/`, has no dependency on scenes or nodes, and keeps `generate_cut(width, height, target_count, style, seed)` as its entry point.
- Every generated point is rounded to 3 decimals (`CutGenerator.PRECISION`, 0.001). `Vector2` is single precision, so rounding happens on the final points.
- Pieces never rotate. Pieces are drawn with `Polygon2D` and hit-tested with `Geometry2D.is_point_in_polygon`.
- Tests are plain headless scripts extending `BaseTest`, run with `godot --headless --script tests/<name>.gd`.
- Match the style of the surrounding code. Keep comments sparse and explain why.

## Decisions the owner made

- The cut generator and its tests are built in the order grid, Regular, Irregular (`docs/version-plan.md`).
- Regular has classic tabs on an even grid. Irregular has uneven sizes and wobbly cuts and stays four-sided (`INTENT.md`).
- The slider offers only valid rows-by-columns splits that fit the image's aspect ratio, from about 12 to 400 (`INTENT.md`).
- The tab-less grid stays as an internal development aid and test fixture (`AGENTS.md`).

## Calls made by Claude, which the owner has not confirmed

The orchestrator was delegated these decisions by the owner. Each one is Claude's.

- **Edge directions.** A face lists its edges as directed references: `2 * id` walks the edge from its first vertex to its second, `2 * id + 1` walks it backwards. The first face to use an edge owns its forward direction. A border edge has only that one face, so its second face is -1.
- **Winding.** Every face's corners go round with positive signed area in image coordinates (clockwise on screen, since y points down), as the grid already does.
- **Edge seeding.** An edge's generator is `SeededRng.new(SeededRng.hash2(seed, edge_id))`, a small integer hash written in the project. Seeds are taken modulo 2^32. The style is not part of the edge seed, so Regular and Irregular cuts with the same seed and split have the same tab directions. The Irregular corner jitter uses `hash2(seed, -1)`, which no edge id can reach.
- **Tab shape.** Ported from the prototype: three cubic curves (shoulder, knob, shoulder) sampled with 8, 10 and 8 segments, so a tabbed edge has 27 points and a four-sided piece at most 104.
- **Tab size from room, not edge length.** The prototype sizes a tab by its edge length and clamps points to the image. Here a tab is sized by the edge's room: the smaller of its length and each neighbouring face's area divided by its length. A long edge on a short cell then gets a tab that fits the cell, so tabs from opposite sides never collide and nothing needs clamping.
- **No tab on a cramped edge.** An edge whose room is below 8 image pixels stays straight. This keeps tiny cells (very small images or huge counts) valid.
- **Tab parameters**, as fractions of the room (size and wobble) or of the edge length (shift):

  | Parameter | Regular | Irregular | Prototype |
  |---|---|---|---|
  | Neck half-width `size` | 0.10 | 0.10 | 0.10 |
  | Size varies by | ±5% | ±10% | ±8% |
  | Knob centre shift along the edge | ±3% | ±4% | ±3% or ±7% |
  | Shoulder and knob wobble | ±2% | ±2% | ±3% or ±7% |

  Irregular was first ±15%, ±8% and ±6% on a ±15% corner jitter. With every draw forced to an extreme, those values made outlines cross themselves even in square cells, and the lattice's sharpest corners (down to about 48 degrees) let two inward knobs shifted toward the same corner touch. With the corner jitter at ±8% (sharpest corner about 68 degrees), the values above pass the forced-extreme check (`tests/test_tab_extremes.gd`), and in tuning a quarter more of each also passed.

- **Irregular lattice.** Column widths and row heights each vary by ±25% before being scaled to fill the image (the prototype used ±35%). Interior corners move by up to ±8% of the smaller neighbouring column width and row height (the prototype used ±20%). Border corners stay on the border. These are tighter than the prototype so pieces stay convex quads and tabs never collide. The forced-extreme test (`tests/test_tab_extremes.gd`) pins this: with every tab draw combination at its extremes, no outline crosses itself on real seeded cuts or on 8 sampled extreme lattices, whose sharpest corner is below 72 degrees.
- **Regular keeps the grid's whole-pixel cell boundaries**, so Grid and Regular share vertices and differ only by tabs.
- **Valid counts.** A count is valid when some exact rows-by-columns split has cells whose aspect ratio is within `exp(±0.18)` of square (about 0.84 to 1.20, the prototype's limit). `grid_split` now prefers the squarest exact split when one is that close, and otherwise falls back to its current scoring, so it keeps working for counts that are not listed (a stale save, or a test). On a 3:2 picture this gives 67 counts between 12 and 400. On a square picture the smallest is 16, since 12 would need cells 4 by 3.
- **Minimum area in tests:** half the mean piece area for Grid and Regular, a quarter for Irregular.
- `CutPiece.home` stays the centre of the outline's bounding rectangle. Nothing reads it yet.

## Left to the builder

- Private helper names and how the tests are split across files, inside the interfaces the plan fixes.
- How the segment-crossing check in the tests is written, as long as the generator test file finishes in under 30 seconds on the desktop.

## What happens if it is too slow

If 400 Regular pieces drop below 60 frames per second on the phone where the grid held, first lower the segment counts (6, 8 and 6 gives 80 points per piece), then look at the `Line2D` outline cost. Record the result in `docs/engine-decision.md`. Pre-baked sprites change an architecture rule and need the owner's decision.
