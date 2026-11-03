# Save and Resume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The board saves its progress to `user://save/current.json` after every lock and whenever the app is left, and resumes it exactly on the next start, regenerating the cut from the saved identity and never storing geometry.

**Architecture:** `PuzzleState.restored(...)` rebuilds a state from saved clusters. A pure `SaveGame` module turns a board snapshot into sorted, full-precision JSON and back, validating every value. A tiny `SaveFile` layer writes atomically (temp file, then rename). `Board` gains its puzzle identity, an elapsed-time counter, `snapshot()` and `save_game()`, saves on lock and on the four leave notifications, and restores in `_ready`, falling back to a fresh puzzle with one warning on any bad file.

**Tech Stack:** Godot 4.7.2, GDScript, Mobile renderer. Tests are plain headless scripts extending `BaseTest` or `BoardTest`.

**Spec:** `docs/superpowers/specs/2026-11-03-save-resume-design.md`. Also read `INTENT.md` and `AGENTS.md`.

## Global Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies, plugins or network calls.
- The save never holds geometry: its keys are exactly `version`, `puzzle` (`image_id`, `width`, `height`, `style`, `piece_count`, `seed`), `clusters` (`root`, `pieces`, `offset`, `locked`), `loose_order`, `elapsed`, `tidy_count`.
- Save after each lock and on `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_WM_GO_BACK_REQUEST`, never every frame and never on a drag, plain drop, join or tidy. A complete puzzle deletes the save instead.
- JSON is written with `JSON.stringify(data, "\t", true, true)` and parsed with `JSON.new().parse(text)`, never `JSON.parse_string`, which prints an error on bad input.
- A bad save logs exactly one `push_warning` starting `Board: discarding the save at`, is deleted, and the board starts fresh from its constants. A missing save logs nothing. No file contents may cause an error or a crash.
- Tests never touch `user://save/`: board tests set `board.save_path = BoardTest.TEST_SAVE_PATH` before the board enters the tree.
- Run `godot --headless --import` after adding any file with a new `class_name`, then `timeout 120 godot --headless --script tests/<name>.gd`. A passing run prints `0 failure(s)` and exits 0.
- Match the surrounding code style, sparse comments that explain why. Conventional commits, one per task; include the `.uid` files Godot creates.

## Review Focus

- A forced drop on pause locks the last cluster: the puzzle completes, the save is deleted, and the pause's own save must not write it back (Task 4, `_test_pause_completing_drop_leaves_no_save`).
- A save whose requested count is not an exact split (55 gives 54 pieces): the restore compares against the regenerated cut, not the requested count, and keeps the requested count for the next save (Task 5, `_test_other_identity`).
- A stale `current.json.tmp` from a crash before the rename: the read ignores it, and the next write replaces it and leaves no temp file (Task 3, `_test_stale_temp_is_ignored`).
- A restored board saved again before anything changes writes the identical bytes, which catches any field that drifts in the round trip (Task 5, `_test_resave_is_identical`).
- The first frame after the app returns can carry the whole time away as its delta: elapsed time grows by at most 0.25 s per frame (Task 4, `_test_elapsed_counts`).

---

### Task 1: Restoring a puzzle state

**Files:**
- Create: `tests/log_capture.gd`
- Modify: `src/game/puzzle_state.gd`, `tests/test_puzzle_state.gd`

**Interfaces:**
- Produces on `PuzzleState`:
  - `static func restored(pieces: Array[CutPiece], tolerance_value: float, roots: PackedInt32Array, groups: Array[PackedInt32Array], offsets: PackedVector2Array, locked: PackedByteArray) -> PuzzleState`. Entry `k` of the four arrays describes one cluster: its root id, its member ids, its offset and its lock flag (0 or 1). Builds a state whose `find(id)` is `roots[k]` for every member, whose `members(root)` is the group sorted ascending, whose offsets and lock flags are the given ones, and whose locked-piece counter is the sum of the locked groups' sizes. On any invalid input it returns the empty state (`piece_count() == 0`) without calling `push_error` or `push_warning`, because its input comes from a file. Invalid: the four arrays differ in size; a group is empty; an id is outside `0 ..< pieces.size()`; a piece is in no group or in two; `roots[k]` is not in `groups[k]`; a lock flag other than 0 or 1; a locked group whose offset is not `Vector2.ZERO`. Pieces whose ids are not their indices still go through `_init`'s check and its `push_error`, since the pieces come from the generator, not the file.
- Produces `tests/log_capture.gd` (no `class_name`; tests use `const LogCapture := preload("res://tests/log_capture.gd")`): `extends Logger`, `var warnings := PackedStringArray()`, `var errors := PackedStringArray()`. `_log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void` appends `rationale if rationale != "" else code` (a `push_warning` message arrives in `code`) to `warnings` when `error_type == Logger.ERROR_TYPE_WARNING`, else to `errors`, under a `Mutex` because loggers can be called from any thread. `_log_message` does nothing. Never print from inside it. Used as `var capture := LogCapture.new(); OS.add_logger(capture)`, then `OS.remove_logger(capture)`.

