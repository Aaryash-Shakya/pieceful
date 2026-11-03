# AGENTS.md

Context for AI agents working in this repository. Read `INTENT.md` first. It says what the owner wants and why, and it wins over anything here when they conflict.

## What this project is

An Android jigsaw puzzle game built in Godot 4. Free, no ads, offline-first, distributed as an APK on GitHub. Version 1 is built and waits for testing on a real phone. See `docs/v1-status.md` for what exists, the decisions made while building it, and what is still open.

## Stack

- Engine: Godot 4.x.
- Language: GDScript, confirmed by the owner.
- Target: Android only. Do not add iOS-specific code.
- Android package name: `io.github.aaryash_shakya.pieceful`. Do not change it.
- Image collections are bundled in a few folders and downloaded from Cloudflare R2 for the rest.

## Architecture rules

1. **The cut generator is pure logic.** It lives in its own directory, has no dependency on scenes or nodes, and its entry point is `generate_cut(width, height, target_count, style, seed)`. It returns pieces, each with a closed outline, a home position in the image and a list of neighbour piece ids. It also exposes `valid_counts(width, height, min_count, max_count)` for the setup slider, and `build_graph` for tests and tools. Game code calls `generate_cut`.
2. **Generation is deterministic.** The same inputs always give the same output on every device. Use a small seeded random generator written in the project, not the engine's global random. Round generated points to a fixed precision.
3. **Never store piece geometry.** Saves and the daily puzzle store the image id, style, piece count and seed, and regenerate the cut.
4. **Every style produces the same intermediate shape.** A cut is a graph of vertices and shared edges, and the pieces are the faces between them. One common step adds tabs and builds outlines. Regular, Irregular and Wild differ only in how they produce the graph. Do not write a separate pipeline per style.
5. **Shared edges are generated once.** Both neighbouring pieces use the same edge, one reversed, so pieces fit with no gaps. Seed each edge by its id.
6. **Pieces are drawn with `Polygon2D`.** The texture is the full image and the texture coordinates are the outline points, so no bitmap baking is needed. Hit-testing uses `Geometry2D.is_point_in_polygon`. This rule may change after the version 1 spike, if drawing 400 polygons is too slow or edges need pre-baked sprites. See `docs/engine-decision.md`.
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

## Documents

- `INTENT.md`: what the owner wants and why.
- `docs/version-plan.md`: the three versions and their exit tests.
- `docs/engine-decision.md`: why Godot, the risks, and the spike checks.
- `docs/dev-setup.md`: every install step for the owner's machine, and how to remove them all.
- `docs/technical-notes.md`: toolchain, images, piece counts and behaviour details.
- `docs/visual-design.md`: locked colours, fonts and effects.
- `docs/open-decisions.md`: what is not decided yet. Check it before assuming an answer.
- `docs/prototype/`: a throwaway browser prototype with a working cut generator to port.
- `docs/v1-status.md`: what version 1 contains, the decisions made while building it, and the phone checklist.
- `docs/superpowers/specs/` and `docs/superpowers/plans/`: the design and the implementation plan for each slice that was built.

## Layout

- `docs/` for design, status and version plans.
- `src/cut/` for the generator, with no scene dependencies.
- `src/game/` for the board, camera, input, clusters, saving, sound and tidy.
- `src/ui/` for the setup screen, theme, buttons and the frame-rate counter.
- `assets/collections/` for bundled image collections, each with a manifest listing file, title, credit and licence. `assets/sounds/` and `assets/fonts/` carry their own licence notes.
- `tools/` for scripts that generate the sounds and pictures and build the APK. They are excluded from the exported APK.
- `tests/` for headless tests.

## Testing

- Generator checks that must always pass: piece areas sum to the image area, every interior edge belongs to exactly two pieces, no piece is below a minimum area, and the same seed gives identical output twice.
- Test cluster joining and save-and-restore with plain logic tests, not through the UI.
- Performance is a feature. Keep an on-screen frame-rate counter available in debug builds and check 400 pieces (the maximum) on a real phone before calling a version done.

## Conventions learned while building version 1

- Tests are plain scripts that extend `res://tests/base_test.gd` by path, run with `godot --headless --script tests/<name>.gd`, and print `0 failure(s)` when they pass. Run `godot --headless --import` first after adding a file with a new `class_name`. Test helpers have no `class_name`, so the exported class cache stays clean.
- A script that errors before `finish()` hangs instead of exiting. Wrap RED runs in `timeout 120`.
- Some tests print deliberate `ERROR` or `WARNING` lines for invalid input. They are captured and checked. Any other `ERROR` or `WARNING` line is a failure.
- Tests use their own save path under `user://test_*` and never touch the real save.
- Generated assets (sounds in `assets/sounds/`, pictures in `assets/collections/`) come from scripts in `tools/` that use only the project's `SeededRng`. Regenerate them with `godot --headless --script tools/<name>.gd`.
- A deliberate change to a cut, which means to a golden checksum in `tests/test_cut_generator.gd`, changes every saved puzzle. Bump `SaveGame.VERSION` in the same commit.
- Cuts must be identical on every device. Cut maths uses 64-bit GDScript floats and the project's own functions, never engine random or the system `log`.
- Never delete a save the game cannot use. Move it aside to `current.bad.json` and log one warning.
- Prefer a fix that removes the cause over one that scatters guard calls through every entry point. The code reviews in version 1 found this more than anything else.

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
