# Slots design (version 2, slice 1)

Four sorting slots at the bottom of the board screen. Scope comes from `docs/version-plan.md` and `INTENT.md`. Decisions below marked "call" are mine, not the owner's.

## Behaviour

- A slot holds whole clusters as a stack. It shows a badge with the number of pieces, not clusters.
- Drop a held cluster with the finger over a slot: the cluster goes into that slot and leaves the board.
- Touch a non-empty slot: every cluster in it fans out under the finger and follows it. Only the whole stack comes out.
- Release with the finger on the same slot: the stack returns to it (the order is kept).
- Release anywhere else: the clusters spread in an even grid centred where the finger lifted. Each cluster is then dropped through the normal drop, so a cluster that lands on its place locks. The grid gap is the same clearance as Tidy (1.25 times the join tolerance), so spreading never joins clusters by accident.
- Pieces in a slot cannot join or lock. They are not drawn and cannot be picked.
- A system release (focus loss, pause, back) while a stack is held returns it to its slot. Call: this never scatters pieces by surprise.
- While a stack is held, extra fingers are ignored. Call: no pinch during a slot drag.
- Tidy ignores slotted clusters.
- Call: the slot rectangles are screen space, owned by the HUD, and handed to the board as `slot_rects`. The tray controls ignore the mouse; the board hit-tests them from raw touches, so there is one input path.

## State and save

- `PuzzleState` gets a per-root slot index (-1 none) and `slot_roots(slot)` in stack order. `_absorbable_roots` skips slotted clusters. A locked cluster can never be slotted.
- Saves bump to `SaveGame.VERSION` 3. A new key `slots` holds four arrays of cluster roots. Slotted pieces are left out of `loose_order`.
- A save whose `slots` name a locked cluster, a non-root, a duplicate, or other than 4 slots is set aside like any bad save.
- Old version 2 saves are set aside by the existing version check. Call: no migration, since v1 is not released.

## Visuals

- Slot panel: surface colour, 9 unit corner radius, accent border when it holds pieces. A small stack of up to three offset tiles shows it is full. A count badge in Baloo 2.
- Tray height 88, 12 gap, 24 bottom margin, four equal slots across the 540 wide viewport.

## Not in this slice

Ghost overlay, timer and completion screen, settings, collections.
