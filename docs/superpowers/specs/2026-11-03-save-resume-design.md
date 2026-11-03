# Save and resume: sixth slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes one slice of version 1 in `docs/version-plan.md`: "Save and resume, covering loose piece positions, clusters, locked pieces and elapsed time", with the exit test "Saving and resuming restores the board exactly". The previous slice is `docs/superpowers/specs/2026-11-03-ui-cleanup-design.md`.

## Intent

`INTENT.md` says: "A game can be left half-finished and resumed. The save includes loose piece positions, clusters, slot contents and elapsed time." Slots are version 2, so this slice saves everything else. Today every launch scatters a fresh 400-piece puzzle, so a phone call or a swipe from recents throws away the player's work.

Two architecture rules shape the slice. Rule 3: "Never store piece geometry. Saves ... store the image id, style, piece count and seed, and regenerate the cut." Rule 10: "Save on app pause and after each lock, not every frame."

## What the slice delivers

1. **A save file.** `user://save/current.json`, small, human-readable JSON, written atomically: the text goes to `current.json.tmp`, which is then renamed over `current.json`, so an app crash mid-write leaves the previous save intact. Format in "The save file" below. One save, one puzzle.
2. **A pure save module.** `SaveGame` (`src/game/save_game.gd`) turns a board snapshot into a `Dictionary` and JSON text and back, and validates everything it reads. No nodes, no files.
3. **A tiny file layer.** `SaveFile` (`src/game/save_file.gd`): atomic write, read, remove. Nothing else touches the file system.
4. **A restore constructor on `PuzzleState`.** `PuzzleState.restored(...)` builds a state from saved clusters: roots, member groups, offsets and lock flags. It rebuilds the locked-piece counter and validates sizes and ids; any failure gives the empty state (`piece_count() == 0`), which the board treats as a failed load.
5. **Saving from the board.** After every lock, and on app pause, focus loss, a window close request and the Android back request, after the forced drop the board already does. Never every frame. When the puzzle is complete the save is deleted instead, so the next launch starts fresh.
6. **Restoring on start.** `Board._ready` reads the save, regenerates the cut from the saved puzzle identity (not from its constants), and restores clusters, offsets, locks, draw order, elapsed time and the tidy counter exactly. A missing save starts a fresh puzzle silently. A save that fails validation logs one warning, is deleted, and the board starts a fresh puzzle from its constants. A bad file never crashes the app.
7. **Elapsed time.** The board counts seconds while the app is focused and the puzzle is not complete. It is saved and restored, not shown; the version 2 timer shows it.

## The save file

Keys are sorted and indented with tabs (Godot puts each array element on its own line; the example is compacted for reading). About 60 KB at 400 loose pieces.

```json
{
	"clusters": [
		{ "locked": false, "offset": [-612.4567260742188, -301.5], "pieces": [0, 1, 20], "root": 1 },
		{ "locked": true, "offset": [0.0, 0.0], "pieces": [5], "root": 5 }
	],
	"elapsed": 754.2166666666667,
	"loose_order": [3, 7, 0, 1, 20],
	"puzzle": { "height": 1024, "image_id": "test-gradient", "piece_count": 400, "seed": 1, "style": "regular", "width": 1536 },
	"tidy_count": 2,
	"version": 1
}
```

- **`version`:** `1`. Any other value is rejected; there is no migration yet.
- **`puzzle`:** the identity the cut is regenerated from. `image_id` is `"test-gradient"` for the board's generated test image until the next slice adds real images. `width` and `height` are the image size in pixels. `style` is a `CutGenerator.STYLES` value. `piece_count` is the requested count, which can differ from the cut's real count when the split is not exact. `seed` is the cut seed.
- **`clusters`:** one entry per cluster, in ascending `root` order. `root` is the cluster's union-find root id, `pieces` its member ids ascending, `offset` its `[x, y]` displacement from home, `locked` its lock flag. A locked cluster's offset is always `[0.0, 0.0]`. Every cluster has all four keys.
- **`loose_order`:** the ids of every loose piece, bottom to top, in the order the loose layer draws them.
- **`elapsed`:** seconds played, a float.
- **`tidy_count`:** how many tidies moved something, so the next Tidy press gives the shuffle it would have given without the restart.
- **Nothing else.** No outline, home position, bounds, camera or any other geometry. A test walks every key of a real save against this exact list.

**Precision.** Floats are written with `JSON.stringify(data, "\t", true, true)`: sorted keys and full precision, 17 significant digits. Offsets are 32-bit floats in `PuzzleState` and node positions, so 17 digits write each one exactly and reading it back gives the identical bits. Elapsed time is a 64-bit float and also round-trips exactly. Nothing is snapped; a test checks the round trip is bit-exact. Integers (ids, counts, seed, size) are written as integers. Godot's JSON reader returns every number as a float, so the reader accepts a float only when it is finite and integral where an integer is expected.

