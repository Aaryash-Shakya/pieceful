# UI and cleanup: fifth slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes one slice of version 1 in `docs/version-plan.md`: "Cleanup button that packs loose pieces and clusters row by row around the board", plus the look it needs: the locked fonts, the full palette and a Godot theme. The previous slice is `docs/superpowers/specs/2026-11-03-feedback-design.md`.

## Intent

The board has 400 pieces scattered around it and no way to tidy them. `INTENT.md` says: "Loose pieces sit around the board. A cleanup button arranges them neatly, packed row by row." `docs/technical-notes.md` adds the prototype's rule: "The cleanup button packs loose pieces in shuffled order, row by row, in two bands, one above and one below the board, then animates them into place."

It is also the first button in the app, so it is where the locked look from `docs/visual-design.md` arrives in Godot: Baloo 2 and Quicksand, the Midnight table palette in light and dark, and chunky buttons that press down physically. The theme built here is the one the setup and completion screens will reuse.

## What the slice delivers

1. **Bundled fonts.** Baloo 2 and Quicksand, the variable fonts from the google/fonts repository (`ofl/baloo2/Baloo2[wght].ttf`, `ofl/quicksand/Quicksand[wght].ttf`), unmodified, saved as `assets/fonts/Baloo2-Variable.ttf` and `assets/fonts/Quicksand-Variable.ttf`, with each folder's `OFL.txt` saved as `assets/fonts/OFL-Baloo2.txt` and `assets/fonts/OFL-Quicksand.txt`. A licence note, `assets/fonts/LICENSE.md`, names both fonts, the SIL Open Font License 1.1, the google/fonts commit they came from, the source URLs and the sha256 of each `.ttf`. A test checks the recorded sums against the files. The export preset's `include_filter` becomes `assets/fonts/*.txt`, so the two licence texts ship inside the APK next to the fonts, as the OFL asks.
2. **The full palette.** `Palette` gains every role in `docs/visual-design.md`, each a static function taking `dark := is_dark()`: `page_background`, `surface`, `raised_surface`, `text`, `muted_text`, `lines`, `accent`, `text_on_accent`, `accent_shadow`, `felt`, `board`. The existing `felt`, `board`, `accent`, `outline` and `is_dark` keep their names and values.
3. **A theme built by a script.** `UiTheme` (`src/ui/ui_theme.gd`) builds a `Theme` for light or dark from the palette and the two fonts: Quicksand 600 for body text, Baloo 2 for buttons (700) and titles (800), chunky accent buttons, panels and sheets. Values are in "The theme" below.
4. **A screen-space HUD.** `Hud` (`src/ui/hud.gd`), a `CanvasLayer` child of the board scene, holds one button, "Tidy", at the top right, below the status bar and beside the frame-rate counter. It does not zoom or pan with the camera and leaves the bottom of the screen free for the version 2 slot tray.
5. **A pure cleanup layout.** `CleanupLayout` (`src/game/cleanup_layout.gd`) takes each loose cluster's bounding rectangle at home and returns one offset per cluster, packing them in shuffled order, row by row, in two bands around the board. No nodes. Rules in "The layout" below.
6. **Cleanup on the board.** `Board.cleanup()` lays out every loose cluster, writes the new offsets into `PuzzleState`, grows the camera's reachable bounds to cover the bands, and animates the clusters into place with one `Tween`. It never joins, locks or reorders anything.

## The layout

All lengths are image pixels. `cell` is the average cell size, `sqrt(width * height / piece_count)`, about 63 px at 400 pieces on the 1536 by 1024 test image.

