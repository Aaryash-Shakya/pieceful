# Snapping: third slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes only the snapping slice of version 1 in `docs/version-plan.md`: "Locking a piece or cluster when it is dropped on its correct board position" and "Clusters: two fitting pieces join permanently and move as one". The previous slices are `docs/superpowers/specs/2026-10-22-board-and-piece-movement-design.md` and `docs/superpowers/specs/2026-11-02-cut-styles-design.md`.

## Intent

The board can cut a picture into real pieces and move them, but nothing fits together yet. This slice makes the puzzle a puzzle: a piece dropped beside its true neighbour joins it with no gap and the two move as one from then on, and a piece or cluster dropped on its place in the picture locks there for good. When every piece is locked, the puzzle is done.

The rules live in a small state object with no nodes in it, so they can be tested headless and so the save slice can write and restore the state exactly. The state holds which pieces are joined, where each cluster sits and which clusters are locked. It never holds geometry: the cut is regenerated from the seed (`AGENTS.md` rule 3).

A snap must feel good in the hand (`INTENT.md`). This slice makes the snap exact and instant. Sound, vibration and the snap ring come later and hook into the signals this slice adds.

## What the slice delivers

1. **A puzzle state.** `PuzzleState` in `src/game/puzzle_state.gd`, a `RefCounted` with no node or scene dependency. Every piece belongs to one cluster, kept with union-find over piece ids. All pieces of a cluster share one offset from their home position, which is exactly the `position` of each piece node. A cluster is loose or locked. A locked cluster has offset exactly `Vector2.ZERO` and never moves again.
2. **Tolerance.** `PuzzleState.tolerance_for(width, height, piece_count)` is `max(10, 0.22 * sqrt(width * height / piece_count))` in image pixels, from the cut's actual piece count. On the 1536 by 1024 board at 400 pieces it is about 13.8 pixels.
3. **Lock on drop.** A dropped cluster whose offset is within the tolerance of zero snaps to zero and locks.
4. **Join on drop.** Otherwise, every loose cluster that has a piece neighbouring (in the solved picture, from `CutPiece.neighbours`) a piece of the dropped cluster, and whose offset is within the tolerance of the dropped cluster's offset, joins it. A cluster that joins can bring in its own aligned neighbours in the same drop. The merged cluster snaps to one offset exactly, so the pieces fit with no gap. If that offset is within the tolerance of zero, the merged cluster locks. Joins are permanent.
5. **Dragging a cluster.** Picking up any piece of a loose cluster lifts the whole cluster: every piece shows the lift shadow and the cluster comes to the top of the loose pieces, keeping its pieces' order. The finger-following, two-finger pan and zoom while holding, and edge pan behaviours all move the cluster's shared offset.
6. **Locked pieces.** They move to their own layer under the loose pieces. They are never picked up and never hit-tested for dragging, so a touch on a locked piece with no loose piece over it pans the camera.
7. **Signals on the board**, for the next slice (sound and vibration) to hook into. Nothing listens yet:
   - `pieces_joined(cluster_root: int, piece_count: int)` after a drop that joined clusters.
   - `cluster_locked(cluster_root: int, piece_count: int)` after a drop that locked a cluster.
   - `puzzle_completed()` once, when the last loose piece locks.
8. **Tests.** The state headless, and the board through injected touches.

## Goals

- A piece dropped within the tolerance of its true neighbour's offset joins it, and the two nodes' positions are then identical, not merely close.
- A piece or cluster dropped within the tolerance of home has position exactly `Vector2.ZERO` afterwards and cannot be picked up again.
- Dragging any piece of a cluster moves every piece of it by the same amount, through every input path the board already has.
- The same sequence of moves and drops gives the same clusters, roots, offsets and locked flags every time.
- 400 pieces still hold 60 frames per second on the Nothing Phone (4a) while dragging a single piece and while dragging a large cluster. A drag event moves at most 400 nodes and allocates nothing.

## Non-goals for this slice

- Sound, vibration, the snap ring, confetti and the board shake (`docs/visual-design.md` effects are out of version 1 scope apart from the lift shadow).
- Saving and resuming, and the save after each lock (`AGENTS.md` rule 10). That is the save slice; this slice only makes the state saveable.
- The cleanup button, the setup screen, slots and the completion screen.
- A cached single image of the locked pieces (see "What happens if it is too slow").
- Any change to the cut generator or to `Scatter`.

## Anti-goals

- Storing piece outlines, bounds or any other geometry in the state.
- Checking joins or locks while dragging. They are checked on drop only (`docs/technical-notes.md`).
- A cluster whose pieces sit at slightly different offsets. Every piece of a cluster has the cluster's one offset, so joined pieces never show a seam.
- Moving locked pieces for any reason.
- Rotation of any kind.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- `PuzzleState` depends only on `CutPiece` (for ids and neighbours) and plain Godot value types. No nodes, no scenes, no engine random.
- Pieces never rotate. A piece node's `position` is its cluster's offset and nothing else.
- Clusters use union-find (`AGENTS.md` rule 8). A cluster moves and hit-tests as one body, joins are permanent, and a cluster that reaches its board position locks.
- Pieces stay `Polygon2D` with `Geometry2D.is_point_in_polygon` hit-tests (`AGENTS.md` rule 6).
- Tests are plain headless scripts extending `BaseTest`, run with `godot --headless --script tests/<name>.gd`.
- Match the style of the surrounding code. Keep comments sparse and explain why.

## Decisions the owner made