**Identical bytes.** The same board saved twice writes the same bytes: sorted keys, clusters in root order, members ascending, and no timestamps.

## When it saves

| Moment | What happens |
|---|---|
| A drop locks a cluster | `_settle` saves after emitting its signals. |
| `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_CLOSE_REQUEST`, `NOTIFICATION_WM_GO_BACK_REQUEST` | Complete a running tidy, force-drop whatever is held (which may itself lock and save), then save. |
| The puzzle is complete | `save_game()` deletes the file instead of writing, whoever calls it. So a forced drop on pause that completes the puzzle does not leave a save behind for the pause to rewrite. |
| Anything else | Nothing. A drag, a plain drop, a join, a tidy, a pan or a zoom does not save. A join is saved by the next lock or the next pause. |

- **While a tidy animates:** the state already holds the final offsets, and the snapshot reads the state, never node positions. So a save mid-animation stores the tidied layout.
- **A failed write** logs one warning and the game carries on; the previous file is untouched.

## Restoring

`_ready` does this, in order. Each step either passes or fails with a reason; the first failure logs one `push_warning("Board: discarding the save at <path>: <reason>")`, deletes the file, and the board starts fresh from `IMAGE_SIZE`, `PIECE_COUNT`, `STYLE` and `SEED` with a new scatter.

1. **No file:** fresh, no warning.
2. **Read and parse.** `SaveGame.from_json` parses with a `JSON` instance's `parse()` (`JSON.parse_string` prints an error on bad input), then checks the structure: a Dictionary with exactly the keys above at every level and the right types; `version == 1`; `style` in `CutGenerator.STYLES`; `piece_count` from 1 to `SaveGame.MAX_PIECE_COUNT` (400); width and height at least 1; every number finite; ids, counts and the seed integral; `elapsed >= 0` and `tidy_count >= 0`.
3. **The image.** Until real images arrive, only `image_id == Board.IMAGE_ID` (`"test-gradient"`) at `Board.IMAGE_SIZE` is valid, because the board cannot draw anything else.
4. **Regenerate.** `CutGenerator.generate_cut(width, height, piece_count, style, seed)`. Steps 2 and 3 make sure this cannot push an error.
5. **Clusters.** `PuzzleState.restored` with the regenerated cut. It fails, giving the empty state, when the four arrays differ in size, a group is empty, an id is out of range for the regenerated cut, a piece is in no cluster or in two, a root is not in its own group, a lock flag is not 0 or 1, or a locked cluster has a non-zero offset. A piece-count mismatch with the regenerated cut shows up here. A restored state that `is_complete()` is also rejected: the empty state counts as complete, and a finished puzzle never has a save.
6. **Draw order.** `loose_order` holds every loose piece exactly once and no locked piece.
7. **Build.** Every node is created as on a fresh start, positioned at `state.offset_of(id)`. Loose nodes are added to the `pieces` layer in `loose_order`; locked nodes go to `locked_pieces` in ascending id. `elapsed` and `_cleanup_count` take the saved values. The camera bounds become the base bounds merged with every loose cluster's home rect at its offset, so a tidied band stays reachable. The camera fits the board as on a fresh start.

Restoring emits no signal, so nothing plays a sound. Roots keep their saved ids, so every later join, lock, tie-break and tidy order is the same as if the app had never closed.

**Validation lives in three places, each once.** `SaveGame` checks the file's shape, types and ranges. `PuzzleState.restored` checks that the clusters partition the cut and that locks are consistent, because those are its invariants. The board checks what only it knows: the image, the loose draw order and completion. `PuzzleState.restored` fails silently, since its input comes from a file; the board's one warning names the stage.

## Elapsed time

- `Board.elapsed`, seconds as a float, starts at 0 on a fresh puzzle.
- `_process` adds `minf(delta, ELAPSED_STEP_LIMIT)` (0.25 s) when the board is focused and `state.is_complete()` is false. The cap keeps one long frame, such as the first frame after the app comes back, from adding the whole time away.
- Focus: `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED` stop counting; `NOTIFICATION_APPLICATION_FOCUS_IN` and `NOTIFICATION_APPLICATION_RESUMED` start it again.
- Nothing shows it in version 1.

## Goals

- Leaving the app at any moment and coming back gives the same board: every cluster, offset, lock, draw order, the tidy counter and the elapsed time, to the bit.
- A crash or a bad file never costs more than the last save, never crashes, and never leaves the player stuck: the worst case is one warning and a fresh puzzle.
- Saving never runs per frame, and the file never holds geometry.
- Tests never touch a real save.

## Non-goals for this slice

