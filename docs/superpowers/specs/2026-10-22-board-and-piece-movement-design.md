# Board and piece movement: first slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes only the first slice of version 1 in `docs/version-plan.md`.

## Intent

Pieceful is a free, ad-free, smooth jigsaw game for Android. The first thing to build is the part the whole game rests on: a puzzle image cut into pieces, a board, loose pieces scattered around it, and moving them with one finger on a phone while the camera pinch-zooms and pans.

This slice is written as real code, not a throwaway. It is also the performance test for Godot that version 1 calls for, so it must run with 400 pieces from the start. Smoothness matters more than anything else here. If it stutters, the engine choice is reopened (see "Fallback").

## What the slice delivers

1. **Cut generator, grid only.** A pure-logic function `generate_cut(width, height, target_count, style, seed)`. For this slice the only style is the tab-less grid, the internal development aid. It returns pieces. Each piece has a closed outline, a home position in the image and a list of neighbour piece ids. It does not depend on scenes or nodes.
2. **Board scene.** A felt table, a board rectangle in the middle, and the pieces drawn as `Polygon2D` nodes showing the full image through texture coordinates. The pieces start scattered around the board in random loose positions.
3. **Piece movement.** One finger or the mouse drags a piece. The piece being dragged is drawn on top of the others and stays on top after the drop. A light shadow sits under a held piece. Pieces never rotate.
4. **World camera.** Two fingers pinch-zoom the world. One finger dragging on empty space pans it. Dragging a piece near the screen edge pans the camera. While one finger holds a piece, a second finger pans and zooms the view with it and the piece stays held, and the drag carries on when the second finger lifts. The board and the loose pieces share one world, and the frame-rate counter lives in screen space and does not zoom.
5. **Frame-rate counter.** Visible in debug builds, showing frames per second.
6. **Palette file.** One small file holding only the colours this slice needs, for both the light and dark modes: table felt, board, piece outline and accent. Values come from `docs/visual-design.md`.
7. **Generator tests.** Run headless.
8. **Runs on the owner's phone and on the desktop.** The desktop run uses the mouse to stand in for touch, so most work needs no phone.

## Goals

- 400 pieces hold 60 frames per second while dragging a piece and while pinch-zooming and panning, on the Nothing Phone (4a). Record the refresh rate each check ran at, since the screen goes up to 120 Hz.
- Piece edges look clean: a dark outline about 2.3 px wide at 80% opacity around every piece, with 2D antialiasing used if needed.
- Pinch and pan are reliable.
- The generator tests pass: piece areas sum to the image area, every interior edge belongs to exactly two pieces, no piece is below a minimum area, and the same seed gives identical output twice.

## Non-goals for this slice

- Snapping, locking and clusters.
- Sound and vibration.
- Saving and resuming.
- The setup screen, the piece-count slider, menus and any other screen.
- Tabs, the Regular, Irregular and Wild styles, and the ghost image.
- Slots, collections, the store, the timer and the completion screen.
- The full Godot Theme, fonts, buttons, corner radii and the settings for theme and roundness.
- Rotation of pieces.

## Anti-goals

- Visible stutter or lag while dragging.
- A separate pipeline per cut style. The generator must produce a graph of vertices and shared edges, with the pieces as the faces between them, so tabs and other styles can be added without rewriting it.
- Stored piece geometry. Only the image, style, count and seed identify a cut.
- Custom subsystems the engine already provides.
- Any new dependency, analytics or network call.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer for now. The renderer is still an open decision in `docs/open-decisions.md`. Android Min SDK is 29 with this renderer, so the Galaxy On7 Pro cannot run it.
- Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- Generation is deterministic. Use a small seeded random generator written in the project, not the engine's global random, and round generated points to a fixed precision.
- Shared edges are generated once. Neighbouring pieces use the same edge, one reversed.
- Pieces are drawn with `Polygon2D`, and hit-testing uses `Geometry2D.is_point_in_polygon`. This may change after this slice if drawing 400 polygons is too slow.
- Match the style of the surrounding code, keep comments sparse and prefer the engine's own features.
- Follow the planned layout in `AGENTS.md`: `src/cut/` for the generator, `src/game/` for the board, camera and input, `tests/` for tests.

## Decisions the owner made

- Build real code directly, not a throwaway spike.
- Build the board and piece movement first.
- Build only the colours the board needs now, and leave the full Theme and fonts for the first screen with buttons.
- The Mobile renderer for now.
- 400 pieces from the first version, since this is also the performance test.

## Calls made by Claude, which the owner has not confirmed

- The board is a rectangle in the middle of the screen showing the solved image's outline.
- Pieces start scattered around the board in random positions.
- One finger on a piece drags it, one finger on empty space pans, and two fingers pinch-zoom.
- The piece count is a constant in code that can be changed between 12 and 400.
- The test image is generated by code, such as a colourful pattern, so no licence or credit is needed yet. A real image comes with the first collection.

## Left to the builder

- File and class names inside the planned layout.
- Whether pinch uses the Android gesture project setting or raw touch events.
- How the camera is built, how the drawing order is managed and how the scatter positions are chosen.
- Which row-by-column split the grid uses for a given piece count and image shape, as long as cells stay close to square.
- Which test framework to use. GUT is the likely choice but has not been verified on Godot 4.7. A plain headless script is fine.
- How to check frame rate on the phone.

## What happens if it is too slow

If 400 pieces cannot hold 60 frames per second, try pre-baked sprites in place of `Polygon2D`, as `AGENTS.md` allows. If that also fails, the engine choice is reopened and the fallback is libGDX with Kotlin. Record the result in `docs/engine-decision.md`.