- [ ] **Step 1: Write `tests/log_capture.gd`** as in the Interfaces block.
- [ ] **Step 2: Add the failing tests to `tests/test_puzzle_state.gd`.** Add the three calls to `_init` before `finish()`. A helper `_parts(state: PuzzleState) -> Array` returns `[roots, groups, offsets, locked]` read from `state.roots()`, `members`, `offset_of` and `is_locked` (as 0 or 1), and `_restore(parts: Array) -> PuzzleState` calls `PuzzleState.restored(cut, _fixture_tolerance(), parts[0], parts[1], parts[2], parts[3])`.
  - `_test_restore_round_trip`: `s := _fresh()`, `_play(s)`, `s.move_cluster(2, Vector2(-612.4567, 0.1))`, `r := _restore(_parts(s))`: `_snapshot(r) == _snapshot(s)` (roots, members, offsets and locks, to the bit); `r.find(i) == s.find(i)` for every `i`; `r.is_complete() == s.is_complete()`; `r.tolerance == s.tolerance`. Then on both `move_cluster(3, offset_of(0))` and `drop(3)`: the two `DropResult`s have equal `root`, `joined` and `locked`, and `_snapshot(r) == _snapshot(s)` ("a restored state plays on identically").
  - `_test_restore_counts_locked`: roots `[0, 3]`, groups `[[2, 0, 1], [3, 4, 5]]`, offsets both `Vector2.ZERO`, locked `[1, 1]`: `piece_count() == 6`, `is_complete()`, `members(1) == PackedInt32Array([0, 1, 2])`. The same with locked `[1, 0]` and the second offset `Vector2(50, 50)`: `not is_complete()`, `is_locked(0)`, `not is_locked(4)`, `offset_of(5) == Vector2(50, 50)`.
  - `_test_restore_rejects_bad_input`: start from `good := _parts(` a `_fresh()` state after `_play` `)`; each case changes a deep copy and checks `_restore(case).piece_count() == 0` with its label: roots one shorter than groups; an empty group added (with a root, offset and flag); id 6 in a group; id -1 in a group; a piece in two groups; a group removed with its entries (a piece in no group); a root not in its group; a lock flag of 2; a locked group with offset `Vector2(1, 0)`. Run the cases between `OS.add_logger(capture)` and `OS.remove_logger(capture)`, then `capture.warnings.is_empty() and capture.errors.is_empty()` ("bad input is rejected silently").