- **Input:** one `Rect2` per loose cluster, the union of its members' outline bounds at home (offset zero), plus the board size, `cell`, the cut seed and a press counter.
- **Order:** a Fisher-Yates shuffle with a `SeededRng` seeded from `hash2(hash2(seed, -3), counter)`. Stream -3 is new: the cut's lattice uses -1 and the scatter -2. The board's counter starts at 0 and goes up by one on every cleanup that moves something, so each press gives a fresh order and the same game gives the same sequence of orders.
- **Two bands:** each item's area is `(w + gap) * (h + gap)`. The top band takes the shortest prefix of the shuffled order whose area reaches half the total; the bottom band takes the rest.
- **Rows:** each band is filled row by row, left to right, in shuffled order. An item starts a new row when the current row is not empty and adding a gap and the item would make it wider than the band width. Each row is centred on the board's centre line, and each item is centred vertically in its row.
- **Growing outward:** in both bands row 0 is the one nearest the board, and each later row sits one gap further out. A band that runs out of room simply grows away from the board.
- **Spacing:** `gap = max(0.14 * cell, 1.25 * tolerance)` between items and between rows, where `tolerance` is the join tolerance the board passes in; `board_gap = 0.7 * cell` between the board edge and row 0; band width `1.45 * board width`. The fractions are the prototype's values. Since the join tolerance is 0.22 cell, the tolerance term wins at every piece count, so the gap is about 0.28 cell. An item wider than the band sits alone in its row and overhangs both sides equally.
- **Output:** one offset per input, `placed.position - home.position`, and the extent, the union of every placed rectangle (`Rect2()` when there is no input).

Since items never share space and a gap separates every pair, no two clusters touch or overlap, and every cluster ends fully outside the board by at least `board_gap`. Because `board_gap` (0.7 cell) is larger than the lock tolerance (0.22 cell), a tidied cluster is never within reach of a lock. It is never within reach of a join either. Two neighbouring pieces have home rectangles that touch, so if their clusters' placed rectangles are at least `gap` apart along one axis, their offsets differ by at least `gap` along that axis. That is 1.25 times the join tolerance, so lifting and dropping any tidied cluster where it lies joins nothing. This holds for every style, including the tab-less grid, and does not rely on tabs making the rectangles overlap.

## The board

- **What moves:** every root in `state.roots()` that is not locked. Locked pieces and their layer are never touched. A cluster keeps its shape because its members share one offset.
- **Zero loose clusters:** `cleanup()` does nothing, not even counting the press.
- **While a cluster is held:** `cleanup()` does nothing. A phone can reach this: hold Tidy down, grab a piece with a second finger, then release Tidy. Its `pressed` fires on release while the piece is held, and the guard ignores it.
- **State first, then nodes:** the new offsets go into `PuzzleState` with `move_cluster` when the press happens. The nodes then animate from where they were to the offsets in the state with one `tween_method` over 0.4 s (`CLEANUP_DURATION`, ease-out cubic). When the tween ends, every member node is set to exactly `state.offset_of(root)`, so state and nodes agree to the bit.
- **Touch during the animation:** the animation completes instantly on the next finger press, before the press is handled, so the press acts on the pieces at their final places. Dragging never waits.
- **Pause during the animation:** focus loss and app pause also complete it instantly, so a later save on pause reads a board whose nodes match the state.
- **A second press during the animation:** completes the first instantly, then runs a new cleanup from there with the next counter.
- **Reachable bounds:** the camera centre is clamped to `_bounds`, today the image grown by `LOOSE_MARGIN` (768 px). At 400 pieces the bands reach about 900 px beyond the board's top and bottom edges, past that margin. After each cleanup, `_bounds` becomes the base bounds merged with the layout's extent, and the camera position is clamped again. Since the camera centre can reach every point of the extent, every tidied cluster can be brought under the finger. The bounds are recomputed from the base on each cleanup, so they can also shrink back as pieces lock.
- **The camera does not move.** The player keeps the view they had.

## The theme

Units are viewport units. The viewport is 540 wide and `canvas_items` stretch maps it onto the phone, so one unit is about 0.76 dp on the 412 dp wide Nothing Phone (4a).