- Multiple save slots, choosing a puzzle, the setup screen, slots and their contents (version 2), stats, cloud saves.
- Showing the elapsed time (the version 2 timer).
- Saving the camera position and zoom.
- Migrating older save versions; version 1 is the first.
- Saving on every join or drag.

## Anti-goals

- Any outline, bounds, home position or other geometry in the save.
- A save written every frame, or a write on the drag path.
- A corrupt save after an app crash mid-write.
- A crash, an error, or a stuck board from any file contents.
- A finished puzzle that comes back on the next launch.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies, plugins or network calls.
- Generation stays deterministic: the same identity regenerates the same cut on every device, which is what makes geometry-free saves work.
- Tests are plain headless scripts extending `BaseTest` or `BoardTest`, run with `godot --headless --script tests/<name>.gd`. Board tests set `Board.save_path` to a test path before the board enters the tree.
- Match the style of the surrounding code. Keep comments sparse and explain why.

## Decisions the owner made

- Saves hold the image, style, count and seed; cut geometry is regenerated, never stored (`INTENT.md` "Decisions already made", `AGENTS.md` rule 3).
- Save on app pause and after each lock, not every frame (`AGENTS.md` rule 10).
- The save includes loose piece positions, clusters, locked pieces and elapsed time; slot contents join it in version 2 (`INTENT.md`, `docs/version-plan.md`).

## Calls made by Claude, which the owner has not confirmed

The orchestrator was delegated these decisions by the owner. Each one below is Claude's, or the orchestrator's where marked.

- **Scope, path, atomic write, triggers, delete on completion, restore on start, elapsed time, the tidy counter in the save, a `save_path` override for tests** (orchestrator). The previous slice's call "the counter is not saved" is replaced: it is now saved.
- **Loose draw order is saved as piece ids** (orchestrator). Claude: the locked layer's order is not saved; locked pieces sit at home, so their order cannot be seen.
- **Board owns the cut** (orchestrator left it open). Claude: `Board.cut` stays the board's, generated in `_ready` from the saved identity or the constants. The board holds that identity as `Board.puzzle`, and `cleanup()` uses `puzzle.cut_seed` instead of `SEED`.
- **Full-precision floats, not snapping.** Snapping offsets to the generator's 0.001 would move every piece by up to half a thousandth of a pixel, so the restored board would not be the saved one to the bit. Full precision round-trips 32-bit offsets exactly at the cost of longer numbers.
- **Every cluster has all four keys,** and locked ones write `[0.0, 0.0]`. One shape is simpler to read and validate than optional keys.
- **The root id is saved.** `PuzzleState` breaks merge ties and orders `roots()` by root id, and `cleanup()` lays clusters out in that order. Saving the root makes every later join and tidy match the unrestarted game exactly.
- **A missing save is silent.** It is the normal first launch, not an error.
- **A fully locked save is rejected,** since completion deletes the save and such a file can only be stale or hand-made.
- **`MAX_PIECE_COUNT` of 400 in a save,** the game's maximum, so a damaged count cannot make the generator run for minutes on start.
- **Only the test image is valid** until the next slice replaces the check with an image lookup.
- **The Android back request also saves.** Godot quits on back by default (`quit_on_go_back`), and it is the most common way to leave on Android, so it is treated like a close request: forced drop, then save. The forced drop also extends from focus loss and pause to both requests.
- **Saves on lock run on the main thread.** A 60 KB stringify and write should take a few milliseconds. The owner checks for a hitch on the phone; if there is one, the save moves to a deferred call or a thread in a follow-up.
- **No fsync.** Godot's `FileAccess` has no fsync. The rename protects against an app crash, which is the case that matters on a phone. A power cut right after a save could still leave an empty or old file; the next launch then warns once and either resumes the older save or starts fresh.
- **Elapsed counting rules:** focus out and pause stop it, focus in and resume start it, each frame adds at most 0.25 s.
- **The camera is not saved.** A resume fits the board like a fresh start; the camera bounds are rebuilt from the loose clusters, so everything stays reachable.
- **Tab indentation.** Human-readable, as asked, at about twice the compact size, still small.
- **File layout.** `save_game.gd` and `save_file.gd` live in `src/game/`, next to `PuzzleState`, since the planned layout has no save directory.

## Left to the builder

- Private helper and field names inside the interfaces the plan fixes.
- The exact wording of each warning's reason, as long as it starts with `Board: discarding the save at`.
- How `SaveGame.from_dict` walks the keys, as long as every check above is made before any value is used.

## What happens if it does not work right

The owner checks resume on the phone (the plan's "Owner checks"). If the board comes back different, the round-trip test is extended with the case the phone found. If a lock visibly stutters, the save on lock moves off the frame (deferred or threaded). If leaving by back or by swiping from recents loses progress, the board gains a save on the notification that does arrive on that path; `adb logcat` shows which ones fire.