- [ ] **Step 3: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_puzzle_state.gd`. Expected: an error that `restored` is not found.
- [ ] **Step 4: Implement `PuzzleState.restored`** as in the Interfaces block: validate everything first, then build from `PuzzleState.new(pieces, zero offsets, tolerance_value)`; the empty state is `PuzzleState.new(empty typed Array[CutPiece], PackedVector2Array(), tolerance_value)`.
- [ ] **Step 5: Run it again.** `timeout 120 godot --headless --script tests/test_puzzle_state.gd`. Expected: `0 failure(s)`.
- [ ] **Step 6: Commit.** `git add src/game/puzzle_state.gd tests/test_puzzle_state.gd tests/log_capture.gd tests/log_capture.gd.uid && git commit -m "feat: restore a puzzle state from saved clusters"`

### Task 2: The save format

**Files:**
- Create: `src/game/save_game.gd`, `tests/test_save_game.gd`

**Interfaces:**
- Consumes: Task 1's `PuzzleState.restored` and `LogCapture`; `CutGenerator.STYLES`.
- Produces `class_name SaveGame extends RefCounted` in `src/game/save_game.gd`:
  - `const VERSION := 1`, `const MAX_PIECE_COUNT := 400`, `const MAX_EXACT_INT := 9007199254740992.0` (2^53, the largest integer a JSON number holds exactly).
  - `class Puzzle:` `var image_id := ""`, `var image_size := Vector2i.ZERO`, `var style := ""`, `var piece_count := 0` (requested), `var cut_seed := 0`.
  - `class Cluster:` `var root := -1`, `var pieces := PackedInt32Array()`, `var offset := Vector2.ZERO`, `var locked := false`.
  - `class Snapshot:` `var puzzle := Puzzle.new()`, `var clusters: Array[Cluster] = []`, `var loose_order := PackedInt32Array()`, `var elapsed := 0.0`, `var tidy_count := 0`.
  - `class Loaded:` `var snapshot: Snapshot = null`, `var error := ""`. Exactly one of them is set.
  - `static func to_dict(snapshot: Snapshot) -> Dictionary`: the spec's "The save file" shape: `version`; `puzzle` with `image_id`, `width`, `height`, `style`, `piece_count`, `seed`; `clusters` as an Array of `{root, pieces, offset: [x, y], locked}` in the snapshot's order, ids and counts as `int`, `pieces` as an Array of `int`; `loose_order` as an Array of `int`; `elapsed`; `tidy_count`.
  - `static func to_json(snapshot: Snapshot) -> String`: `JSON.stringify(to_dict(snapshot), "\t", true, true)`.
  - `static func from_dict(data: Variant) -> Loaded`: every check in the spec's "Restoring" step 2, made before any value is used: `data` and `puzzle` and each cluster are Dictionaries with exactly their keys; `version == 1`; `image_id` a non-empty String; `style` a String in `CutGenerator.STYLES`; `piece_count` an integer from 1 to `MAX_PIECE_COUNT`; `width` and `height` integers of at least 1; `seed` an integer; `clusters`, `pieces`, `loose_order` Arrays; `root`, every member id and every `loose_order` entry an integer; `offset` an Array of exactly two finite numbers; `locked` a bool; `elapsed` a finite number of at least 0; `tidy_count` an integer of at least 0. An integer is an `int`, or a finite `float` with `v == floorf(v)` and `absf(v) <= MAX_EXACT_INT` (Godot's JSON reader returns every number as a float). Id ranges are not checked here; `PuzzleState.restored` and `loose_order_valid` do that. `error` names the first failing key.
  - `static func from_json(text: String) -> Loaded`: `JSON.new().parse(text)`, an `error` naming the parse failure when it is not `OK`, else `from_dict(json.data)`. Prints nothing.
  - `static func clusters_of(state: PuzzleState) -> Array[Cluster]`: one per `state.roots()` entry, ascending, with `members`, `offset_of` and `is_locked`.
  - `static func state_from(clusters: Array[Cluster], pieces: Array[CutPiece], tolerance: float) -> PuzzleState`: unpacks the clusters into `PuzzleState.restored`'s four arrays.
  - `static func loose_order_valid(order: PackedInt32Array, state: PuzzleState) -> bool`: true when `order` holds every unlocked piece id of `state` exactly once and nothing else.

- [ ] **Step 1: Write the failing test `tests/test_save_game.gd`** extending `BaseTest`. Fixture: `cut := CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)`, `tolerance := PuzzleState.tolerance_for(300, 200, 6)`, and `_played() -> PuzzleState`, a state with offsets `Vector2(1000 * (i + 1), 0)` that then runs the moves of `_play` in `tests/test_puzzle_state.gd` (copy those seven lines) plus `move_cluster(2, Vector2(-612.4567, 0.1))` and `move_cluster(3, Vector2(1e-7, 3.3333333))`. `_sample() -> SaveGame.Snapshot`: puzzle `"test-gradient"`, `Vector2i(300, 200)`, `"grid"`, 6, cut seed 1; `clusters_of(_played())`; `loose_order` `[3, 2, 0, 1, 4]`; `elapsed` `754.2166666666667`; `tidy_count` 2. `_init` runs these, then `finish()`:
  - `_test_clusters_of`: on `_played()`, the roots of `clusters_of` equal `state.roots()`, and each cluster's `pieces`, `offset` and `locked` equal `members`, `offset_of` and `is_locked` of its root.
  - `_test_dict_shape`: `d := SaveGame.to_dict(_sample())`: sorted `d.keys()` is `["clusters", "elapsed", "loose_order", "puzzle", "tidy_count", "version"]`; sorted puzzle keys `["height", "image_id", "piece_count", "seed", "style", "width"]`; every cluster's sorted keys `["locked", "offset", "pieces", "root"]`; `d.version == 1`, `d.puzzle.seed == 1`, `d.puzzle.width == 300`; the locked cluster (root 5) has `Vector2(o[0], o[1]) == Vector2.ZERO`.
  - `_test_json_round_trip_is_exact`: `text := SaveGame.to_json(s)`, `l := SaveGame.from_json(text)`: `l.error == ""`; every puzzle field equal; equal cluster count and, per cluster, equal `root`, `pieces`, `locked` and `offset` with `==` (not approximately); `loose_order`, `elapsed` (with `==`) and `tidy_count` equal; `SaveGame.to_json(l.snapshot) == text`. Also `SaveGame.from_dict(SaveGame.to_dict(s)).error == ""` (integers as `int` are accepted too).
  - `_test_json_is_stable`: `to_json(_sample()) == to_json(_sample())`; the text contains none of `"outline"`, `"bounds"`, `"home"`.
  - `_test_state_from`: `r := SaveGame.state_from(_sample().clusters, cut, tolerance)`: `r.piece_count() == 6`, and roots, members, offsets and locks equal `_played()`'s.
  - `_test_rejects_bad_data`: with `capture` attached, each case is a `duplicate(true)` of `to_dict(_sample())` with one change, and `from_dict(case)` must give `snapshot == null` and a non-empty `error`, labelled: not a Dictionary (`[]`); `version` 2; `version` `"1"`; `version` missing; an extra top-level key `"outline"`; `clusters` missing; `puzzle.seed` missing; `puzzle.seed` 1.5; `style` `"wild"`; `style` 3; `piece_count` 0; `piece_count` 401; `piece_count` 12.5; `width` 0; `height` -1; `image_id` 5; `image_id` `""`; `clusters` a Dictionary; a cluster that is a number; a cluster missing `root`; a cluster with an extra key `"home"`; `pieces` holding 1.5; `pieces` a String; `root` 1e300; `offset` with one element; `offset` holding `"x"`; `offset` holding `INF`; `offset` holding `NAN`; `locked` `"yes"`; `loose_order` holding `"3"`; `elapsed` -1; `elapsed` `INF`; `tidy_count` -1; `tidy_count` 0.5. Then `from_json` of `""`, `"{bad"`, the first half of `to_json(_sample())`, `"[]"` and `"null"` each give `snapshot == null` and an `error`. After removing the logger: `capture.warnings.is_empty() and capture.errors.is_empty()`. Build the `INF` cases on the dictionary, not as text: Godot's number parser itself warns "Exponent too high" on `1e99999`.
  - `_test_loose_order_valid`: on `_played()` (pieces 0, 1, 4 joined and loose, 2 and 3 loose, 5 locked): `[3, 2, 0, 1, 4]` and `[0, 1, 2, 3, 4]` are valid; `[3, 2, 0, 1]` (missing), `[3, 2, 0, 1, 4, 4]` (twice), `[3, 2, 0, 1, 4, 5]` (locked), `[3, 2, 0, 1, 6]` and `[3, 2, 0, 1, -1]` are not.
- [ ] **Step 2: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_save_game.gd`. Expected: an error that `SaveGame` is not found.
- [ ] **Step 3: Implement `SaveGame`** as in the Interfaces block. Run `godot --headless --import`.
- [ ] **Step 4: Run it again.** `timeout 120 godot --headless --script tests/test_save_game.gd`. Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game/save_game.gd src/game/save_game.gd.uid tests/test_save_game.gd tests/test_save_game.gd.uid && git commit -m "feat: encode and validate saves"`

### Task 3: Atomic save files

**Files:**
- Create: `src/game/save_file.gd`, `tests/test_save_file.gd`

**Interfaces:**
- Consumes: Task 1's `LogCapture`.
- Produces `class_name SaveFile extends RefCounted` in `src/game/save_file.gd`:
  - `const DEFAULT_PATH := "user://save/current.json"`, `const TEMP_SUFFIX := ".tmp"`
  - `static func write_atomic(path: String, text: String) -> Error`: `DirAccess.make_dir_recursive_absolute(path.get_base_dir())`; writes `text` to `path + TEMP_SUFFIX` with `FileAccess.open(..., FileAccess.WRITE)` and `store_string`, closes it, then `DirAccess.rename_absolute(temp, path)`, which replaces the old file in one step. Returns `OK`, or the first error (`FileAccess.get_open_error()`, `ERR_FILE_CANT_WRITE` when `store_string` returns false, or the rename's error); on any error after the temp file was created, the temp file is removed.
  - `static func read(path: String) -> String`: the file's text, or `""` when it does not exist, without printing anything. Never reads the temp file.
  - `static func remove(path: String) -> void`: deletes `path` and `path + TEMP_SUFFIX` when they exist, silently otherwise.

- [ ] **Step 1: Write the failing test `tests/test_save_file.gd`** extending `BaseTest`, with `DIR := "user://test_save_file"` and `PATH := DIR + "/current.json"`. `_init` attaches `capture`, runs the first five tests, removes the logger and checks `capture.warnings.is_empty() and capture.errors.is_empty()` ("the file layer prints nothing"), then runs `_test_write_failure`, removes `DIR`'s files and `DIR`, and calls `finish()`:
  - `_test_write_creates_directory`: remove `PATH`, its temp file and `DIR`; `write_atomic(PATH, "one") == OK`; `read(PATH) == "one"`; `not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX)`.
  - `_test_write_replaces`: `write_atomic(PATH, "two") == OK`; `read(PATH) == "two"`; no temp file.
  - `_test_stale_temp_is_ignored`: `write_atomic(PATH, "good")`; write `"half"` straight to `PATH + TEMP_SUFFIX` with `FileAccess`; `read(PATH) == "good"`; `write_atomic(PATH, "three") == OK`; `read(PATH) == "three"`; no temp file.
  - `_test_read_missing`: `SaveFile.remove(PATH)`: `read(PATH) == ""`, `not FileAccess.file_exists(PATH)`.
  - `_test_remove`: write `PATH` and a temp file; `remove(PATH)`: neither exists; `remove(PATH)` again changes nothing.
  - `_test_write_failure`: write a file `DIR + "/blocker"`; `write_atomic(DIR + "/blocker/x.json", "x") != OK`; `read(DIR + "/blocker")` still returns the text written to it. Godot may print its own error here, so this test runs outside the silence check.
- [ ] **Step 2: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_save_file.gd`. Expected: an error that `SaveFile` is not found.
- [ ] **Step 3: Implement `SaveFile`** as in the Interfaces block. Run `godot --headless --import`.
- [ ] **Step 4: Run it again.** `timeout 120 godot --headless --script tests/test_save_file.gd`. Expected: `0 failure(s)`.
- [ ] **Step 5: Commit.** `git add src/game/save_file.gd src/game/save_file.gd.uid tests/test_save_file.gd tests/test_save_file.gd.uid && git commit -m "feat: write saves atomically"`