- Two pieces that fit join permanently into a cluster that moves as one. A piece or cluster dropped on its correct board position locks (`INTENT.md`).
- Clusters use union-find, joins are permanent, and a cluster that reaches its board position locks (`AGENTS.md` rule 8).
- Never store piece geometry (`AGENTS.md` rule 3). Save on app pause and after each lock (`AGENTS.md` rule 10), in the save slice.
- From the prototype (`docs/technical-notes.md`): all pieces in a cluster share one offset; the tolerance is about 22% of the average cell size with a minimum of 10 image pixels; joins are checked on drop.
- Effects other than the lift shadow are out of version 1 scope (`docs/visual-design.md`, `docs/version-plan.md`).

## Calls made by Claude, which the owner has not confirmed

The orchestrator was delegated these decisions by the owner. Each one is Claude's.

- **Average cell size** is `sqrt(width * height / piece_count)` with the cut's actual piece count, as in the prototype. "Within the tolerance" means a distance of at most the tolerance (`<=`); the prototype used strictly less, which makes no difference a finger can feel.
- **Lock before join.** A drop first checks the lock. A cluster dropped within the tolerance of home locks even if a loose neighbour is also aligned with it; that neighbour locks when it is dropped home itself. This is the prototype's order, and it means a piece dropped on its place always locks.
- **Join-then-lock is a guard.** Because a loose cluster can only come to rest after a drop, and any drop near home locks, no loose cluster ever rests within the tolerance of home in normal play, so a join cannot produce a cluster near zero. The rule is kept anyway, so a restored save or a later feature that moves clusters cannot leave a loose cluster sitting on its place.
- **Who moves on a join.** Every candidate is compared with the dropped cluster's offset as it was dropped, and candidates are found by spreading out from the dropped cluster through neighbours until no more join, so the result does not depend on the order neighbours are listed in. The merged cluster then sits at a new offset, so the spread repeats from it, comparing candidates with that new offset, until nothing more joins; a near fit is never left apart. On the first pass the merged cluster takes the offset of the largest cluster that joined (ties go to the lowest root id). On every later pass the cluster merged so far counts as a candidate too, so it keeps its place unless a bigger cluster joins (ties again to the lowest root id). The dropped cluster therefore always moves onto what it was dropped against, and a big cluster on the table never jumps to meet a small one. The prototype instead let the last cluster joined win, which depends on scan order.
- **Union-find root.** After a join, the root is the root of the largest cluster involved, the dropped one included, with ties to the lowest root id. Roots are piece ids, so they are stable integers the save slice can write.
- **Locked clusters stay separate.** Locked clusters are never joined to anything, loose or locked. Joining them would change nothing on screen. Completion is "every piece locked", counted as locked pieces.
- **Every release is a drop.** A finger lifting, a touch the system cancels, and the app losing focus or pausing all release the held cluster where it is and then apply the lock and join rules. Otherwise a cancelled drag could leave a loose cluster resting on its place, which the save slice would then write.
- **Signal order.** One drop emits at most `pieces_joined`, then `cluster_locked`, then `puzzle_completed`, in that order and after the nodes have been moved. A join-then-lock emits both of the first two. The prototype played only the lock sound in that case; the sound slice decides which feedback to play, and has the facts to do it.
- **The merged cluster comes to the top** of the loose pieces after a join, keeping its pieces' order, as in the prototype, where the merged cluster takes the dropped cluster's place in the draw order.
- **Locked layer.** The board gets a `LockedPieces` `Node2D` added before `Pieces`, so it draws below. A locking cluster's nodes are moved into it. Hit-testing still walks only `Pieces`, so locked pieces are excluded with no extra check, and the layer is the natural place for the cached image if it is ever needed.
- **Lift shadow for a cluster.** A lifted piece is drawn one z level above the board and the other pieces (`PieceNode.HELD_Z_INDEX`, 1), and its shadow one level below its piece. Every shadow of a lifted cluster then draws under every body of that cluster, so a later piece's shadow never darkens an earlier neighbour in the same cluster.
- **No grab fallback.** The prototype picked the nearest piece centre within 11 screen pixels when a touch hit no piece. This slice keeps the exact polygon hit-test only. If tiny pieces at low zoom prove hard to pick up on the phone, that is a separate change.
- **Snaps are instant.** The dropped cluster jumps to its snapped offset in the same frame. Easing it there is an effect, and effects are out of scope.
- **What the save slice gets.** `roots()`, `members(piece)`, `offset_of(piece)` and `is_locked(piece)` describe the whole state. The save slice adds the restore path. Offsets are kept as the board's own single-precision `Vector2` values; how they are rounded in the save file is the save slice's call.

## Left to the builder

- Private helper and field names, and how union-find stores its arrays, inside the interfaces the plan fixes.
- How the tests find a screen point over a given piece, as long as each board test file finishes in under 30 seconds on the desktop.

## What happens if it is too slow

`docs/technical-notes.md` says the prototype painted locked pieces into one cached layer. In Godot each locked piece is still three canvas items, but it no longer moves, so it may cost little. This slice does not build the cache. The phone check measures 400 pieces with about half of them locked; if that drops below 60 frames per second where the all-loose board held, the follow-up is to draw `LockedPieces` into one cached texture (a `SubViewport` rendered once per lock, or a `CanvasGroup`), measured before and after. If dragging a large cluster is the slow part, the follow-up is to move the cluster's nodes under one temporary parent while it is held, so a drag event changes one transform instead of up to 400. Record the results in `docs/engine-decision.md`. Pre-baked sprites change an architecture rule and need the owner's decision.
