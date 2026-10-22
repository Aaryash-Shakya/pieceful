# Version plan

Pieceful ships in three versions. Each version is playable on its own and has a clear exit test. Work stays inside the current version. Features from a later version are not pulled forward without the owner's agreement.

See `INTENT.md` for what the project is for and `AGENTS.md` for architecture rules.

Assumptions the owner has not rejected: GDScript as the language, the sorting slots in version 2, and Wild pieces with interlocking edges.

## Version 1: Playable core

Version 1 is also the performance test for Godot. The first milestone is a spike, a throwaway test on the owner's real phone at the 400-piece maximum. The checks are proposed and still need the owner's confirmation. See `docs/engine-decision.md`.

- 60fps while dragging pieces and while pinch-zooming and panning.
- A snap sound that feels instant. If it does not, try an Oboe-based audio plugin before judging the engine.
- Clean piece edges, using 2D MSAA where needed.
- Pinch and pan that work reliably, through the Android gesture project setting or raw touch events.

If the first two cannot be fixed, the engine choice is reopened before anything else is built. The fallback is libGDX with Kotlin.

**Scope**

- Godot 4 project, Android export, and a repeatable way to install the APK on a phone.
- The cut generator and its tests. Build order: the tab-less grid first, then Regular, then Irregular. The tab-less grid is an internal development aid and is not shown to players.
- Setup screen with the piece slider from 12 to 400, snapping to valid rows-by-columns splits, and a live preview of the cut lines over the image.
- World camera with pinch-zoom and pan, and piece dragging with correct stacking order.
- Locking a piece or cluster when it is dropped on its correct board position.
- Clusters: two fitting pieces join permanently and move as one.
- Sound and vibration on joins (light) and on board locks (stronger).
- Cleanup button that packs loose pieces and clusters row by row around the board.
- Save and resume, covering loose piece positions, clusters, locked pieces and elapsed time.
- One bundled image collection.
- A frame-rate counter available in debug builds.

**Exit tests**

- 400 pieces (the maximum) hold 60fps while dragging and zooming on the owner's phone.
- The snap sound and vibration feel instant.
- Saving and resuming restores the board exactly.
- The generator tests pass: piece areas sum to the image area, every interior edge belongs to exactly two pieces, no piece is below the minimum area, and the same seed gives identical output twice.

## Version 2: Sorting and finishing

**Scope**

- The four slots: messy stack, fan-out under the finger, return when released near the slot, even grid spread when released away from it, and a count badge. Only the whole stack can be taken out.
- The ghost-image overlay toggle, on by default at 20% opacity.
- Four bundled collections and a collection picker.
- Timer, completion screen and the shareable result card (puzzle name, piece count, cut style, ghost overlay setting, time) through the Android share sheet.
- Settings for sound and vibration.
- Polish of haptics and audio.
- Slot contents added to the save file.

**Exit tests**

- A 300-piece puzzle can be sorted through the slots and finished.
- The result card shows the correct details.
- Slot contents survive save and resume.

## Version 3: Variety and reach

**Scope**

- The Wild cut: evenly spread points, Voronoi regions relaxed to avoid slivers, knobbed edges, and exactly the requested piece count.
- Daily puzzle with a fixed seed, chosen from bundled images only, with difficulty set by the weekday (see `INTENT.md`). The ghost image is always on.
- The collection store backed by Cloudflare R2: manifest, download with progress and retry, offline cache, and an offline-safe empty state. Resetting game progress never deletes downloaded collections.
- Stats history.
- GitHub release builds of the APK.

**Exit tests**

- A downloaded collection is still available after resetting game progress.
- Wild stays solvable at 400 pieces: no sliver pieces and no overly small pieces.
- The daily puzzle produces the identical cut on two different devices.

## Open items

- Confirm GDScript as the language.
- Confirm slots in version 2.
- Confirm Wild pieces have interlocking edges.