### Task 4: Saving from the board

**Files:**
- Create: `tests/test_board_save.gd`
- Modify: `src/game/board.gd`, `tests/board_test.gd`

**Interfaces:**
- Consumes: Task 2's `SaveGame.Puzzle`, `Snapshot`, `to_json`, `clusters_of`; Task 3's `SaveFile.DEFAULT_PATH`, `write_atomic`, `remove`; Task 1's `LogCapture`.
- Produces on `Board`:
  - `const IMAGE_ID := "test-gradient"`, `const ELAPSED_STEP_LIMIT := 0.25`. `IMAGE_SIZE`, `PIECE_COUNT`, `STYLE` and `SEED` stay as the fresh puzzle's identity.
  - `var save_path := SaveFile.DEFAULT_PATH`, set before the board enters the tree.
  - `var puzzle: SaveGame.Puzzle`, set at the top of `_ready` from `IMAGE_ID`, `IMAGE_SIZE`, `STYLE`, `PIECE_COUNT` and `SEED`. `_ready` generates the cut and the scatter from `puzzle`'s fields, and `cleanup()` passes `puzzle.cut_seed` where it passed `SEED`.
  - `var elapsed := 0.0`. `_process(delta)` first adds `minf(delta, ELAPSED_STEP_LIMIT)` when the board is focused and `not state.is_complete()`, then does its edge pan as before. A private `_focused := true` becomes false on `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED`, true on `NOTIFICATION_APPLICATION_FOCUS_IN` and `NOTIFICATION_APPLICATION_RESUMED`.
  - `func snapshot() -> SaveGame.Snapshot`: `puzzle`, `SaveGame.clusters_of(state)`, `loose_order` as the `piece_id` of each child of `pieces` in child order, `elapsed`, `tidy_count = _cleanup_count`. Reads the state, never node positions, so a running tidy is saved at its final offsets.
  - `func save_game() -> bool`: false when `state` is null (a board that never entered the tree). When `state.is_complete()`, `SaveFile.remove(save_path)` and true. Otherwise `SaveFile.write_atomic(save_path, SaveGame.to_json(snapshot()))`; on an error, `push_warning("Board: could not save to %s (error %d)" % [save_path, err])` and false; else true.
  - `_settle`: after its signals, `save_game()` when `result.locked`.
  - `_notification`: for `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_WM_GO_BACK_REQUEST`: `_finish_cleanup()`, the forced release with `releasing_for_system` as today, then `save_game()`.
