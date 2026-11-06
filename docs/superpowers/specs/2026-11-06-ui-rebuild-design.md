# UI rebuild design

Written 2026-11-06. Reference: `docs/prototype/ui-flow.html`, the owner-approved screen-by-screen design. Open it in a browser. "Flow board" shows every frame, "Try it" is clickable, and the Style button changes theme, mode, accent, type and roundness live.

## Intent

The owner approved a new look for the whole app and asked for it to be rebuilt in Godot. Version 1 and 2 work (cuts, board, snapping, slots, save, feedback) stays as it is. The screens around it change: how the app opens, how a picture and a cut are chosen, what sits over the board, what happens on pause and on finish, and a settings area that can change the look of the app.

Why: the old screens are one long setup page with a Settings button bolted on. The approved design is picture-led, puts one big action in the thumb zone on every screen, and keeps the board as large as possible.

## Goals

- Every screen in the reference exists in the app and behaves as in the reference: Home, Daily, Pictures, Collections store, Setup, Board, Slot stack fanned, Pause, Puzzle complete, Settings Look, Settings Play.
- The look is data, not code: theme, light/dark/auto, accent, corner roundness are settings that restyle every screen at once. Midnight table with Baloo 2 and Quicksand stays the default and stays exactly as `docs/visual-design.md` locks it.
- Same game, same saves. No change to cut output, save format or piece behaviour.
- One screen stack with Android back handling: Home is the root, back pops, back on Home quits.
- 400 pieces still hold the frame rate. New screens must not add per-frame work while the board runs.

## Non-goals

- Network code. The store shows its downloads disabled until the R2 hosting exists.
- Wild cuts. The daily ramp uses the Wild days' counts only as the nearest valid Irregular split until Wild exists (see Daily).
- Stats, best times, notifications, accounts.
- Backdrop blur. The reference uses blurred glass panels. Godot has no cheap equivalent on Mobile, so these are plain semi-opaque panels.

## Anti-goals

- Anything that costs frame rate on the board.
- Two copies of any colour or radius. Every screen reads tokens from one place.
- Rewriting working game code to suit the new UI.

## Constraints

- Rules in `AGENTS.md` apply: GDScript, Android only, pure cut generator untouched, tests are plain scripts, commit style, one slice per branch.
- Viewport stays 540 by 1200 portrait. The reference is 360 by 760, so reference pixels times 1.5 give Godot pixels.
- Safe area comes from `DisplayServer.get_display_safe_area`, replacing the fixed 56-unit top inset.
- Save version stays 4. Settings stay in `user://settings.cfg`, apart from the save, so Reset progress never touches them or the downloaded collections.

## Decisions

Made by the owner (approved design, scope answer):
- The reference is the target for layout, hierarchy and behaviour.
- Daily and Store are real screens with light logic: Daily works offline, Store downloads stay disabled.

Mine. The owner can overturn any of them:
- **Screen stack.** One root scene `AppShell` holds the current screen and a stack. Screens are Controls built in code like today's. The board is a screen too, so Home, Android back and "Save and exit" all go through the stack. `SetupScreen.open` and `Board.go_home` move behind it.
- **Look settings.** `Settings` gains `theme`, `mode` (auto, light, dark), `accent` (theme default or a hex colour) and `roundness` (0 to 250 percent, default 100) in slice 1. Slice 6 adds `ghost_strength` (5 to 60, default 20), `edge_strength` (30 to 100, default 100), `snap_effects` and `reduce_motion`. Old files load with defaults.
- **Palette becomes data.** Four themes from the reference (Midnight table, Orchard, Berry jam, Slate), each with a light and a dark set of the same eleven roles as `Palette` has today. `Palette` reads the current theme. Midnight table keeps today's exact values.
- **Theme build.** `UiTheme.build` takes the look and sets radii from roundness (base 8, 10, 9, 14, times the factor). Changing a setting rebuilds the theme and every open screen picks it up.
- **Floating nav** on Home, Pictures, Daily, Settings (four tabs). Hidden on Setup, Board, Store, Pause and Complete.
- **Daily.** Day counted in UTC. Seed is the UTC date as an integer, so everyone gets the same cut. Picture is picked from bundled collections by date. The ramp is open decision 10's default (Mon Regular 54, Tue Regular 96, Wed Irregular 150, Thu Wild 200, Fri Wild 250, Sat Wild 300, Sun Regular 400). Counts snap to the nearest valid split for the picture (decision 13's default) and the share card shows the real count. Until Wild exists, Wild days use Irregular and the screen says so. Ghost is always on. A finished daily is marked done for that date in `settings.cfg`.
- **Store.** A static list of catalog entries (name, count, size, preview pictures from bundled art). Download buttons are disabled with the note "Coming soon". One row can show the downloaded and the downloading look from the reference as design states only when a debug flag is set.
- **Effects.** Snap ring on join and lock, confetti and a 0.3 s board shake on finish, as `docs/visual-design.md` already specifies. Off when Reduce motion is on, and Reduce motion turns on by itself when the device asks. This pulls the effects the version 1 and 2 notes skipped into this slice of work.
- **Fonts.** The default pair is locked and ships. The reference also offers four more pairs. The owner skipped them, so the app ships only the locked pair.
- **Pause.** Opens from the board's pause button, saves the game, stops the clock, and shows the sheet from the reference. Android back on the board opens Pause.