| Item | Value |
|---|---|
| Default font | Quicksand at weight 600 (`FontVariation`), size 20, colour `text` |
| Label | colour `text` |
| `Title` (Label variation) | Baloo 2 at 800, size 28, colour `text` |
| Button font | Baloo 2 at 700, size 22, colour `text_on_accent` in every state |
| Button normal | face `accent`, a solid 5 px bottom band in `accent_shadow`, radius 8, content margins 20 left and right, 8 top, 13 bottom |
| Button pressed | the face moves down 4 px and the band shrinks to 1 px; content margins 12 top, 9 bottom, so the text moves with the face and the button's size does not change |
| Button hover | same as normal (touch has no hover); hover pressed is the same as pressed |
| Button focus | empty (no focus ring on touch) |
| `PanelContainer` | `surface`, 1 px `lines` border, radius 10, content margin 12 |
| `Sheet` (PanelContainer variation) | `surface`, 1 px `lines` border, radius 14, content margin 20 |

The pressed face moves down by giving the pressed `StyleBoxFlat` a top expand margin of -4, which shrinks its drawn rectangle from the top while the bottom stays where the shadow ended. The bottom of the shadow therefore stays still, like a key pressed into its socket, which is the prototype's `translateY(3px)` with its shadow shrinking from 4 px to 1 px, scaled to these units.

## The HUD

- A `CanvasLayer` on layer 10 (the frame-rate counter is on 100). Its child is one full-screen `Control` with `mouse_filter` set to ignore, carrying the theme from `UiTheme.build()`, so touches outside the button go straight to the board.
- The button reads "Tidy", is 120 by 64 units (about 48 dp tall, a comfortable touch target), and sits 16 units from the right edge and 56 units from the top, the frame-rate counter's status-bar clearance (`FpsCounter.MARGIN_TOP`). The counter sits at the top left, so the two never overlap.
- The button's `mouse_filter` is stop, so a touch on it never reaches the board's `_unhandled_input`, never starts a pan, and never completes an animation.
- The HUD finds the board through an exported `board: Board` field set to `..` in `board.tscn`, as `Feedback` does, and connects the button's `pressed` to `board.cleanup`.

## Goals

- One press packs every loose cluster into two tidy bands, with nothing touching, nothing on the board and nothing out of the camera's reach.
- The same game gives the same sequence of tidy layouts; each press gives a different one.
- State and nodes agree exactly whenever no animation is running, and a touch never waits for an animation.
- Locked pieces, cluster membership and lock state are never changed by cleanup.
- The button and every later screen use the locked fonts, palette and radii in both light and dark.
- Dragging stays at 60 frames per second: the HUD does nothing per frame, and the cleanup tween runs only for 0.4 s after a press.

## Non-goals for this slice

- The setup screen, slots, the completion screen, the settings screen, the ghost image, effects (snap ring, confetti, shake) and saving.
- Following a light or dark change while the app runs. The theme is built once when the HUD starts.
- Reduced motion. The duration is a named constant so a later setting can set it to zero.
- A sound or vibration for cleanup, a toast ("Loose pieces tidied" in the prototype), or a fit-to-content camera move.
- A disabled button style. No control is disabled yet.

## Anti-goals

- Any font, colour or radius other than the locked ones in `docs/visual-design.md`.
- A touch on the button that also moves the camera or a piece.
- A cleanup that joins, locks or splits a cluster, or leaves a node at a different place from its state once the animation has ended.
- Per-piece tweens or per-frame work when nothing is animating.
- Fonts that are not under the SIL Open Font License, or font files modified from the upstream release.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies or plugins. The only network use is downloading the two fonts once at build time; the app makes no network call.
- Randomness comes from `SeededRng`, never the engine's random functions.
- Tests are plain headless scripts extending `BaseTest` or `BoardTest`, run with `godot --headless --script tests/<name>.gd`.
- Match the style of the surrounding code. Keep comments sparse and explain why.

## Decisions the owner made

