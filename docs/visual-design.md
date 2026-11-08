# Visual design

These choices were made by the owner. They are locked in as the defaults for the real app. Change them only if the owner asks.

## Choices (Workshop, approved 2026-11-08)

On 2026-11-08 the owner replaced Midnight table with the Workshop look and its fonts. The approved mockup of every screen and the app icon is the "Pieceful workshop edition" artifact, built from the owner's reference, the Behance project "Jigsaw Puzzle Game - Mobile UI Design" (gallery 184555083). Its coins, gems, store purchases and achievements are left out, because Pieceful is free with no ads or purchases.

- **Colour theme:** Workshop. A warm, tactile casual-game look: a rust table, chocolate panels with an orange rim, cream text, chunky green buttons, sun-yellow highlights.
- **Mode:** Workshop is one world and looks the same in light and dark mode. Midnight table and the other themes keep their light and dark sets.
- **Accent:** green, the go colour. Sun yellow `#ffd21f` is used for the Home logo.
- **Fonts:** Laila Bold for titles and numbers, Laila SemiBold for buttons, and Monda (weight 500) for body text. Both are Google Fonts under the SIL Open Font License, bundled in the APK. They replace Baloo 2 and Quicksand.
- **Shape:** corner radii as before (8 px buttons, 10 px panels, 9 px option tiles, 14 px sheets). Panels and sheets have a 3 px rim.
- **App icon:** an orange piece with a chocolate edge on a rust square. Sources are `assets/app_icon/*.svg`; `tools/build_app_icon.sh` renders the Android launcher PNGs.

## Workshop palette

| Role | Value |
|---|---|
| Page background (rust table) | `#b8420f` |
| Surface (chocolate panel) | `#43160a` |
| Raised surface | `#7a3418` |
| Text (cream) | `#fff3dc` |
| Muted text | `#f3cfa3` |
| Lines (orange rim) | `#d27a2a` |
| Accent (green) | `#4cc417` |
| Text on accent | `#ffffff` |
| Accent shadow | `#2c8209` |
| Table felt | `#43160a` |
| Board | `#5e2410` |

The mockup also shows peach paper panels, wooden picture frames and ribbon titles. The screens still to be rebuilt (Setup, board overlay, Pause, Complete, Settings, Daily) should follow the mockup's layout with these tokens.

## Previous choices (Midnight table)

Midnight table stays available as a theme. Its fonts were Baloo 2 and Quicksand, now removed.

## Midnight table palette

| Role | Light | Dark |
|---|---|---|
| Page background | `#e7e9f0` | `#0b1020` |
| Surface | `#f6f7fb` | `#131a2e` |
| Raised surface | `#dbdfea` | `#1c2540` |
| Text | `#141b2d` | `#e9edf7` |
| Muted text | `#566079` | `#8d98b5` |
| Lines | `#c9cfdd` | `#27314f` |
| Accent | `#e2a41f` | `#ffc857` |
| Text on accent | `#2a1d00` | `#2a1d00` |
| Accent shadow | `#a87612` | `#b58712` |
| Table felt | `#223a63` | `#14264a` |
| Board | `#2c4878` | `#1c3463` |

The felt and board are used behind the puzzle in both modes. Light mode keeps the dark navy table.

## Effects defaults

- Snap ring on a join (light) and on a lock (larger), in the accent colour.
- Lift shadow under held pieces.
- Confetti and a short shake of the board (about 0.3 seconds, board only, not the interface) when a puzzle is finished.
- Subtle grain on the felt.
- Ghost image is on by default, at 20% opacity.
- Piece edges at 100% strength: a dark outline about 2.3 px wide at 80% opacity around every piece, so cut lines stay clear.
- Reduce motion is off by default but turns on automatically when the device asks for reduced motion. When on, the ring, confetti and shake are disabled.

## Notes for the Godot build

- The settings screen should keep the same options: theme, mode, accent, fonts, roundness, ghost strength, edge strength, and the effect toggles.
- Buttons are chunky and press down physically, with a solid shadow underneath that shrinks when pressed.
- Source of truth for the prototype values: the published design prototype. If the app and this file disagree, ask the owner.