Left to the builder: node structure of each screen, tween timings, the exact scatter of the floating pieces on Home, how the generated pictures are cropped for hero images, test layout.

## Screens and what is new

| Screen | New compared with today |
|---|---|
| Home | New. Resume hero with the picture, title, progress and Continue. Daily tile, New puzzle tile. |
| Daily | New. Today's picture, week ramp strip, share card line, Play. |
| Pictures | Replaces the picture strip. Collection tabs, staggered grid, "Cut this" action. |
| Store | New, disabled downloads. |
| Setup | Picture preview on top, bottom sheet with piece count, style tiles drawn with their own cut, ghost switch, Start. Existing slider steps, preview worker timing and seeds are reused. |
| Board | Same game. Floating pause, timer and progress, ghost, Tidy over the felt. Slot tray becomes the dock. Lifted piece and lit target slot are already in. |
| Pause | New sheet: time, Resume, Ghost, Sound, Vibration tiles, Restart, Save and exit. |
| Complete | Replaces the panel. Picture frame, large time, chips, Share, New puzzle, Home. Confetti. |
| Settings Look | New. Live preview, theme, mode, accent, roundness. |
| Settings Play | Replaces the settings sheet. Ghost and edge strength, sound, vibration, effects, reduce motion, reset progress, about. |

## Slices

Each is its own branch, plan, review and pull request. Each leaves the app working. Slice 1 goes first and alone. Then three tracks run in parallel in separate worktrees: A is slices 2 then 3, B is slices 4 then 5, C is slices 6, 7 and 8.

1. **Foundations.** Look settings, data-driven `Palette`, parameterised `UiTheme`, `AppShell` and the screen stack, safe area, floating nav control. The current setup screen runs inside the shell, unchanged.
2. **Home and Pictures.** Home hub, Pictures screen with collection tabs, picture choice carried into Setup.
3. **Setup.** The new layout.
4. **Board overlay and Pause.** Floating HUD, dock tray, Pause sheet, back button behaviour.
5. **Complete and effects.** New completion screen, confetti, shake, snap rings, reduce motion.
6. **Settings.** Look and Play screens, Reset progress, About.
7. **Daily.**
8. **Store.**
Extra font pairs are not planned. The owner skipped them on 2026-11-06.

## Testing

- Headless tests for everything that is logic: Look settings round trip and defaults, palette values for each theme and mode, radii from roundness, stack push and pop and back handling, Daily date to seed, picture and count, nearest valid count and the share line, effects off when reduce motion is on.
- Existing tests keep passing. Tests tied to the old setup layout are rewritten with their slice, not deleted.
- Screens get construction tests like the existing ones (nodes exist, buttons wired, no stray errors).
- The visual match is checked by running the app and comparing with the reference at 540 by 1200. Anything only a phone can settle goes in a status file as the earlier versions did.

## Open for the owner

- Everything in "Mine" above, on review.
