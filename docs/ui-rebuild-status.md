# UI rebuild status

Written 2026-11-06. The design is `docs/superpowers/specs/2026-11-06-ui-rebuild-design.md`, and the approved screens are in `docs/prototype/ui-flow.html`. This file records what has been built, what is next, and the calls made while building that the owner can overturn.

## Slice 1: foundations (built)

The app now starts in an `AppShell`, which is the main scene and holds a stack of screens (push, pop, replace). The look is data: theme, light/dark/auto, accent and corner roundness are settings in `user://settings.cfg`, and `Palette` and `UiTheme` read them. Four themes are in (Midnight table is the default and unchanged, then Orchard, Berry jam, Slate). This section describes slice 1 as it was built then. At the end of slice 1, no screen used the safe-area helper or tab bar; slice 2 mounts the tab bar on Home and Pictures. The setup screen and the board worked as before and swapped through the shell. All 43 headless test files passed then. Nothing has run on a phone.

Plan: `docs/superpowers/plans/2026-11-06-ui-foundations.md`.

## Slices

| Slice | State |
|---|---|
| 1. Foundations (settings, palette, theme, shell, safe area, nav bar) | Built |
| 2. Home and Pictures | Built (track A) |
| 3. Setup | Not started (track A, after 2) |
| 4. Board overlay and Pause | Not started (track B) |
| 5. Complete screen and effects | Not started (track B, after 4) |
| 6. Settings screens | Not started (track C) |
| 7. Daily | Not started (track C) |
| 8. Store | Not started (track C) |

Extra font pairs from the reference are not planned. The owner skipped them.

## Calls made while building slice 1

- Option tiles are 23 at 250 percent roundness, not 22 as the plan said. The plan's own formula (`roundi(9 * 250 / 100.0)`) gives 23.
- The safe-area "sides" test uses a safe rect 1020 wide. The plan's rect ended at 1040 and would have given a right inset of 20, not 10.
- The nav bar's icon tint lives on its own `NavButton` theme variation. Putting it on the shared `Option` variation would have tinted the picture thumbnails on the setup screen.
- `Settings.accent` is checked when the file is loaded, not again in `Palette`. A bad hex assigned in code would log a colour-parse error.
- Theme colour tables are plain arrays, because GDScript does not accept a packed array as a constant.
- `tests/test_setup_flow.gd` expects `app_shell.tscn` as the main scene now.
- `SetupScreen` and `Board` still handle their own Android back request. Screens added later use `AppShell.pop()`.

## Slice 2: Home and Pictures (built)

The app opens on Home. Home shows a Resume hero when a save exists, and a first-launch state when not. The Daily tile says "Coming soon". New puzzle opens Pictures.

Pictures has collection tabs, a two-column grid, one fixed Cut button that opens Setup on the chosen picture, and a disabled "More pictures" button.

A floating tab bar (`TabHost`) shows Home and Pictures as live tabs. Daily and Settings are disabled until their slices add a route. One `BoardLaunch` helper opens the board, and the board's Home button returns to Home. Setup opens on the picture chosen in Pictures. Nav icons are scaled 1.4, and disabled nav tabs are drawn quiet. `TapGuard` is shared by Setup and Pictures.

Android back is delivered from the root, where the tree refuses child changes, so `AppShell.pop()` decides synchronously whether there is a screen to pop and changes the tree deferred, like `present`. Back on Setup returns to Pictures, back on Pictures returns to Home, and back on Home quits.

The board and Home are root destinations: `BoardLaunch.launch` and `HomeScreen.open` use `AppShell.reset_to`, which frees every screen in the stack and leaves only the new one, so stale Pictures screens do not pile up as puzzles are started.

Nothing has run on a phone.

## Calls made while building slice 2

- Home and Pictures refer to each other, so one had to exist first. Home's New puzzle and Pick a picture were disabled until the Pictures screen existed, then Task 5 wired them through an `open_pictures` callback, which keeps a load-time cycle out. The test that Pictures opens by default sits with Pictures.
- The minimum touch target is 66 Godot px, which is 44 dp at the 1.5 scale. Controls are a little larger than the bare minimum. The plan's sentence on this was garbled.
- The branch started before PR #17 (touch fix in AppShell and Board). This branch started before PR #17 and must be rebased onto main after #17 merges. The AppShell conflict is two lines.
- When Setup opens with a picture chosen in Pictures, that picture wins over a saved game. Setup shows no resume card, because Resume lives on Home. The save file stays as it is until Start replaces it. A player who picks a picture can resume only from Home.
- Setup still judges the save when a picture is chosen. An unusable save is moved aside, as before. Otherwise Start would overwrite a save the game cannot use.

## What only a phone can settle

The nav bar and the safe-area insets have not been seen on a device. The first screens that mount them (slices 2 to 4) should be checked on the phone for the status bar and gesture bar clearance, the nav bar's thumb reach, and the icon tint in light and dark mode.

Slice 1:

- Android back on the board returns to Home (it returned to setup in slice 1), and the screen is never blank.

Slice 2 (Home and Pictures):

- Nav bar clearance above the gesture bar and the status bar.
- Thumb reach of the nav bar.
- Nav icon tint in light and dark mode.
- Home hero fade legibility at a large system font.
- Home hero text is anchored to the bottom of the hero and grows upward. Check it at real screen heights.
- Android back on Home, Pictures and Setup.
- Double tap on Continue.
- Pictures grid visual match to the pictures frame.
- Real-touch scroll versus tap on the Pictures grid.
- The desktop movie capture shows a 2x zoomed centre crop, so the layout has only been checked headlessly.

## Carry-over for later slices

- Slices 3 and 4 must stop setting their own `theme = UiTheme.build()` in `setup_screen.gd:158` and `hud.gd:39`, so `AppShell.apply_look()` reaches them. Slice 4's dock replaces `slot_tray.gd:193`, which uses the unscaled `UiTheme.OPTION_RADIUS`.
- Slice 6 must make `SettingsSheet` and `Feedback` read `Settings.current()` instead of loading their own copies, so a look edit cannot be overwritten by an open sheet saving stale look fields.

## Notes for tracks B and C

- `TabHost.routes` is where Daily and Settings attach. Each screen exposes a static `make_host(path, source, quit) -> TabHost`. Their nav buttons enable themselves when a route is added.
- Home reads `Palette` once, when it is built. A live look change (slice 6) needs Home and Pictures rebuilt, or a listener on `AppShell.look_applied`.
- The branch must be rebased onto main after PR #17 merges.