- Cleanup packs loose pieces and clusters row by row around the board (`INTENT.md`, `docs/version-plan.md`), in shuffled order, in two bands above and below the board, animated into place (`docs/technical-notes.md`, from the prototype).
- Midnight table palette, light and dark following the device; Baloo 2 for titles, numbers and buttons; Quicksand at 600 for body; radii about 8 px for buttons, 10 px for panels, 14 px for sheets; chunky buttons that press down with a solid shadow that shrinks (`docs/visual-design.md`).
- The slot tray and other UI live in screen space and do not zoom (`AGENTS.md` rule 9). Slots are version 2 and sit at the bottom of the screen (`INTENT.md`).

## Calls made by Claude, which the owner has not confirmed

The orchestrator was delegated these decisions by the owner. Each one below is Claude's, or the orchestrator's where marked.

- **Font sources and files** (orchestrator: google/fonts, variable fonts, `curl`). Claude: the download is pinned to one google/fonts commit, recorded in the licence note; the files are renamed without brackets so their resource paths need no escaping; the contents are unmodified. The OFL texts are exported into the APK through the preset's include filter, because Godot exports only resources by default.
- **A theme built by a script, not a `.tres` file.** One function makes both modes from `Palette`, so the colours cannot drift from the palette, and a test can read every value. It is applied on the HUD's root control rather than as the project theme, because a project theme needs a saved resource; later screens apply the same `UiTheme.build()`.
- **Sizes.** Body 20, button 22, title 28; button 120 by 64. The prototype's sizes were CSS pixels on a phone about 390 wide; these are viewport units on a 540-wide viewport (about 1.3 units per CSS pixel), which puts the text at about the prototype's 15, 16 and 20 px and keeps the button a comfortable touch target.
- **Weights.** Buttons 700 and titles 800, as in the prototype's CSS. Body 600 as locked.
- **Radii in viewport units.** 8, 10 and 14 units, the locked numbers, read in the app's own units. That is slightly tighter on the phone than the prototype's CSS pixels; the owner checks it.
- **How the button presses.** A 5 px bottom band in the accent-shadow colour that becomes 1 px, with the face moving down 4 px through a negative top expand margin. `StyleBoxFlat` has one border colour, so the band is the bottom border and no other border is drawn.
- **Hover equals normal, focus is empty.** A phone has no hover, and a focus ring would stay on the button after every tap.
- **Label "Tidy", top right.** The prototype called it "Tidy loose pieces". A word is clearer than an icon without an icon set, and the top right keeps the bottom free for slots and the top left for the frame-rate counter.
- **Row 0 nearest the board.** The prototype filled its top band from the outside in, so a short last row sat against the board. Filling from the board outward keeps the bands tight against the board and lets them grow outward, as the brief asks.
- **Shuffle seed.** The cut seed and a press counter, on a new stream (-3). The counter is not saved; after a resume the next press starts from 0 again, which only changes which shuffle the player sees.
- **State first, then animate.** The state holds the final offsets from the press, so a save at any moment stores the tidy layout.
- **A touch completes the animation instantly** rather than waiting for it, because `INTENT.md` puts responsiveness first.
- **Ignored while held.** Moving a held cluster out from under its finger would break the board's rule that a held cluster stays under its finger.
- **Bounds from the base each time.** The bounds can shrink after a later cleanup with fewer loose pieces; the camera is clamped again at once, which may move it a little if it was outside the new bounds.
- **One tween for all clusters.** A single `tween_method` steps every moved cluster's nodes, so members move together and only one tweener exists.
- **The camera stays put.** The prototype fitted the camera to the tidied pieces. Moving the view without asking can disorient; if the owner wants the fit, it is a small follow-up.
- **No sound, haptic or toast** for cleanup, since none is specified.

## Left to the builder

- Private helper and field names inside the interfaces the plan fixes.
- Whether the HUD's button is anchored with presets or explicit offsets, as long as its rectangle is the one the plan's test checks.

## What happens if it does not look or feel right

The owner checks the button and the tidy on the phone (the plan's "Owner checks"). If the button is too small, too large or crowded, only the HUD constants change. If the press does not read as physical, only the button's depth and travel change. If the bands feel too loose or too tight, only the three layout fractions change. If the touch on the button leaks to the board on a real phone, the HUD gains a hit-rectangle check the board consults before handling a press.
