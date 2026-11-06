# UI rebuild status

Written 2026-11-06. The design is `docs/superpowers/specs/2026-11-06-ui-rebuild-design.md`, and the approved screens are in `docs/prototype/ui-flow.html`. This file records what has been built, what is next, and the calls made while building that the owner can overturn.

## Slice 1: foundations (built)

The app now starts in an `AppShell`, which is the main scene and holds a stack of screens (push, pop, replace). The look is data: theme, light/dark/auto, accent and corner roundness are settings in `user://settings.cfg`, and `Palette` and `UiTheme` read them. Four themes are in (Midnight table is the default and unchanged, then Orchard, Berry jam, Slate). A safe-area helper and a floating tab bar control are built and tested but no screen uses them yet. The setup screen and the board work as before and swap through the shell. All 43 headless test files pass and the app starts with no errors or warnings. Nothing has run on a phone.

Plan: `docs/superpowers/plans/2026-11-06-ui-foundations.md`.

## Slices

| Slice | State |
|---|---|
| 1. Foundations (settings, palette, theme, shell, safe area, nav bar) | Built |
| 2. Home and Pictures | Not started (track A) |
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

## What only a phone can settle

The nav bar and the safe-area insets have not been seen on a device. The first screens that mount them (slices 2 to 4) should be checked on the phone for the status bar and gesture bar clearance, the nav bar's thumb reach, and the icon tint in light and dark mode.

- Android back on the board returns to setup, and the screen is never blank.

## Carry-over for later slices

- Slice 2 must set the nav icons' import scale to about 1.4 (`svg/scale` in `assets/icons/*.svg.import`, currently 1.0). The reference's icon at 1.5 scale is about 33 px.
- Slices 3 and 4 must stop setting their own `theme = UiTheme.build()` in `setup_screen.gd:158` and `hud.gd:39`, so `AppShell.apply_look()` reaches them. Slice 4's dock replaces `slot_tray.gd:193`, which uses the unscaled `UiTheme.OPTION_RADIUS`.
- Slice 6 must make `SettingsSheet` and `Feedback` read `Settings.current()` instead of loading their own copies, so a look edit cannot be overwritten by an open sheet saving stale look fields.
