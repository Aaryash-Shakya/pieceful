# Open decisions

Things that are not settled. For each one, the owner's answer is needed, and where Claude proposed a default, it is given so work can continue. Move an item to `INTENT.md` or the relevant doc once it is decided, and delete it from here.

## Needed before building

| # | Decision | Default if not answered | Why it matters |
|---|---|---|---|
| 1 | Confirm the spike checks as the first milestone of version 1 | Yes, as in `docs/engine-decision.md`. Version 1 was built on the real board, so the checks run on the finished version 1 build on the phone (see `docs/v1-status.md`) | They decide whether Godot is kept or replaced. |
| 2 | Minimum Android version | Android 10 (API 29), which is what the Mobile renderer gives. Android 8 (API 26) was the earlier default | Sets which devices can install the APK. The owner's Galaxy On7 Pro runs Android 6.0 (API 23), so it cannot install a Mobile build. Whether the Compatibility renderer lowers the minimum enough is not verified. |

## Needed before the first release

| # | Decision | Default if not answered | Why it matters |
|---|---|---|---|
| 3 | How release APKs are signed and stored | A release keystore kept outside the repo | Losing the key means users cannot update the app. |

## Product decisions still open

| # | Decision | Default if not answered | Why it matters |
|---|---|---|---|
| 4 | Slots in version 1 or version 2 | Version 2. Version 1 was built that way, and the bottom of the screen is kept free for the slot tray | Sorting is central to how the owner plays, so it may belong in version 1. |
| 5 | Wild pieces: interlocking edges or plain straight edges | Interlocking, as in the owner's reference screenshots | Changes the Wild generator. |
| 6 | Daily reminder notification | No notifications | Needs a plugin and, on newer Android, a permission prompt. Push notifications would need a server, which the project avoids. |
| 7 | How collections are organised on screen | A single library of collection cover cards, with not-yet-downloaded collections shown in the same grid and downloaded in place, replacing the separate store screen | The prototype uses chips and a separate store. The owner has not answered. Until then the setup screen uses chips, one per bundled collection. |
| 8 | Progress marks and best times per picture | None, so no stats | Needs a small local record of finished puzzles. Stats history is also listed in version 3. |
| 9 | Which images go in each collection | Not decided. Version 1 ships six generated abstract pictures as placeholders (`assets/collections/abstract/`). Replace or add pictures by editing the collection's `manifest.json` | Four generated placeholder collections now ship (abstract, geometry, landscape, pattern, six pictures each); the owner still has to choose the real pictures. The owner is still thinking about image sources. Only public domain, CC0, the owner's own and AI-generated images are allowed. |
| 10 | Daily puzzle: the exact ramp | Monday Regular 54, Tuesday Regular 96, Wednesday Irregular 150, Thursday Wild 200, Friday Wild 250, Saturday Wild 300, Sunday Regular 400 | The owner approved the idea of a weekday ramp. The styles and counts are Claude's. |
| 11 | Accessibility beyond reduced motion | Not planned | Colour-blind safety, text scaling and screen-reader support have not been discussed. |
| 12 | Licence for the owner's own images and sounds | CC BY 4.0 (reuse allowed with credit, the same idea as the code licence) | The MIT licence covers code only. Third-party images and fonts keep their own licences, recorded in the collection manifests. |
| 13 | Daily puzzle on a picture where that weekday's count is not a valid split | The daily picks only bundled pictures whose aspect ratio makes that weekday's count valid. If none fits, it uses the nearest valid count and shows the real count on the share card | On a square picture none of 54, 96, 150 and 300 is a valid Regular or Irregular split, so a daily on such a picture would get a different count from the ramp. The share card must not claim a count the puzzle does not have. |

## May change after the spike

- Whether pieces are drawn with `Polygon2D` and no baking (the rule in `AGENTS.md`) or with pre-baked piece sprites.
- Whether snap audio needs an Oboe-based plugin or a custom Godot build.
- Which Godot renderer to use: Compatibility (OpenGL, runs on old phones like the Galaxy On7 Pro, but has no 2D MSAA) or Mobile (Vulkan, has 2D MSAA, but old phones cannot run it). The spike should try both on the Nothing Phone (4a).
- Whether the share action uses a community plugin or a small custom plugin.
- Whether Godot stays at all. The fallback is libGDX with Kotlin. See `docs/engine-decision.md`.

## Settled while building version 1

See `docs/v1-status.md` for the reasons. The Mobile renderer is in use for now and the phone checks may change that. GDScript is confirmed. Slots stay in version 2. Fonts, sounds and the placeholder pictures are the project's own work or under the SIL Open Font License.

## Still to write

- The written design and implementation plans for version 3. Version 2 has one design for slots (`docs/superpowers/specs/2026-11-03-slots-design.md`) and `docs/v2-status.md`. Each version 1 slice has its own in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