- Produces on `tests/board_test.gd`: `const TEST_SAVE_PATH := "user://test_save/current.json"`; `make_board()` sets `board.save_path = TEST_SAVE_PATH` and calls `SaveFile.remove(TEST_SAVE_PATH)` before `root.add_child(board)`, so every board test starts fresh and never writes the real save.

- [ ] **Step 1: Point board tests at the test path.** Change `make_board()` as in the Interfaces block. Run `timeout 120 godot --headless --script tests/test_board_input.gd`. Expected: `0 failure(s)`.
- [ ] **Step 2: Write the failing test `tests/test_board_save.gd`** extending `BoardTest`. Members `_completed := 0` (connected to `puzzle_completed` after each `make_board()`), `capture`, and `_used := PackedInt32Array()`, every piece id a test has moved, so later tests pick untouched pieces. Helpers: `_saved() -> Dictionary`, `JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))`; `_cluster_of(saved: Dictionary, piece: int) -> Dictionary`, the saved cluster whose `pieces` holds `piece`; `_hold(node: PieceNode, target: Vector2) -> Vector2`, the first half of `_move_by_touch` (press at `_grab_point`, drag so the node's position becomes `target`), returning the finger's screen point; `_first_loose_singleton() -> PieceNode`, the lowest-id loose singleton not in `_used` with a `_grab_point`, appended to `_used`. `_init` awaits `process_frame`, `make_board()`, `_show_everything()`, runs these in order, frees the board, and `finish()`:
  - `_test_fresh_identity`: `board.puzzle.image_id == Board.IMAGE_ID`, `image_size == Board.IMAGE_SIZE`, `style == Board.STYLE`, `piece_count == Board.PIECE_COUNT`, `cut_seed == Board.SEED`; `board.elapsed == 0.0`; `not FileAccess.file_exists(TEST_SAVE_PATH)` ("starting does not save").
  - `_test_plain_drag_and_join_do_not_save`: `n := _first_loose_singleton()`, `_move_by_touch(n, n.position + Vector2(5, 5))`: `board.state.members(n.piece_id).size() == 1` and not locked (precondition), file absent. `pair := _loose_pair(_used)`, both appended to `_used`, joined with `_move_by_touch(board.node_for(pair.x), board.node_for(pair.y).position)`: they share a root, file absent.
  - `_test_lock_saves`: lock `n := _first_loose_singleton()` with `_move_by_touch(n, Vector2.ZERO)`: file exists; `_cluster_of(_saved(), n.piece_id).locked == true`; no temp file.
  - `_test_file_matches_snapshot`: `FileAccess.get_file_as_string(TEST_SAVE_PATH) == SaveGame.to_json(board.snapshot())`.
  - `_test_snapshot_contents`: `s := board.snapshot()`: `s.loose_order` equals the `piece_id`s of `board.pieces.get_children()` in order; the roots of `s.clusters` equal `board.state.roots()`; `s.tidy_count == board._cleanup_count`; `s.elapsed == board.elapsed`; `s.puzzle == board.puzzle`.
  - `_test_no_geometry_keys`: walk `_saved()` recursively and collect every Dictionary key: the set equals exactly `["clusters", "elapsed", "height", "image_id", "locked", "loose_order", "offset", "piece_count", "pieces", "puzzle", "root", "seed", "style", "tidy_count", "version", "width"]`; `FileAccess.get_file_as_bytes(TEST_SAVE_PATH).size() < 131072`.
  - `_test_identical_bytes`: `board.save_game()` twice, reading `FileAccess.get_file_as_bytes` after each: equal.
  - `_test_notification_saves(what: int, label: String)`, run for the four notifications: `SaveFile.remove(TEST_SAVE_PATH)`; `n := _first_loose_singleton()`, `_hold(n, n.position + Vector2(0, 40))`; `board._notification(what)`: `not _is_held(n)`, file exists, no temp file, `_cluster_of(_saved(), n.piece_id).offset` read as a `Vector2` `== board.state.offset_of(n.piece_id)` ("the save holds the forced drop"). Afterwards send `NOTIFICATION_APPLICATION_FOCUS_IN`.
  - `_test_tidy_does_not_save`: `SaveFile.remove(TEST_SAVE_PATH)`; `board.cleanup()`: file absent. `board.save_game()` while `board.is_tidying()`: for every loose root, its saved offset `== board.state.offset_of(root)` ("a save mid-tidy holds the final offsets"). `board._finish_cleanup()`.
  - `_test_elapsed_counts`: `e := board.elapsed`; `board._process(0.1)`: `is_equal_approx(board.elapsed, e + 0.1)`; `board._process(5.0)`: grows by exactly `Board.ELAPSED_STEP_LIMIT`; after `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`, `_process(0.1)` changes nothing; after `FOCUS_IN` it grows again; the same for `PAUSED` then `RESUMED`. Then `await process_frame` three times: `board.elapsed` grew ("it counts on real frames").
  - `_test_completion_deletes_save`: `board.save_game()`, file exists. `n := _first_loose_singleton()`; lock every other loose root in the state only (`board.state.move_cluster(root, Vector2.ZERO)`, `board.state.drop(root)`); `_move_by_touch(n, Vector2.ZERO)`: `_completed == 1`, file and temp file absent; `board._process(0.1)` leaves `elapsed` unchanged; `board.save_game() == true` and the file is still absent; `board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)` leaves it absent.
  - `_test_pause_completing_drop_leaves_no_save`: free the board, `make_board()`, `_show_everything()`, reconnect `_completed`, reset it and `_used`; `n := _first_loose_singleton()`, lock every other loose root in the state only, `board.save_game()` (file exists); `_hold(n, Vector2.ZERO)`; `board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)`: `board.state.is_complete()`, `_completed == 1`, file and temp file absent.
  - Around the whole run: `capture` attached after the first `make_board()`; before `finish()`, `capture.warnings.is_empty() and capture.errors.is_empty()`.
- [ ] **Step 3: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_board_save.gd`. Expected: an error that `puzzle` (or `save_game`) is not found on `Board`.
- [ ] **Step 4: Implement** the Interfaces block in `src/game/board.gd`.
- [ ] **Step 5: Run the board tests.** `godot --headless --import`, then `for t in test_board_save test_board_cleanup test_board_snapping test_board_input test_feedback test_hud; do timeout 120 godot --headless --script "tests/$t.gd" || echo "FAILED $t"; done`. Expected: `0 failure(s)` each and no `FAILED` line. Then `test ! -e ~/.local/share/godot/app_userdata/Pieceful/save/current.json || echo "a test wrote the real save"` prints nothing (no build before this task could write that file, so only a desktop run of the game since then can explain one).
- [ ] **Step 6: Commit.** `git add src/game/board.gd tests/board_test.gd tests/test_board_save.gd tests/test_board_save.gd.uid && git commit -m "feat: save the board on lock and on leaving"`

### Task 5: Resuming on start

**Files:**
- Create: `tests/test_board_resume.gd`
- Modify: `src/game/board.gd`, `tests/board_test.gd`, `docs/technical-notes.md`

**Interfaces:**
- Consumes: Task 2's `SaveGame.from_json`, `state_from`, `loose_order_valid`; Task 3's `SaveFile.read`, `remove`; Task 4's `Board.puzzle`, `save_path`, `elapsed`, `snapshot()`, `save_game()`, `IMAGE_ID`.
- Produces on `Board`:
  - `_ready`, before building any node, follows the spec's "Restoring": no file at `save_path` gives a fresh puzzle silently; otherwise `SaveGame.from_json(SaveFile.read(save_path))`, then the image check (`image_id == IMAGE_ID`, `image_size == IMAGE_SIZE`), then `cut` from the snapshot's `puzzle`, then `state = SaveGame.state_from(clusters, cut, PuzzleState.tolerance_for(width, height, cut.size()))`, rejected when `state.is_complete()` (which also covers the empty state), then `SaveGame.loose_order_valid`. The first failing stage calls a private `_discard_save(reason: String)`: one `push_warning("Board: discarding the save at %s: %s" % [save_path, reason])` and `SaveFile.remove(save_path)`; then `puzzle`, `cut`, `state` and the scatter come from the constants as in Task 4.
  - On success: `puzzle` is the saved one, `elapsed` and `_cleanup_count` the saved values. Nodes are built once, for the final `cut`: every node is set up as today and positioned at `state.offset_of(id)`; loose nodes are added to `pieces` in `loose_order`, locked ones to `locked_pieces` in ascending id. `_bounds` is `_base_bounds` merged with `cluster_home_rect(root)` moved by `state.offset_of(root)` for every loose root. The camera fits the board as on a fresh start. No signal is emitted.
- Produces on `tests/board_test.gd`: `make_board(fresh := true)`; only a fresh board removes `TEST_SAVE_PATH` first.

- [ ] **Step 1: Add `fresh := true` to `make_board()`.** Run `timeout 120 godot --headless --script tests/test_board_save.gd`. Expected: `0 failure(s)`.
- [ ] **Step 2: Write the failing test `tests/test_board_resume.gd`** extending `BoardTest`. Helpers: `_record() -> Dictionary` with `roots` (`state.roots()`), and per root `members`, `offset_of` and `is_locked`; `positions`, every node's `position` by id; `loose`, the `piece_id`s of `board.pieces` children in order; `locked_layer`, the sorted ids under `board.locked_pieces`; `elapsed`; `tidy_count`; `bounds` (`board._bounds`). A member `_fresh_offsets`, set to `Scatter.scatter(board.cut, Vector2(Board.IMAGE_SIZE), Board.LOOSE_MARGIN, Board.SEED)` right after the first `make_board()` in `_test_round_trip`, and a member `_good: Dictionary`, set in `_test_missing_file_starts_fresh`. `_init` awaits `process_frame`, runs these in order, frees the last board, and `finish()`:
  - `_test_round_trip`: `make_board()`, `_show_everything()`; join one loose pair, lock one loose singleton, lift and drop another loose singleton 30 px away (it moves to the top of the stack), `board.cleanup()` and land it (`board._finish_cleanup()`), then `board._process(0.2)` and `board._process(0.17)`. `a := _record()`, `board.save_game()`, `_text_a := FileAccess.get_file_as_string(TEST_SAVE_PATH)`. Free the board, `make_board(false)` with `capture` attached: no warnings or errors; `b := _record()`; `b.roots == a.roots` and, per root, members, offsets (with `==`) and locks equal; `b.positions == a.positions` (with `==`); `b.loose == a.loose`; `b.locked_layer == a.locked_layer`; `b.elapsed == a.elapsed`; `a.tidy_count == 1` and `b.tidy_count == 1`; `b.bounds.position.is_equal_approx(a.bounds.position)` and the same for `size`; `board.puzzle.piece_count == Board.PIECE_COUNT`; `not board.is_tidying()`.
  - `_test_resave_is_identical`: on the restored board, before any frame, `board.save_game()`: the file's text `== _text_a`.
  - `_test_plays_on`: on the same board, `_show_everything()`, lock another loose singleton by touch: it is locked, its node is under `locked_pieces`, and the file's cluster for it is locked; `board.cleanup()` makes `board._cleanup_count == 2`; `board._finish_cleanup()`.
  - `_test_tidy_mid_animation`: `board.cleanup()`; while `board.is_tidying()`, `board.save_game()` and record every root's `state.offset_of`. Free, `make_board(false)`: `not board.is_tidying()`; every node's `position` equals its recorded root offset ("restore lands a tidy at its final offsets").
  - `_test_other_identity`: `cut55 := CutGenerator.generate_cut(1536, 1024, 55, CutGenerator.STYLE_REGULAR, 7)` (54 pieces; check `cut55.size() == 54`); a `SaveGame.Snapshot` with puzzle `Board.IMAGE_ID`, `Board.IMAGE_SIZE`, `"regular"`, 55, cut seed 7, one loose singleton cluster per piece `i` (root `i`, offset `Vector2(-400 - 3 * i, -300)`), `loose_order` `0 ..< 54` reversed, `elapsed` 9.5, `tidy_count` 0; `SaveFile.write_atomic(TEST_SAVE_PATH, SaveGame.to_json(it))`. Free, `make_board(false)` with `capture`: no warnings; `board.cut.size() == 54`; `board.pieces.get_child_count() == 54`; `board.puzzle.piece_count == 55` and `cut_seed == 7`; each node's position equals its offset; the first child of `pieces` is piece 53; `board.elapsed == 9.5`. `board.save_game()`, then the file's `puzzle.piece_count == 55`.
  - `_test_missing_file_starts_fresh`: free, `SaveFile.remove(TEST_SAVE_PATH)`, `make_board(false)` with `capture`: no warnings or errors; `_is_fresh()`. Then `_good = SaveGame.to_dict(board.snapshot())`.
  - `_test_bad_file(label: String, text: String)`, run for each case below: free the board, `SaveFile.write_atomic(TEST_SAVE_PATH, text)`, attach a new `capture`, `make_board(false)`, remove it: `capture.warnings.size() == 1` and `capture.warnings[0].begins_with("Board: discarding the save at")`; `capture.errors.is_empty()`; `not FileAccess.file_exists(TEST_SAVE_PATH)`; `_is_fresh()`. `_is_fresh() -> bool`: `board.cut.size() == Board.PIECE_COUNT`, `board.pieces.get_child_count() == Board.PIECE_COUNT`, `board.locked_pieces.get_child_count() == 0`, `board.state.roots().size() == Board.PIECE_COUNT`, every node's `position == _fresh_offsets[id]`, `board.elapsed == 0.0`, `board._cleanup_count == 0`, `board.puzzle.cut_seed == Board.SEED`. Each case is a `duplicate(true)` of `_good` with one change, written with `JSON.stringify(case, "\t", true, true)`, except the four raw texts:
    - `"corrupt"`: `"{not json"`; `"empty"`: `""`; `"truncated"`: the first half of `JSON.stringify(_good, "\t", true, true)`; `"array"`: `"[]"`.
    - `"wrong version"`: `version` 2; `"missing key"`: `loose_order` erased; `"unknown style"`: `style` `"wild"`.
    - `"unknown image"`: `image_id` `"cats-01"`; `"wrong size"`: `width` 2048.
    - `"wrong count"`: `puzzle.piece_count` 54 (a valid 54-piece cut, 400 saved pieces).
    - `"piece in two clusters"`: `clusters[1].pieces` gets `clusters[0].pieces[0]` appended; `"piece in no cluster"`: the last cluster removed.
    - `"locked with an offset"`: `clusters[0].locked` true and its offset `[3.0, 0.0]`.
    - `"complete"`: every cluster locked with offset `[0.0, 0.0]` and `loose_order` `[]`.
    - `"bad draw order"`: `loose_order` with its first id appended again.
- [ ] **Step 3: Run it, expecting failure.** `timeout 120 godot --headless --script tests/test_board_resume.gd`. Expected: `_test_round_trip` fails (the restored board is a fresh scatter).
- [ ] **Step 4: Implement** the Interfaces block in `src/game/board.gd`.
- [ ] **Step 5: Run it again.** `godot --headless --import`, then `timeout 120 godot --headless --script tests/test_board_resume.gd`. Expected: `0 failure(s)`.
- [ ] **Step 6: Record the defaults.** In `docs/technical-notes.md`, after the "**default** The Godot theme is built by..." bullet, add: "**default** Saves: one puzzle in `user://save/current.json`, sorted JSON with tabs and full-precision floats, written to a `.tmp` file and renamed over the old one. It holds the image id, size, style, requested count and seed, every cluster's root, members, offset and lock, the loose draw order, elapsed seconds and the tidy counter, never geometry. The board saves after each lock and on pause, focus loss, close and back, deletes the save on completion, and on start regenerates the cut from the save; a bad save logs one warning, is deleted, and a fresh puzzle starts. The camera is not saved. Elapsed time counts while focused and not complete, at most 0.25 s per frame."
- [ ] **Step 7: Run every test.** `godot --headless --import`, then `for t in tests/test_*.gd; do timeout 120 godot --headless --script "$t" || echo "FAILED $t"; done`. Expected: `0 failure(s)` for each file and no `FAILED` line.
- [ ] **Step 8: Commit.** `git add src/game/board.gd tests/board_test.gd tests/test_board_resume.gd tests/test_board_resume.gd.uid docs/technical-notes.md && git commit -m "feat: resume the saved puzzle on start"`

---

## Owner checks

These need the phone or a person, so they are not task steps. Run them after Task 5.

1. **Desktop:** `godot --path . res://src/game/board.tscn`. Join a few pieces, lock two, tidy, close the window. Start again: the same board, with the camera fitted to the board. `cat ~/.local/share/godot/app_userdata/Pieceful/save/current.json` reads as plain JSON with no outlines.
2. **Phone, Nothing Phone (4a), swipe away:** lock some pieces, join a few, tidy, press home, swipe the app away from recents, reopen: the identical board, including the stacking of overlapping pieces.
3. **Phone, back button:** press Back to leave, reopen: the identical board. If it is not, run `adb logcat -s godot` while leaving and note which notifications arrive.
4. **Phone, held piece:** hold a piece, pull down the notification shade or press home, swipe the app away, reopen: the piece sits where it was dropped, and nothing played late.
5. **Phone, lock hitch:** with the frame-rate counter on and 400 pieces loose, lock pieces one after another: no visible stutter on the lock. If there is one, say so; the save on lock then moves off the frame.
6. **Phone, the file:** `adb shell run-as io.github.aaryash_shakya.pieceful cat files/save/current.json`: plain JSON; play a minute and read it again after leaving the app: `elapsed` grew by about a minute and did not count the time away.
