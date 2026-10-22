# AGENTS.md

Context for AI agents working in this repository. Read `INTENT.md` first. It says what the owner wants and why, and it wins over anything here when they conflict.

## What this project is

An Android jigsaw puzzle game built in Godot 4. Free, no ads, offline-first, distributed as an APK on GitHub. The code is currently at the planning stage. Nothing has been scaffolded yet.

## Stack

- Engine: Godot 4.x.
- Language: GDScript (assumed, not confirmed by the owner yet).
- Target: Android only. Do not add iOS-specific code.
- Image collections are bundled in a few folders and downloaded from Cloudflare R2 for the rest.

## Architecture rules

1. **The cut generator is pure logic.** It lives in its own directory, has no dependency on scenes or nodes, and exposes one function: `generate_cut(width, height, target_count, style, seed)`. It returns pieces, each with a closed outline, a home position in the image and a list of neighbour piece ids.
2. **Generation is deterministic.** The same inputs always give the same output on every device. Use a small seeded random generator written in the project, not the engine's global random. Round generated points to a fixed precision.
3. **Never store piece geometry.** Saves and the daily puzzle store the image id, style, piece count and seed, and regenerate the cut.
4. **Every style produces the same intermediate shape.** A cut is a graph of vertices and shared edges, and the pieces are the faces between them. One common step adds tabs and builds outlines. Regular, Irregular and Wild differ only in how they produce the graph. Do not write a separate pipeline per style.
5. **Shared edges are generated once.** Both neighbouring pieces use the same edge, one reversed, so pieces fit with no gaps. Seed each edge by its id.
6. **Pieces are drawn with `Polygon2D`.** The texture is the full image and the texture coordinates are the outline points, so no bitmap baking is needed. Hit-testing uses `Geometry2D.is_point_in_polygon`.
7. **Pieces never rotate.** Only translation.
8. **Clusters use union-find.** A cluster moves and hit-tests as one body. Joins are permanent. A cluster that reaches its board position locks.
9. **The world camera is a transform.** The board and loose pieces live in world space. The slot tray and other UI live in screen space and do not zoom.
10. **Save on app pause and after each lock, not every frame.**

## Cut styles

- **Regular:** even grid with classic tabs.
- **Irregular:** jittered grid corners, uneven row and column sizes, varied tabs. Still four-sided.
- **Wild:** evenly spread random points with a Voronoi region per point, relaxed once or twice to avoid slivers, with knobbed edges.
- The slider snaps to valid rows-by-columns splits that fit the image aspect ratio for Regular and Irregular. Wild produces exactly the target count.
- A tab-less grid exists as an internal development aid and test fixture. It is not a player-facing style.

## Planned layout

This is the intended structure, not what exists today. Create directories as the work needs them.

- `docs/` for design and version plans.
- `src/cut/` for the generator, with no scene dependencies.
- `src/game/` for the board, camera, input, clusters and slots.
- `src/ui/` for setup, completion and store screens.
- `assets/collections/` for bundled image collections, each with a manifest listing file, title, credit and licence.
- `tests/` for generator and cluster tests.

## Testing

- Generator checks that must always pass: piece areas sum to the image area, every interior edge belongs to exactly two pieces, no piece is below a minimum area, and the same seed gives identical output twice.
- Test cluster joining and save-and-restore with plain logic tests, not through the UI.
- Performance is a feature. Keep an on-screen frame-rate counter available in debug builds and check 600 pieces on a real phone before calling a version done.

## Visual design

Colours, fonts, corner radii and effect defaults are locked in `docs/visual-design.md`. Use those values. Do not substitute other fonts or palettes.

## Conventions

- Match the style of the surrounding code. Keep comments sparse and explain why, not what.
- Prefer the engine's built-in feature over custom code. Do not build subsystems the engine already provides.
- Keep changes small and focused. Do not add abstractions for a single use.
- Do not add dependencies, analytics, ad SDKs or network calls beyond the collection store.
- Images must be public domain, CC0, the owner's own, or AI-generated. Record credit and licence in the collection manifest.

## Workflow

- Version plans live in `docs/`. Work within the current version. Do not pull later-version features forward without asking.
- Ask the owner before changing anything listed under "Decisions already made" in `INTENT.md`.
- Commit messages follow the conventional commit style.
