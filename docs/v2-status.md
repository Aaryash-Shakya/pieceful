# Version 2 status

Written 2026-11-03. Every version 2 scope item is built and the headless suite passes. Nothing here has run on a phone yet; the checks that need one are at the end. Slice designs: `docs/superpowers/specs/2026-11-03-slots-design.md`.

## What exists

- **Slots.** Four slots in screen space at the bottom (`src/ui/slot_tray.gd`). Drop a held cluster over a slot and it goes in, hidden in `Board.stash`. Touch a full slot and the whole stack fans out under the finger (`SlotSpread.fan`). Release near the slot, or over any slot, and it goes back in. Release elsewhere and it spreads in an even grid (`SlotSpread.grid`), each cluster then dropped normally. Count badge shows pieces. `PuzzleState` holds slot membership; slotted clusters never join or lock.
- **Ghost overlay.** `Board.ghost_sprite`, 20% opacity, on by default, toggled by the Ghost button. It is part of the puzzle (`SaveGame.Puzzle.ghost`).
- **Timer and completion.** The clock shows in the top row. On the last lock the Hud shows a completion panel with name, piece count, cut style, ghost setting and time (`ResultCard`). Share and Home buttons.
- **Share.** `Share.send` calls the `GodotShare` plugin singleton if the build has one, otherwise copies the text to the clipboard and says so.
- **Settings.** `Settings` (user://settings.cfg, apart from the save) holds sound and vibration. `SettingsSheet` is opened from the Settings button on the setup screen. `Feedback` reads it on start.
- **Collections.** Four bundled generated collections and a chip picker on the setup screen (`CollectionLibrary`). Details in `docs/technical-notes.md`.
- **Polish.** A stash plays the join click and buzz (`Board.stashed`).
- **Save.** Version 4: slots (four stacks of roots, left out of `loose_order`) and `puzzle.ghost`. Older saves are set aside as `current.bad.json`.

## Decisions made while building (mine, not the owner's)

- Slots hit-tested by the board from raw touches; tray controls ignore the mouse.
- While a stack is held, other fingers are ignored. A pause or focus loss returns it to its slot. A stack released over a different slot joins that slot's stack.
- The ghost choice is saved with the puzzle and the card shows the setting at completion time.
- No save migration, since version 1 is unreleased.
- Chips for the collection picker (open decision 7 stays open).
- Spread grid cells are as large as the biggest cluster in the stack, so one big cluster makes a loose grid.

## Not done

- Completion confetti, board shake and the picture fade (`docs/visual-design.md`). Not in the version 2 scope.
- A real Android share sheet. Needs a plugin added to the export and a phone test; the plugin's method name `shareText(title, subject, text)` is from memory and unverified.
- The settings sheet uses Godot's default CheckBox look, not the project theme.
- Piece images for the three new collections are generated placeholders and some are garish (open decision 9).
- Sound and haptic polish beyond the stash click. No new sounds.

## What only the phone can settle

1. Slots: grab a piece, drop on a slot, take it out, spread. Does the tray clear the gesture bar and feel reachable? Is the fan readable?
2. A 300-piece puzzle sorted through the slots and finished (the version 2 exit test). Frame rate while a big stack is fanned.
3. Resume after swiping the app away with slots full.
4. The completion panel, then Share: does the clipboard note show? Does the plugin work if added?
5. Ghost toggle feel, and whether 20% reads on every picture.
6. Which new pictures to replace.
