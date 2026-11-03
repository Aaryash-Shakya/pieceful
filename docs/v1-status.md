# Version 1 status

Written 2026-11-03, after the last version 1 slice (PR #8) was merged. The version plan is `docs/version-plan.md`. This file records what is built, the decisions made while building it, and what only the owner's phone can settle.

## Where version 1 stands

All version 1 scope items are built. The exit tests that need a real phone have not been run.

| Scope item | State | Where |
|---|---|---|
| Godot 4 project, Android export, repeatable install | Built | `project.godot`, `export_presets.cfg`, `tools/build_apk.sh`, `docs/dev-setup.md` |
| Cut generator and tests (grid, Regular, Irregular) | Built | `src/cut/`, spec `2026-11-02-cut-styles-design.md` |
| Setup screen: slider over valid counts, live preview | Built | `src/ui/setup_screen.gd`, spec `2026-11-03-setup-collection-design.md` |
| World camera, pinch-zoom, pan, piece dragging | Built | `src/game/board.gd`, spec `2026-10-22-board-and-piece-movement-design.md` |
| Locking and clusters | Built | `src/game/puzzle_state.gd`, spec `2026-11-02-snapping-design.md` |
| Sound and vibration on joins and locks | Built | `src/game/feedback.gd`, spec `2026-11-03-feedback-design.md` |
| Cleanup button | Built (named Tidy) | `src/game/cleanup_layout.gd`, spec `2026-11-03-ui-cleanup-design.md` |
| Save and resume | Built | `src/game/save_game.gd`, `save_file.gd`, spec `2026-11-03-save-resume-design.md` |
| Bundled collections | Built, placeholder art. Version 2 added three more (geometry, landscape, pattern) and a picker on the setup screen | `assets/collections/`, `tools/make_collection.gd`, `src/game/collection_library.gd` |
| Frame-rate counter in debug builds | Built | `src/ui/fps_counter.gd` |

The exit tests:

| Exit test | State |
|---|---|
| Generator tests pass (areas sum, shared edges, minimum area, determinism) | Pass, headless |
| Saving and resuming restores the board exactly | Pass, headless (round trip, byte-identical resave, bad-file cases). Not yet run on a device. |
| 400 pieces hold 60 fps while dragging and zooming | **Not measured. Needs the phone.** |
| The snap sound and vibration feel instant | **Not judged. Needs the phone.** |

Seven slices built it, each with a spec in `docs/superpowers/specs/` and a plan in `docs/superpowers/plans/`: board and piece movement, cut styles, snapping, feedback, UI and cleanup, save and resume, setup screen and collection. The first slice also added a follow-up change that keeps a held piece while a second finger pans and zooms.

## Decisions made while building

These were made by Claude while the owner had delegated the open choices. The owner can overturn any of them.

**Product and scope**
- Slots stay in version 2. Effects other than the lift shadow (snap ring, confetti, shake) are not in the version 1 scope and were skipped.
- Portrait only, 540 by 1200 viewport, `canvas_items` stretch with `expand`.
- Renderer: Mobile. It gives Android Min SDK 29, so the Galaxy On7 Pro (Android 6) cannot install a Mobile build. The Compatibility renderer is still an open question.
- The bundled pictures are six generated abstract images (the project's own work, CC BY 4.0, marked generated). They are placeholders. The richness checks in the tests measure grain and colour, not structure, and some pictures (ember-rings, woven-plaid) have wide plain bands. Whether they are good to solve is an owner check.
- Start replaces a saved game without asking. The Resume card is on the same screen.

**Cuts**
- Irregular corner jitter is 8% (the plan said 15%) and its tab values are (size 0.10, size jitter 0.10, shift 0.04, wobble 0.02), because a worst-case test showed outlines crossing themselves at the plan's values. A piece that cannot be drawn costs more than wobblier corners. Compare Irregular with Regular on screen and say if it looks too tame.
- Tab curves and edge room use 64-bit GDScript maths and are snapped before becoming `Vector2`, so cuts match across CPUs. The split choice uses a project-owned logarithm, not the system `log`.
- Golden checksums pin a whole 400-piece Regular cut and a whole Irregular cut (1536 by 1024, seed 1) and one tab edge's 27 points. A deliberate change to a cut changes every saved puzzle, so bump `SaveGame.VERSION` too.
- Valid piece counts are exact rows-by-columns splits with near-square cells. On a 3:2 picture 200 and 250 are not valid, which the daily puzzle ramp only tolerates because those are Wild days. Open decision 13 covers the daily count on other picture shapes.

**Snapping and Tidy**
- A drop locks first, then joins. After a merge the join repeats from the merged position until nothing more fits, so a near fit never stays apart. A big resting cluster never jumps to meet a small one.
- Tidy puts the final positions in the puzzle state at once and animates the pieces over 0.4 s. The next touch, a pause or focus loss, or another Tidy finishes the animation. Tidy is ignored while a piece is held. The gap between tidied clusters is at least 1.25 times the join tolerance, so a tidy never leaves neighbours close enough to join by accident. The camera stays put and its reachable bounds grow.

**Sound, vibration and the engine**
- Godot's Android audio driver ignores the project latency settings and adds about 46 ms of fixed buffering (see `docs/engine-decision.md`). No latency setting is used. If the snap does not feel instant, the fallback is an Oboe-based audio plugin.
- Vibration: join 12 ms at 0.5, lock 25 ms at 1.0, completion 60 ms at 1.0, none on pick-up. Feedback is silent for drops forced by the app losing focus or pausing.
- The export excludes `tools/*` and `tests/*` and includes the OFL font licence texts. A headless debug export builds (about 35 MB).

**Saves**
- The save is JSON at `user://save/current.json`, written atomically (flush, error check, read-back, rename). Godot has no fsync, so a power cut right after a save can still lose it.
- Saves happen after every lock and on pause, focus out, close and back. Completing a puzzle deletes the save. The clock runs only while the window has focus.
- A save the game cannot use is moved aside to `current.bad.json` with one warning, never deleted. A healthy save is left alone if its pictures are temporarily unavailable. A missing save starts fresh quietly.
- The save stores a checksum of the cut, so generator changes are detected on restore.
- The file keeps readable tab indentation. Dropping it was measured and saves only about 80 microseconds of each save's 2.9 ms. If a lock hitches on the phone, move the save off the frame instead.

**Process**
- Each slice followed the same loop: spec and plan, one implementer per task, a review per task, a final review, a pull request, a code review, and a merge.
- The shell tool used by the agents refuses to write files with `curl -o`, so the fonts were downloaded by the controller from a pinned google/fonts commit.

## Known gaps and deferred work

- Version 2 is built, see `docs/v2-status.md`. Version 3 (Wild, daily puzzle, the collection store, stats, release builds) are not started.
- The room measure for tabs is average cell width, which suits the grid styles. Wild needs a better one.
- Picking up or locking a very large cluster costs about 1 to 2.4 ms on the desktop. The phone may be 3 to 5 times slower.
- The setup screen decodes the full 2048 px picture on every tile tap and generates the preview on the main thread. A `WorkerThreadPool` preview is the fix if the phone hitches.
- The picture strip is a scroller inside the page scroller. On short phones a vertical swipe starting on the strip may not scroll the page.
- If moving a bad save aside fails, a later fresh game may overwrite it.
- Resume on a save that fails the board's deeper checks starts that picture fresh with a warning.
- No disabled-button theme style for slots and screens that need it later, the Tidy and Home buttons use a fixed 56-unit top inset instead of the real safe area, and the build script has no stub-based behaviour test.

## What only the phone can settle

Install with `tools/build_apk.sh` (or Remote Deploy), then check:

1. **Performance, the decisive check.** Start a 400-piece puzzle on a collection picture. Zoom out so all 400 pieces are visible. Drag a piece for 10 seconds and write down the lowest fps, the worst frame time and the refresh rate the counter shows. Pinch-zoom and pan for 10 seconds and note the same. Look at the piece edges for jaggedness. If this fails, the version plan reopens the engine choice, with pre-baked piece sprites tried first and libGDX with Kotlin as the fallback. Record the results in `docs/engine-decision.md`.
2. **Snap feel.** Do the sound and buzz feel instant when pieces join and lock? Do they feel good? If the sound is late, try an Oboe audio plugin.
3. **Setup screen.** The picture strip scrolls by swipe to the fifth and sixth pictures, a swipe never selects and a tap does. The slider is easy to grab and does not hitch on release. Tapping a picture shows no annoying pause. The preview lines read on every picture in light and dark mode. The lossy pictures look clean up close.
4. **Starting, leaving, resuming.** First launch over the old test save shows no Resume card and a `current.bad.json` exists. Home and Android back return to setup and show Resume. Resume restores the board exactly, including after swiping the app away from recents. Back on setup quits. Tapping Start rapidly opens one board. A finished puzzle leaves no Resume card.
5. **Controls.** Hold a piece, then pan and zoom with a second finger, and the drag continues when it lifts. Tidy works with a finger resting on the board and a second-finger tap does the same. Hold a piece near its place, press home, come back: the lock plays once and nothing plays late. Home, Tidy and the frame counter sit clear of the status bar and camera cutout on a tall phone.
6. **Install.** Running `tools/build_apk.sh` over the installed app keeps the save.
7. **The art.** Say which generated pictures to replace.
